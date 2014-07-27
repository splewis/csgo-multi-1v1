#define TABLE_NAME "multi1v1_stats"
#define K_FACTOR 8.0
#define DISTRIBUTION_SPREAD 1000.0
#define DEFAULT_RATING 1500.0

new String:g_TableFormat[][] = {
    "accountID INT NOT NULL PRIMARY KEY default 0",
    "auth varchar(64) NOT NULL default ''",
    "name varchar(64) NOT NULL default ''",
    "wins INT NOT NULL default 0",
    "losses INT NOT NULL default 0",
    "rating FLOAT NOT NULL default 1500.0",
    "rifleRating FLOAT NOT NULL default 1500.0",
    "awpRating FLOAT NOT NULL default 1500.0",
    "pistolRating FLOAT NOT NULL default 1500.0",
    "lastTime INT default 0 NOT NULL",
    "recentRounds INT default 0 NOT NULL"
};

/**
 * Attempts to connect to the database.
 * Creates the stats (TABLE_NAME) if needed.
 */
public DB_Connect() {
    new String:error[255];
    db = SQL_Connect("multi1v1", true, error, sizeof(error));
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
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (!StrEqual("", error)) {
        g_dbConnected = false;
        LogError("Last Connect SQL Error: %s", error);
        CloseHandle(db);
    }
}

/**
 * Adds a player, updating their name if they already exist, to the database.
 */
public DB_AddPlayer(client) {
    if (db != INVALID_HANDLE) {
        new id = GetSteamAccountID(client);

        // player name
        decl String:name[64];
        GetClientName(client, name, sizeof(name));
        decl String:sanitized_name[64];
        SQL_EscapeString(db, name, sanitized_name, sizeof(name));

        // steam id
        decl String:auth[64];
        GetClientAuthString(client, auth, sizeof(auth));

        // insert if not already in the table
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "INSERT IGNORE INTO %s (accountID,auth,name,rating) VALUES (%d, '%s', '%s', %f);",
               TABLE_NAME, id, auth, sanitized_name, DEFAULT_RATING);
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
               "SELECT rating, awpRating, pistolRating, rifleRating, wins, losses FROM %s WHERE accountID = %d",
               TABLE_NAME, GetSteamAccountID(client));
        SQL_TQuery(db, Callback_FetchRating, g_sqlBuffer, client);
    }
}

public Callback_FetchRating(Handle:owner, Handle:hndl, const String:error[], any:data) {
    new client = data;
    g_FetchedPlayerInfo[client] = false;
    if (!IsPlayer(client))
        return;

    if (hndl == INVALID_HANDLE) {
        LogError("Query failed: (error: %s)", error);
    } else if (SQL_FetchRow(hndl)) {
        g_Rating[client] = SQL_FetchFloat(hndl, 0);
        g_AwpRating[client] = SQL_FetchFloat(hndl, 1);
        g_PistolRating[client] = SQL_FetchFloat(hndl, 2);
        g_RifleRating[client] = SQL_FetchFloat(hndl, 3);
        g_Wins[client] = SQL_FetchInt(hndl, 4);
        g_Losses[client] = SQL_FetchInt(hndl, 5);
        g_FetchedPlayerInfo[client] = true;
    } else {
        LogError("Couldn't fetch rating for %N", client);
    }
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
public DB_WriteRatings(client) {
    if (g_FetchedPlayerInfo[client]) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer),
               "UPDATE %s set rating = %f, pistolRating = %f, awpRating = %f, rifleRating = %f WHERE accountID = %d",
               TABLE_NAME, g_Rating[client], g_PistolRating[client], g_AwpRating[client], g_RifleRating[client], GetSteamAccountID(client));
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
static Increment(client, const String:field[]) {
    if (db != INVALID_HANDLE) {
        new id = GetSteamAccountID(client);
        if (id >= 1) {
            Format(g_sqlBuffer, sizeof(g_sqlBuffer),
                "UPDATE %s SET %s = %s + 1 WHERE accountID = %d",
                TABLE_NAME, field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        }
    }
}

static Float:ELORatingDelta(Float:winner_rating, Float:loser_rating, Float:K) {
    // probability of each player winning
    new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / DISTRIBUTION_SPREAD));

    // constant factor, suppose we have two opponents of equal ratings:
    // then they lose/gain K/2
    new Float:winner_delta = K * (1.0 - pWinner);

    return winner_delta;
}

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
static UpdateRatings(winner, loser, bool:forceLoss=false) {
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

        if (forceLoss) {
            ForceLoss(winner);
            ForceLoss(loser);
            return;
        }

        new Float:rating_delta = ELORatingDelta(g_Rating[winner], g_Rating[loser], K_FACTOR);

        if (IsValidClient(winner) && IsValidClient(loser)) {
            new int_winner_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser = RoundToNearest(g_Rating[loser] - rating_delta);
            new int_winner = RoundToNearest(g_Rating[winner] + rating_delta);

            PluginMessage(winner, "\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                int_winner, int_winner_d, loser, int_loser, int_loser_d);
            PluginMessage(loser,  "\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
                int_loser, int_loser_d, winner, int_winner, int_winner_d);

            g_Rating[winner] += rating_delta;
            g_Rating[loser] -= rating_delta;

            // rndTypeUpdate(RoundType:roundType, Float:ratingArray[])
            #define rndTypeUpdate(%1,%2) \
            if (g_roundTypes[arena] == %1) { \
               new Float:delta = ELORatingDelta(%2[winner], %2[loser], K_FACTOR); \
                %2[winner] += delta; \
                %2[loser] -= delta; \
            }

            new arena = g_Ranking[winner];
            if (IsValidArena(arena)) {
                rndTypeUpdate(RoundType_Rifle, g_RifleRating)
                rndTypeUpdate(RoundType_Pistol, g_PistolRating)
                rndTypeUpdate(RoundType_Awp, g_AwpRating)
             }

            DB_WriteRatings(winner);
            DB_WriteRatings(loser);
        }
    }
}

static ForceLoss(client) {
    new Float:rating = g_Rating[client];
    new Float:delta = ELORatingDelta(rating, rating, K_FACTOR);
    PluginMessage(client, "\x04You \x01(rating \x04%d\x01, \x07-%d\x01) let time run out",
                  RoundToNearest(g_Rating[client] - delta),
                  RoundToNearest(delta));

    g_Rating[client] -= delta;
    DB_WriteRatings(client);
}

public ShowStatsForPlayer(client, target) {
    decl String:url[255];
    GetConVarString(g_hStatsWebsite, url, sizeof(url));
    if (StrEqual(url, "")) {
        PluginMessage(client, "Sorry, there is no stats website for this server.");
        return;
    }

    decl String:player_url[255];
    Format(player_url, sizeof(player_url), "%s%d", url, GetSteamAccountID(target));
    ShowMOTDPanel(client, "Multi-1v1 Stats", player_url, MOTDPANEL_TYPE_URL);
}
