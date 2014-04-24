#include <sourcemod>

new Float:ratings[MAXPLAYERS+1];
new ids[MAXPLAYERS+1];

new bool:db_connected = false;
new Handle:db = INVALID_HANDLE;
new String:sqlBuffer[1024];

public DB_Connect() {
	new String:error[255];
	db = SQL_Connect("remote", true, error, sizeof(error));
	if (db == INVALID_HANDLE) {
		db_connected = false;
		LogError("Could not connect: %s", error);
	} else {
		db_connected = true;
		SQL_TQuery(db, SQLErrorCheckCallback, "DELETE FROM stats WHERE wins+losses <= 5;")
	}
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if (!StrEqual("", error)) {
		LogError("Last Connect SQL Error: %s", error);
	}
}

public DB_AddPlayer(client, Float:default_rating) {
	if (db != INVALID_HANDLE) {
		new id = ids[client];
		new String:name[100];
		GetClientName(client, name, sizeof(name));
		new String:sanitized_name[100];
		SQL_EscapeString(db, name, sanitized_name, sizeof(name));
		Format(sqlBuffer, sizeof(sqlBuffer), "INSERT IGNORE INTO stats (steamID,name,rating) VALUES (%d, '%s', %f);", id, sanitized_name, default_rating);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
		Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE stats SET name = '%s' WHERE steamID = %d", sanitized_name, id);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
	}
}

public DB_Increment(client, const String:field[]) {
	if (db != INVALID_HANDLE) {
		new id = ids[client];
		if (id >= 1) {
			Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE stats SET %s = %s + 1 WHERE steamID = %d", field, field, id);
			SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
		}
	}
}

public Float:DB_GetRating(client) {
	new Float:rating = 0.0;
	if (db != INVALID_HANDLE) {
		Format(sqlBuffer, sizeof(sqlBuffer), "SELECT rating FROM stats WHERE steamID = %d", GetSteamAccountID(client));
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
	}
	return rating;
}

public DB_UpdateRating(winner, loser) {
	if (db != INVALID_HANDLE) {

		new Float:winner_rating = ratings[winner];
		new Float:loser_rating = ratings[loser];

		// go fetch the ratings if needed
		if (winner_rating <= 0.0) {
			SQL_LockDatabase(db);
			winner_rating = DB_GetRating(winner);
			ratings[winner] = winner_rating;
			SQL_UnlockDatabase(db);
		}

		if (loser_rating <= 0.0) {
			SQL_LockDatabase(db);
			loser_rating = DB_GetRating(loser);
			ratings[loser] = loser_rating;
			SQL_UnlockDatabase(db);
		}

		if (winner_rating <= 0.0 || loser_rating <= 0.0) {
			return;
		}

		new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / 400.0));
		new Float:pLoser = 1.0 - pWinner;


		new Float:K = 12.0;
		if (winner_rating > 2000 || loser_rating > 2000) {
			K = 8.0;
		}

		new Float:winner_delta = K * (1.0 - pWinner);
		new Float:loser_delta =  K * (0.0 - pLoser);

		new Float:winner_rating_new  = winner_rating + winner_delta;
		new Float:loser_rating_new   = loser_rating  + loser_delta;

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

		ratings[winner] = winner_rating_new;
		ratings[loser] = loser_rating_new;
	}
}

DB_WriteRating(client) {
	if (ratings[client] > 199.0) {
		Format(sqlBuffer, sizeof(sqlBuffer), "UPDATE stats set rating = %f WHERE steamID = %d", ratings[client], ids[client]);
		SQL_TQuery(db, SQLErrorCheckCallback, sqlBuffer);
	}
}
