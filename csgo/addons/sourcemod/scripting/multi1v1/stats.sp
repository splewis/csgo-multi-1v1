#define TABLE_NAME "multi1v1_stats"
#define K_FACTOR 8.0
#define DISTRIBUTION_SPREAD 1000.0
#define DEFAULT_RATING 1500.0
#define MIN_RATING 200.0

/**
 * Attempts to connect to the database.
 * Creates the stats (TABLE_NAME) if needed.
 * 'Cleans' the database eliminating players with a very small number of wins+losses. (meant to reduce database size)
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
        CreateTables();
        PurgeRows();
        SQL_UnlockDatabase(db);
        g_dbConnected = true;
    }
}

static CreateTables() {
    Format(g_sqlBuffer, sizeof(g_sqlBuffer), "CREATE TABLE IF NOT EXISTS %s (accountID INT NOT NULL PRIMARY KEY default 0, auth varchar(64) NOT NULL default '', name varchar(64) NOT NULL default '', wins INT NOT NULL default 0, losses INT NOT NULL default 0, rating FLOAT NOT NULL default 1500.0, lastTime INT default 0 NOT NULL);", TABLE_NAME);
    SQL_FastQuery(db, g_sqlBuffer);
 }

static PurgeRows() {
    Format(g_sqlBuffer, sizeof(g_sqlBuffer), "DELETE FROM %s WHERE wins+losses < %d;", TABLE_NAME, GetConVarInt(g_hMinRoundsForDB));
    SQL_FastQuery(db, g_sqlBuffer);
}

/**
 * Generic SQL threaded query error callback.
 */
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (!StrEqual("", error)) {
        db = INVALID_HANDLE;
        g_dbConnected = false;
        LogError("Last Connect SQL Error: %s", error);
    }
}

/**
 * Adds a player, updating their name if they already exist, to the database.
 */
public DB_AddPlayer(client, Float:default_rating) {
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
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "INSERT IGNORE INTO %s (accountID,auth,name,rating) VALUES (%d, '%s', '%s', %f);", TABLE_NAME, id, auth, sanitized_name, default_rating);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        // update the player name
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE %s SET name = '%s' WHERE accountID = %d", TABLE_NAME, sanitized_name, id);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE %s SET lastTime = %d WHERE accountID = %d", TABLE_NAME, GetTime(), id);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}

/**
 * Reads a player rating from the database.
 * Note that this is a *SLOW* operation and you should not do it during gameplay
 */
public DB_FetchRatings(client) {
    new Float:rating = 0.0;

    if (db != INVALID_HANDLE) {
        SQL_LockDatabase(db);
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "SELECT rating FROM %s WHERE accountID = %d", TABLE_NAME, GetSteamAccountID(client));
        new Handle:query = SQL_Query(db, g_sqlBuffer);

        if (query == INVALID_HANDLE) {
            new String:error[255];
            SQL_GetError(db, error, sizeof(error));
            LogError("Failed to query (error: %s)", error);
            g_dbConnected = false;
            CloseHandle(db);
        } else if (SQL_FetchRow(query)) {
            rating = SQL_FetchFloat(query, 0);
        } else {
            LogError("Couldn't fetch rating for %N", client);
        }

        CloseHandle(query);
        SQL_UnlockDatabase(db);
    }
    g_ratings[client] = rating;
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
public DB_WriteRatings(client) {
    if (g_ratings[client] >= MIN_RATING) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE %s set rating = %f WHERE accountID = %d", TABLE_NAME, g_ratings[client], GetSteamAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}

public DB_RoundUpdate(winner, loser, bool:forceLoss) {
    if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {

        /* TODO: this is a temporary band-aid for the first round ending too early sometimes and unfairly punishes early connectors */
        if (forceLoss && g_TotalRounds <= 2) {
            return;
        }

        Increment(loser, "losses");
        if (forceLoss)
            Increment(winner, "losses");
        else
            Increment(winner, "wins");
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
            Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE %s SET %s = %s + 1 WHERE accountID = %d", TABLE_NAME, field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        }
    }
}

static Float:ELORatingDelta(Float:winner_rating, Float:loser_rating) {
    // probability of each player winning
    new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / DISTRIBUTION_SPREAD));

    // constant factor, suppose we have two opponents of equal ratings - they will lose/gain K/2
    new Float:winner_delta = K_FACTOR * (1.0 - pWinner);

    return winner_delta;
}

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
static UpdateRatings(winner, loser, bool:forceLoss=false) {
    if (db != INVALID_HANDLE) {
        // go fetch the ratings if needed
        if (g_ratings[winner] < MIN_RATING) {
            DB_FetchRatings(winner);
        }

        if (g_ratings[loser] < MIN_RATING) {
            DB_FetchRatings(loser);
        }

        // still couldn't fetch the ratings - give up
        if (g_ratings[winner] <= MIN_RATING || g_ratings[loser] <= MIN_RATING) {
            return;
        }

        if (forceLoss) {
            ForceLoss(winner);
            ForceLoss(loser);
            return;
        }

        new Float:rating_delta = ELORatingDelta(g_ratings[winner], g_ratings[loser]);

        if (IsValidClient(winner) && IsValidClient(loser)) {
            new int_winner_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser = RoundToNearest(g_ratings[loser] - rating_delta);
            new int_winner = RoundToNearest(g_ratings[winner] + rating_delta);

            PrintToChat(winner, " \x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                int_winner, int_winner_d, loser, int_loser, int_loser_d);
            PrintToChat(loser,  " \x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
                int_loser, int_loser_d, winner, int_winner, int_winner_d);
        }

        g_ratings[winner] += rating_delta;
        g_ratings[loser]  -= rating_delta;

        DB_WriteRatings(winner);
        DB_WriteRatings(loser);

    }
}

static ForceLoss(client) {
    new Float:rating = g_ratings[client];
    new Float:delta = ELORatingDelta(rating, rating);
    PrintToChat(client, " \x04You \x01(rating \x04%d\x01, \x07-%d\x01) let time run out", RoundToNearest(g_ratings[client] - delta), RoundToNearest(delta));
    g_ratings[client] -= delta;
    DB_WriteRatings(client);
}
