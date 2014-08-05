new String:g_TableFormat[][] = {
    "accountID INT NOT NULL PRIMARY KEY default 0",
    "auth varchar(64) NOT NULL default ''",
    "name varchar(64) NOT NULL default ''",
    "wins INT NOT NULL default 0",
    "losses INT NOT NULL default 0",
    "rating FLOAT NOT NULL default 1500.0",
    "lastTime INT default 0 NOT NULL",
    "recentRounds INT default 0 NOT NULL"
};

/**
 * Attempts to connect to the database.
 * Creates the stats (TABLE_NAME) if needed.
 */
public DB_Connect() {
    new String:error[255];
    new String:dbCfgName[255];
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
               "SELECT rating, wins, losses FROM %s WHERE accountID = %d",
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
        g_Wins[client] = SQL_FetchInt(hndl, 1);
        g_Losses[client] = SQL_FetchInt(hndl, 2);
        g_FetchedPlayerInfo[client] = true;
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
               "UPDATE %s set rating = %f WHERE accountID = %d",
               TABLE_NAME, g_Rating[client], GetSteamAccountID(client));
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

        if (GetConVarInt(g_hUseDataBase) == 0)
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
public Increment(client, const String:field[]) {
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

/**
 * Fetches, if needed, and calculates the relevent players' new ratings.
 */
public UpdateRatings(winner, loser, bool:forceLoss) {
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

        new bool:block = g_BlockStatChanges[winner] || g_BlockStatChanges[loser];
        if (block)
            return;

        if (forceLoss) {
            ForceLoss(winner, loser);
            return;
        }

        if (IsValidClient(winner) && IsValidClient(loser)) {
            new Float:delta = ELORatingDelta(g_Rating[winner], g_Rating[loser], K_FACTOR);
            RatingMessage(winner, loser, g_Rating[winner], g_Rating[loser], delta);
            g_Rating[winner] += delta;
            g_Rating[loser] -= delta;
            DB_WriteRatings(winner);
            DB_WriteRatings(loser);
        }
    }
}

static ForceLoss(winner, loser) {
    new Float:delta = K_FACTOR / 2.0;
    g_Rating[winner] -= delta;
    g_Rating[loser] -= delta;
    DB_WriteRatings(winner);
    DB_WriteRatings(loser);
    ForceLossMessage(winner, g_Rating[winner], delta);
    ForceLossMessage(loser, g_Rating[loser], delta);
}

static RatingMessage(winner, loser, Float:winner_rating, Float:loser_rating, Float:delta) {
    Multi1v1Message(winner, "\x04You \x01(rating \x04%.1f\x01, \x06+%.1f\x01) beat \x03%N \x01(rating \x03%.1f\x01, \x02-%.1f\x01)",
                    winner_rating, delta, loser, loser_rating, delta);
    Multi1v1Message(loser,  "\x04You \x01(rating \x04%.1f\x01, \x07-%.1f\x01) lost to \x03%N \x01(rating \x03%.1f\x01, \x06+%.1f\x01)",
                    loser_rating, delta, winner, winner_rating, delta);
}

static ForceLossMessage(client, Float:rating, Float:delta) {
    Multi1v1Message(client, "\x04You \x01(rating \x04%.1f\x01, \x07-%.1f\x01) let time run out",
                   rating, delta);
}

public Action:Command_Stats(client, args) {
    new String:arg1[32];
    if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
        new target = FindTarget(client, arg1, true, false);
        if (target != -1) {
            ShowStatsForPlayer(client, target);
        }
    } else {
        ShowStatsForPlayer(client, client);
    }

    return Plugin_Handled;
}

public ShowStatsForPlayer(client, target) {
    decl String:url[255];
    GetConVarString(g_hStatsWebsite, url, sizeof(url));
    if (StrEqual(url, "")) {
        Multi1v1Message(client, "Sorry, there is no stats website for this server.");
        return;
    }

    decl String:player_url[255];
    Format(player_url, sizeof(player_url), "%s%d", url, GetSteamAccountID(target));
    ShowMOTDPanel(client, "Multi1v1 Stats", player_url, MOTDPANEL_TYPE_URL);
}

public Float:ELORatingDelta(Float:winner_rating, Float:loser_rating, Float:K) {
    new Float:pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / DISTRIBUTION_SPREAD));
    new Float:pLoser = 1.0 - pWinner;
    new Float:winner_delta = K * pLoser;
    return winner_delta;
}
