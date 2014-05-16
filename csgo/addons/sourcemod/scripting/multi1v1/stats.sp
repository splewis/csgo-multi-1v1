/**
 *
 */
public DB_ResetClientVariables(client) {
    g_playerIDs[client] = 0;
    g_ratings[client] = 0.0;
    g_pistolRatings[client] = 0.0;
    g_awpRatings[client] = 0.0;
    g_rifleRatings[client] = 0.0;
}

/**
 * Attempts to connect to the database.
 * Creates the multi1v1_stats table if needed.
 * 'Cleans' the database eliminating players with a very small number of wins+losses. (meant to reduce database size)
 */
public DB_Connect() {
    new String:error[255];
    db = SQL_Connect("multi1v1", true, error, sizeof(error));
    if (db == INVALID_HANDLE) {
        g_dbConnected = false;
        LogError("Could not connect: %s", error);
    } else {
        SQL_LockDatabase(db);
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS multi1v1_stats (accountID INT NOT NULL PRIMARY KEY default 0, name varchar(64) NOT NULL default '', wins INT NOT NULL default 0, losses INT NOT NULL default 0, rating FLOAT NOT NULL default 1500.0, pistolRating FLOAT NOT NULL default 1500.0, rifleRating FLOAT NOT NULL default 1500.0, awpRating FLOAT NOT NULL default 1500.0);");
        SQL_UnlockDatabase(db);
        SQL_TQuery(db, SQLErrorCheckCallback, "DELETE FROM multi1v1_stats WHERE wins+losses <= 5;");
        g_dbConnected = true;
    }
}

/**
 * Generic SQL threaded query error callback.
 */
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (!StrEqual("", error)) {
        LogError("Last Connect SQL Error: %s", error);
    }
}

/**
 * Adds a player, updating their name if they already exist, to the database.
 */
public DB_AddPlayer(client, Float:default_rating) {
    if (db != INVALID_HANDLE) {
        new id = GetAccountID(client);
        g_playerIDs[client] = id;
        new String:name[100];
        GetClientName(client, name, sizeof(name));
        new String:sanitized_name[100];
        SQL_EscapeString(db, name, sanitized_name, sizeof(name));
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "INSERT IGNORE INTO multi1v1_stats (accountID,name,rating) VALUES (%d, '%s', %f);", id, sanitized_name, default_rating);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats SET name = '%s' WHERE accountID = %d", sanitized_name, id);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}

/**
 * Increments a named field in the database.
 */
static Increment(client, const String:field[]) {
    if (db != INVALID_HANDLE) {
        new id = GetAccountID(client);
        if (id >= 1) {
            Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats SET %s = %s + 1 WHERE accountID = %d", field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        }
    }
}

public DB_RoundUpdate(winner, loser, RoundType:roundType) {
    if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {
        Increment(winner, "wins");
        Increment(loser, "losses");
        UpdateRatings(winner, loser, roundType);
    }
}

public GetAccountID(client) {
    if (g_playerIDs[client] == 0)
        g_playerIDs[client] = GetSteamAccountID(client);
    return g_playerIDs[client];
}

/**
 * Reads a player rating from the database.
 * Note that this is a *SLOW* operation and you should not do it during gameplay
 */
public DB_FetchRatings(client) {
    new Float:rating = 0.0;
    new Float:pistolRating = 0.0;
    new Float:awpRating = 0.0;
    new Float:rifleRating = 0.0;

    if (db != INVALID_HANDLE) {
        SQL_LockDatabase(db);
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "SELECT rating, pistolRating, awpRating, rifleRating FROM multi1v1_stats WHERE accountID = %d", GetSteamAccountID(client));
        new Handle:query = SQL_Query(db, g_sqlBuffer);

        if (query == INVALID_HANDLE) {
            new String:error[255];
            SQL_GetError(db, error, sizeof(error));
            LogError("Failed to query (error: %s)", error);
        } else {
            while (SQL_FetchRow(query)) {
                rating = SQL_FetchFloat(query, 0);
                pistolRating = SQL_FetchFloat(query, 1);
                awpRating = SQL_FetchFloat(query, 2);
                rifleRating = SQL_FetchFloat(query, 3);
            }
            CloseHandle(query);
        }
        SQL_UnlockDatabase(db);
    }
    g_ratings[client] = rating;
    g_pistolRatings[client] = pistolRating;
    g_awpRatings[client] = awpRating;
    g_rifleRatings[client] = rifleRating;
}

static Float:ELORatingDelta(Float:winner_rating, Float:loser_rating) {
    // probability of each player winning
    new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / 800.0));
    Assert(pWinner >= 0.0 && pWinner <= 1.0, "pWinner=%f is out of bounds", pWinner);

    // constant factor, suppose we have two opponents of equal ratings - they will lose/gain K/2
    new Float:K = 8.0;
    new Float:winner_delta = K * (1.0 - pWinner);

    return winner_delta;
}

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
static UpdateRatings(winner, loser, RoundType:roundType) {
    if (db != INVALID_HANDLE) {
        // go fetch the ratings if needed
        if (g_ratings[winner] <= 0.0) {
            DB_FetchRatings(winner);
        }

        if (g_ratings[loser] <= 0.0) {
            DB_FetchRatings(loser);
        }

        if (g_ratings[winner] <= 0.0 || g_ratings[loser] <= 0.0) {
            return;
        }

        new Float:rating_delta = ELORatingDelta(g_ratings[winner], g_ratings[loser]);

        if (IsValidClient(winner) && IsValidClient(loser)) {
            new int_winner_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser = RoundToNearest(g_ratings[loser]);
            new int_winner = RoundToNearest(g_ratings[winner]);

            PrintToChat(winner, " \x01\x0B\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                int_winner, int_winner_d, loser, int_loser, int_loser_d);
            PrintToChat(loser,  " \x01\x0B\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
                int_loser, int_loser_d, winner, int_winner, int_winner_d);
        }

        g_ratings[winner] += rating_delta;
        g_ratings[loser]  -= rating_delta;

        if (roundType == RoundType_Pistol) {
            rating_delta = ELORatingDelta(g_pistolRatings[winner], g_pistolRatings[loser]);
            g_pistolRatings[winner] += rating_delta;
            g_pistolRatings[loser] -= rating_delta;
        } else if (roundType == RoundType_Awp) {
            rating_delta = ELORatingDelta(g_awpRatings[winner], g_awpRatings[loser]);
            g_awpRatings[winner] += rating_delta;
            g_awpRatings[loser] -= rating_delta;
        } else if (roundType == RoundType_Rifle) {
            rating_delta = ELORatingDelta(g_rifleRatings[winner], g_rifleRatings[loser]);
            g_rifleRatings[winner] += rating_delta;
            g_rifleRatings[loser] -= rating_delta;
        }

        DB_WriteRatings(winner);
        DB_WriteRatings(loser);

    }
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
DB_WriteRatings(client) {
    if (g_ratings[client] >= 200.0) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats set rating = %f WHERE accountID = %d", g_ratings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
    if (g_pistolRatings[client] >= 200.0) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats set pistolRating = %f WHERE accountID = %d", g_pistolRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
    if (g_awpRatings[client] >= 200.0) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats set awpRating = %f WHERE accountID = %d", g_awpRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
    if (g_rifleRatings[client] >= 200.0) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats set rifleRating = %f WHERE accountID = %d", g_rifleRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}
