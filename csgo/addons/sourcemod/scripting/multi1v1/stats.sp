#include <sourcemod>
#include "common.sp"
#include "roundTypes.sp"
#pragma semicolon 1

new Handle:g_hUseDatabase = INVALID_HANDLE;
new bool:g_dbConnected = false;
new Handle:db = INVALID_HANDLE;

// Internal variables for this file
new Float:__ratings[MAXPLAYERS+1]; // current rating for a player
new Float:__pistolRatings[MAXPLAYERS+1];
new Float:__rifleRatings[MAXPLAYERS+1];
new Float:__awpRatings[MAXPLAYERS+1];
new __ids[MAXPLAYERS+1]; // steam account ID for a player - fetched on connection
new String:__sqlbuffer[1024];

/**
 *
 */
public DB_ResetClientVariables(client) {
    __ids[client] = 0;
    __ratings[client] = 0.0;
    __pistolRatings[client] = 0.0;
    __awpRatings[client] = 0.0;
    __rifleRatings[client] = 0.0;
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
        __ids[client] = id;
        new String:name[100];
        GetClientName(client, name, sizeof(name));
        new String:sanitized_name[100];
        SQL_EscapeString(db, name, sanitized_name, sizeof(name));
        Format(__sqlbuffer, sizeof(__sqlbuffer), "INSERT IGNORE INTO multi1v1_stats (accountID,name,rating) VALUES (%d, '%s', %f);", id, sanitized_name, default_rating);
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
        Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats SET name = '%s' WHERE accountID = %d", sanitized_name, id);
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
    }
}

/**
 * Increments a named field in the database.
 */
public __Increment(client, const String:field[]) {
    if (db != INVALID_HANDLE) {
        new id = GetAccountID(client);
        if (id >= 1) {
            Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats SET %s = %s + 1 WHERE accountID = %d", field, field, id);
            SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
        }
    }
}

public DB_RoundUpdate(winner, loser, RoundType:roundType) {
    if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {
        __Increment(winner, "wins");
        __Increment(loser, "losses");
        __UpdateRating(winner, loser, roundType);
    }
}

public GetAccountID(client) {
    if (__ids[client] == 0)
        __ids[client] = GetSteamAccountID(client);
    return __ids[client];
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
        Format(__sqlbuffer, sizeof(__sqlbuffer), "SELECT rating, pistolRating, awpRating, rifleRating FROM multi1v1_stats WHERE accountID = %d", GetSteamAccountID(client));
        new Handle:query = SQL_Query(db, __sqlbuffer);

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
    __ratings[client] = rating;
    __pistolRatings[client] = pistolRating;
    __awpRatings[client] = awpRating;
    __rifleRatings[client] = rifleRating;
}

public Float:ELORatingDelta(Float:winner_rating, Float:loser_rating) {
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
public __UpdateRating(winner, loser, RoundType:roundType) {
    if (db != INVALID_HANDLE) {
        // go fetch the ratings if needed
        if (__ratings[winner] <= 0.0) {
            DB_FetchRatings(winner);
        }

        if (__ratings[loser] <= 0.0) {
            DB_FetchRatings(loser);
        }

        if (__ratings[winner] <= 0.0 || __ratings[loser] <= 0.0) {
            return;
        }

        new Float:rating_delta = ELORatingDelta(__ratings[winner], __ratings[loser]);

        if (IsValidClient(winner) && IsValidClient(loser)) {
            new int_winner_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser_d = RoundToNearest(FloatAbs(rating_delta));
            new int_loser = RoundToNearest(__ratings[loser]);
            new int_winner = RoundToNearest(__ratings[winner]);

            PrintToChat(winner, " \x01\x0B\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                int_winner, int_winner_d, loser, int_loser, int_loser_d);
            PrintToChat(loser,  " \x01\x0B\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
                int_loser, int_loser_d, winner, int_winner, int_winner_d);
        }

        __ratings[winner] += rating_delta;
        __ratings[loser] -= rating_delta;

        if (roundType == RoundType_Pistol) {
            rating_delta = ELORatingDelta(__pistolRatings[winner], __pistolRatings[loser]);
            __pistolRatings[winner] += rating_delta;
            __pistolRatings[loser] -= rating_delta;
        } else if (roundType == RoundType_Awp) {
            rating_delta = ELORatingDelta(__awpRatings[winner], __awpRatings[loser]);
            __awpRatings[winner] += rating_delta;
            __awpRatings[loser] -= rating_delta;
        } else if (roundType == RoundType_Rifle) {
            rating_delta = ELORatingDelta(__rifleRatings[winner], __rifleRatings[loser]);
            __rifleRatings[winner] += rating_delta;
            __rifleRatings[loser] -= rating_delta;
        }

        DB_WriteRatings(winner);
        DB_WriteRatings(loser);

    }
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
DB_WriteRatings(client) {
    if (__ratings[client] >= 200.0) {
        Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats set rating = %f WHERE accountID = %d", __ratings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
    }
    if (__pistolRatings[client] >= 200.0) {
        Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats set pistolRating = %f WHERE accountID = %d", __pistolRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
    }
    if (__awpRatings[client] >= 200.0) {
        Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats set awpRating = %f WHERE accountID = %d", __awpRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
    }
    if (__rifleRatings[client] >= 200.0) {
        Format(__sqlbuffer, sizeof(__sqlbuffer), "UPDATE multi1v1_stats set rifleRating = %f WHERE accountID = %d", __rifleRatings[client], GetAccountID(client));
        SQL_TQuery(db, SQLErrorCheckCallback, __sqlbuffer);
    }
}
