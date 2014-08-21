char g_TableFormat[][] = {
    "accountID INT NOT NULL PRIMARY KEY default 0",
    "auth varchar(64) NOT NULL default ''",
    "name varchar(64) NOT NULL default ''",
    "wins INT NOT NULL default 0",
    "losses INT NOT NULL default 0",
    "rating FLOAT NOT NULL default 1500.0",
    "rifleRating FLOAT NOT NULL default 1500.0",
    "pistolRating FLOAT NOT NULL default 1500.0",
    "awpRating FLOAT NOT NULL default 1500.0",
    "lastTime INT default 0 NOT NULL",
    "recentRounds INT default 0 NOT NULL"
};

/**
 * Attempts to connect to the database.
 * Creates the stats (TABLE_NAME) if needed.
 */
public DB_Connect() {
    char error[255];
    char dbCfgName[255];
    GetConVarString(g_hDatabaseName, dbCfgName, sizeof(dbCfgName));
    db = SQL_Connect(dbCfgName, true, error, sizeof(error));
    if (db == INVALID_HANDLE) {
        g_dbConnected = false;
        LogError("Could not connect: %s", error);
    } else {
        // create the table
        SQL_LockDatabase(db);
        SQL_CreateTable(db, TABLE_NAME, g_TableFormat, sizeof(g_TableFormat));
        SQL_UnlockDatabase(db);
        g_dbConnected = true;
    }
}

/**
 * Generic SQL threaded query error callback.
 */
public SQLErrorCheckCallback(Handle owner, Handle hndl, const char error[], any:data) {
    if (!StrEqual("", error)) {
        LogError("Last Connect SQL Error: %s", error);
    }
}

/**
 * Adds a player, updating their name if they already exist, to the database.
 */
public DB_AddPlayer(client) {
    if (db != INVALID_HANDLE) {
        int id = GetSteamAccountID(client);

        // player name
        char name[64];
        GetClientName(client, name, sizeof(name));
        char sanitized_name[64];
        SQL_EscapeString(db, name, sanitized_name, sizeof(name));

        // steam id
        char auth[64];
        GetClientAuthString(client, auth, sizeof(auth));

        // insert if not already in the table
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "INSERT IGNORE INTO %s (accountID,auth,name) VALUES (%d, '%s', '%s');",
               TABLE_NAME, id, auth, sanitized_name);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        // update the player name
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "UPDATE %s SET name = '%s' WHERE accountID = %d",
               TABLE_NAME, sanitized_name, id);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        // update last connect time
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
              "UPDATE %s SET lastTime = %d WHERE accountID = %d",
              TABLE_NAME, GetTime(), id);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        DB_FetchRatings(client);
    }
}

/**
 * Reads a player rating from the database.
 * Note that this is a *SLOW* operation and you should not do it during gameplay
 */
public DB_FetchRatings(client) {
    g_FetchedPlayerInfo[client] = false;
    if (db != INVALID_HANDLE) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "SELECT rating, rifleRating, pistolRating, awpRating, wins, losses FROM %s WHERE accountID = %d",
               TABLE_NAME, GetSteamAccountID(client));
        SQL_TQuery(db, Callback_FetchRating, g_sqlBuffer, client);
    }
}

