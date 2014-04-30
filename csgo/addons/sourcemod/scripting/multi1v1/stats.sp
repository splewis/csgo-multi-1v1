#include <sourcemod>

new Float:g_ratings[MAXPLAYERS+1]; // current rating for a player
new g_ids[MAXPLAYERS+1]; // steam account ID for a player - fetched on connection

new Handle:g_hUseDatabase = INVALID_HANDLE;
new bool:g_dbConnected = false;
new Handle:db = INVALID_HANDLE;
new String:sqlBuffer[1024];

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
		SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS multi1v1_stats (accountID INT NOT NULL PRIMARY KEY default 0, name varchar(255) NOT NULL default '', wins INT NOT NULL default 0, losses INT NOT NULL default 0, rating FLOAT NOT NULL default 1450.0);");
		SQL_UnlockDatabase(db);
		SQL_TQuery(db, SQLErrorCheckCallback, "DELETE FROM multi1v1_stats WHERE wins+losses <= 5;")
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
		new id = g_ids[client];
		new String:name[100];
		GetClientName(client, name, sizeof(name));
		new String:sanitized_name[100];
		SQL_EscapeString(db, name, sanitized_name, sizeof(name));
		Format(sqlBuffer, sizeof(sqlBuffer), "INSERT IGNORE INTO multi1v1_stats (accountID,name,rating) VALUES (%d, '%s', %f);", id, sanitized_name, default_rating);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
		Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE multi1v1_stats SET name = '%s' WHERE accountID = %d", sanitized_name, id);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
	}
}

/**
 * Increments a named field in the database.
 */
public DB_Increment(client, const String:field[]) {
	if (db != INVALID_HANDLE) {
		new id = g_ids[client];
		if (id >= 1) {
			Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE multi1v1_stats SET %s = %s + 1 WHERE accountID = %d", field, field, id);
			SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
		}
	}
}

/**
 * Reads a player rating from the database.
 * Note that this is a *SLOW* operation and you should not do it during gameplay
 */
public DB_FetchRating(client) {
	new Float:rating = 0.0;
	if (db != INVALID_HANDLE) {
		SQL_LockDatabase(db);
		Format(sqlBuffer, sizeof(sqlBuffer), "SELECT rating FROM multi1v1_stats WHERE accountID = %d", GetSteamAccountID(client));
		new Handle:query = SQL_Query(db, sqlBuffer);

		if (query == INVALID_HANDLE) {
			new String:error[255]
			SQL_GetError(db, error, sizeof(error))
			LogError("Failed to query (error: %s)", error)
		} else {
			while (SQL_FetchRow(query))	{
				rating = SQL_FetchFloat(query, 0);
			}
			CloseHandle(query);
		}
		SQL_UnlockDatabase(db);
	}
	g_ratings[client] = rating;
}

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
public DB_UpdateRating(winner, loser) {
	if (db != INVALID_HANDLE) {

		new Float:winner_rating = g_ratings[winner];
		new Float:loser_rating  = g_ratings[loser];

		// go fetch the ratings if needed
		if (winner_rating <= 0.0) {
			DB_FetchRating(winner);
			winner_rating = g_ratings[winner];
		}

		if (loser_rating <= 0.0) {
			DB_FetchRating(loser);
			loser_rating = g_ratings[loser];
		}

		if (winner_rating <= 0.0 || loser_rating <= 0.0) {
			return;
		}

		// probability of each player winning
		new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / 600.0));
		new Float:pLoser = 1.0 - pWinner;

		// constant factor, suppose we have two opponents of equal ratings - they will lose/gain K/2
		new Float:K = 8.0;
		new Float:winner_delta = K * (1.0 - pWinner);
		new Float:loser_delta  = K * (0.0 - pLoser);

		new Float:winner_rating_new  = winner_rating + winner_delta;
		new Float:loser_rating_new   = loser_rating  + loser_delta;

		// lower bound on ratings, it's important this is greater than 0 so
		// we can use <= 0 to detect failures to read the player rating
		if (loser_rating_new <= 200.0) {
			loser_rating_new = 200.0;
		}

		if (IsValidClient(winner) && IsValidClient(loser)) {
			new int_winner_d = RoundToNearest(FloatAbs(winner_delta));
			new int_loser_d = RoundToNearest(FloatAbs(loser_delta));
			new int_loser = RoundToNearest(loser_rating_new);
			new int_winner = RoundToNearest(winner_rating_new);

			PrintToChat(winner, " \x01\x0B\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
				int_winner, int_winner_d, loser, int_loser, int_loser_d);
			PrintToChat(loser,  " \x01\x0B\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
				int_loser, int_loser_d, winner, int_winner, int_winner_d);
		}

		g_ratings[winner] = winner_rating_new;
		g_ratings[loser] = loser_rating_new;
	}
}

/**
 * Writes the rating for a player, if the rating is valid, back to the database.
 */
DB_WriteRating(client) {
	if (g_ratings[client] >= 200.0) {
		Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE multi1v1_stats set rating = %f WHERE accountID = %d", g_ratings[client], g_ids[client]);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
	}
}
