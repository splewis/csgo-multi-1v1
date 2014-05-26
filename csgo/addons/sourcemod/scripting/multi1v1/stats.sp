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
        SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS multi1v1_stats (accountID INT NOT NULL PRIMARY KEY default 0, auth varchar(64) NOT NULL default '', name varchar(64) NOT NULL default '', wins INT NOT NULL default 0, losses INT NOT NULL default 0, rating FLOAT NOT NULL default 1500.0;");
        SQL_UnlockDatabase(db);

        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "DELETE FROM multi1v1_stats WHERE wins+losses < %d;", GetConVarInt(g_hMinRoundsForDB));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        g_dbConnected = true;
    }
}

/**
 * Generic SQL threaded query error callback.
 */
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (!StrEqual("", error)) {
        CloseHandle(db);
        g_dbConnected = false;
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

        decl String:name[64];
        GetClientName(client, name, sizeof(name));
        decl String:sanitized_name[64];
        SQL_EscapeString(db, name, sanitized_name, sizeof(name));

        decl String:auth[64];
        GetClientAuthString(client, auth, sizeof(auth));

        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "INSERT IGNORE INTO multi1v1_stats (accountID,auth,name,rating) VALUES (%d, '%s', '%s', %f);", id, auth, sanitized_name, default_rating);
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);

        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats SET name = '%s' WHERE accountID = %d", sanitized_name, id);
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
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "SELECT rating FROM multi1v1_stats WHERE accountID = %d", GetSteamAccountID(client));
        new Handle:query = SQL_Query(db, g_sqlBuffer);

        if (query == INVALID_HANDLE) {
            new String:error[255];
            SQL_GetError(db, error, sizeof(error));
            LogError("Failed to query (error: %s)", error);
        } else {
            while (SQL_FetchRow(query)) {
                rating = SQL_FetchFloat(query, 0);
            }
            CloseHandle(query);
        }
        SQL_UnlockDatabase(db);
    }
    g_ratings[client] = rating;
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
public DB_WriteRatings(client) {
    if (g_ratings[client] >= MIN_RATING) {
        Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats set rating = %f WHERE accountID = %d", g_ratings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
    }
}

public GetAccountID(client) {
    if (g_playerIDs[client] == 0)
        g_playerIDs[client] = GetSteamAccountID(client);
    return g_playerIDs[client];
}

public DB_RoundUpdate(winner, loser, bool:forceLoss) {
    if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {
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
        new id = GetAccountID(client);
        if (id >= 1) {
            Format(g_sqlBuffer, sizeof(g_sqlBuffer), "UPDATE multi1v1_stats SET %s = %s + 1 WHERE accountID = %d", field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, g_sqlBuffer);
        }
    }
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
static UpdateRatings(winner, loser, bool:forceLoss=false) {
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

            PrintToChat(winner, "\x01\x0B\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                int_winner, int_winner_d, loser, int_loser, int_loser_d);
            PrintToChat(loser,  "\x01\x0B\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
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
    PrintToChat(client, "\x01\x0B\x04You \x01(rating \x04%d\x01, \x07-%d\x01) let time run out", RoundToNearest(g_ratings[client]), RoundToNearest(delta));
    g_ratings[client] -= delta;
    DB_WriteRatings(client);
}