public Callback_FetchRating(Handle owner, Handle hndl, const char error[], any:data) {
    int client = data;
    g_FetchedPlayerInfo[client] = false;
    if (!IsPlayer(client))
        return;

    if (hndl == INVALID_HANDLE) {
        LogError("Query failed: (error: %s)", error);
    } else if (SQL_FetchRow(hndl)) {
        g_Rating[client] = SQL_FetchFloat(hndl, 0);
        g_RifleRating[client] = SQL_FetchFloat(hndl, 1);
        g_PistolRating[client] = SQL_FetchFloat(hndl, 2);
        g_AwpRating[client] = SQL_FetchFloat(hndl, 3);
        g_Wins[client] = SQL_FetchInt(hndl, 4);
        g_Losses[client] = SQL_FetchInt(hndl, 5);
        g_FetchedPlayerInfo[client] = true;
        Call_StartForward(g_hOnStatsCached);
        Call_PushCell(client);
        Call_Finish();

    } else {
        LogError("Failed to fetch statistics for for %N", client);
    }
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
public DB_WriteRatings(client) {
    if (g_FetchedPlayerInfo[client]) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "UPDATE %s set rating = %f, rifleRating = %f, awpRating = %f, pistolRating = %f WHERE accountID = %d",
               TABLE_NAME, g_Rating[client], g_RifleRating[client], g_AwpRating[client], g_PistolRating[client],
               GetSteamAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}

public DB_RoundUpdate(winner, loser, bool:forceLoss) {
    if (IsPlayer(winner) && IsPlayer(loser)) {

        // TODO: this is a temporary band-aid for the first round ending
        //  too early sometimes and unfairly punishes early connectors
        if (forceLoss && g_totalRounds <= 3) {
            return;
        }

        Call_StartForward(g_hOnRoundWon);
        Call_PushCell(winner);
        Call_PushCell(loser);
        Call_PushCell(forceLoss);
        Call_Finish();

        if (GetConVarInt(g_hUseDatabase) == 0)
            return;

        Increment(loser, "losses");
        if (forceLoss)
            Increment(winner, "losses");
        else
            Increment(winner, "wins");

        Increment(winner, "recentRounds");
        Increment(loser, "recentRounds");
        UpdateRatings(winner, loser, forceLoss);
    }
}

/**
 * Increments a named field in the database.
 */
public Increment(int client, const char field[]) {
    if (db != INVALID_HANDLE) {
        int id = GetSteamAccountID(client);
        if (id >= 1) {
            Format(g_sqlBuffer, sizeof(g_sqlBuffer),
                "UPDATE %s SET %s = %s + 1 WHERE accountID = %d",
                TABLE_NAME, field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        }
    }
}

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
public UpdateRatings(int winner, int loser, bool forceLoss) {
    if (db != INVALID_HANDLE) {
        // go fetch the ratings if needed
        if (!g_FetchedPlayerInfo[winner]) {
            DB_FetchRatings(winner);
        }

        if (!g_FetchedPlayerInfo[loser]) {
            DB_FetchRatings(loser);
        }

        // give up - we don't have the ratings yet, better luck next time?
        if (!g_FetchedPlayerInfo[winner] || !g_FetchedPlayerInfo[loser]) {
            return;
        }

        bool block = g_BlockStatChanges[winner] || g_BlockStatChanges[loser];
        if (block)
            return;

        if (forceLoss) {
            ForceLoss(winner, loser);
            return;
        }

        if (IsValidClient(winner) && IsValidClient(loser)) {
            float delta = ELORatingDelta(g_Rating[winner], g_Rating[loser], K_FACTOR);
            g_Rating[winner] += delta;
            g_Rating[loser] -= delta;
            RatingMessage(winner, loser, g_Rating[winner], g_Rating[loser], delta);

            // rndTypeUpdate(RoundType roundType, float ratingArray[])
            #define rndTypeUpdate(%1,%2) \
            if (g_roundTypes[arena] == %1) { \
                delta = ELORatingDelta(%2[winner], %2[loser], K_FACTOR); \
                %2[winner] += delta; \
                %2[loser] -= delta; \
            }

            int arena = g_Ranking[winner];
            if (arena > 0) {
                rndTypeUpdate(RoundType_Rifle, g_RifleRating)
                rndTypeUpdate(RoundType_Pistol, g_PistolRating)
                rndTypeUpdate(RoundType_Awp, g_AwpRating)
            }

            DB_WriteRatings(winner);
            DB_WriteRatings(loser);
        }
    }
}

static ForceLoss(int winner, int loser) {
    float delta = K_FACTOR / 2.0;
    g_Rating[winner] -= delta;
    g_Rating[loser] -= delta;
    DB_WriteRatings(winner);
    DB_WriteRatings(loser);
    ForceLossMessage(winner, g_Rating[winner], delta);
    ForceLossMessage(loser, g_Rating[loser], delta);
}

static RatingMessage(int winner, int loser, float winner_rating, float loser_rating, float delta) {
    int winner_int = RoundToNearest(winner_rating);
    int loser_int = RoundToNearest(loser_rating);
    Multi1v1Message(winner, "%t", "WonMessage", winner_int, delta, loser, loser_int, delta);
    Multi1v1Message(loser, "%t", "LossMessage", loser_int, delta, winner, winner_int, delta);
}

static ForceLossMessage(int client, float rating, float delta) {
    Multi1v1Message(client, "%t", "TimeRanOut", RoundToNearest(rating), delta);
}
