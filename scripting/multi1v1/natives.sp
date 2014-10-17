// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    CreateNative("Multi1v1_IsInArena", Native_IsInArena);
    CreateNative("Multi1v1_GetMaximumArenas", Native_GetMaximumArenas);
    CreateNative("Multi1v1_GetNumActiveArenas", Native_GetNumActiveArenas);
    CreateNative("Multi1v1_IsInWaitingQueue", Native_IsInWaitingQueue);
    CreateNative("Multi1v1_HasStats", Native_HasStats);
    CreateNative("Multi1v1_GetRating", Native_GetRating);
    CreateNative("Multi1v1_GetAwpRating", Native_GetAwpRating);
    CreateNative("Multi1v1_GetRifleRating", Native_GetRifleRating);
    CreateNative("Multi1v1_GetPistolRating", Native_GetPistolRating);
    CreateNative("Multi1v1_GetArenaNumber", Native_GetArenaNumber);
    CreateNative("Multi1v1_GetArenaPlayer1", Native_GetArenaPlayer1);
    CreateNative("Multi1v1_GetArenaPlayer2", Native_GetArenaPlayer2);
    CreateNative("Multi1v1_GetRoundsAtArena1", Native_GetRoundsAtArena1);
    CreateNative("Multi1v1_GetOpponent", Native_GetOpponent);
    CreateNative("Multi1v1_GetRoundsPlayed", Native_GetRoundsPlayed);
    CreateNative("Multi1v1_GetWins", Native_GetWins);
    CreateNative("Multi1v1_GetLosses", Native_GetLosses);
    CreateNative("Multi1v1_HasDatabase", Native_HasDatabase);
    CreateNative("Multi1v1_GetDatabase", Native_GetDatabase);
    CreateNative("Multi1v1_GivePlayerArenaWeapons", Native_GivePlayerArenaWeapons);
    CreateNative("Multi1v1_GivePlayerArenaWeaponsNoNades", Native_GivePlayerArenaWeaponsNoNades);
    CreateNative("Multi1v1_Message", Native_Multi1v1Message);
    CreateNative("Multi1v1_MessageToAll", Native_Multi1v1MessageToAll);
    CreateNative("Multi1v1_BlockRatingChanges", Native_BlockRatingChanges);
    CreateNative("Multi1v1_UnblockRatingChanges", Native_UnblockRatingChanges);
    CreateNative("Multi1v1_BlockChatMessages", Native_BlockChatMessages);
    CreateNative("Multi1v1_UnblockChatMessages", Native_UnblockChatMessages);
    CreateNative("Multi1v1_BlockMVPStars", Native_BlockMVPStars);
    CreateNative("Multi1v1_UnblockMVPStars", Native_UnblockMVPStars);
    CreateNative("Multi1v1_BlockArenaDones", Native_BlockArenaDones);
    CreateNative("Multi1v1_UnblockArenaDones", Native_UnblockArenaDones);
    CreateNative("Multi1v1_SetArenaOffsetValue", Native_SetArenaOffsetValue);
    CreateNative("Multi1v1_ELORatingDelta", Native_ELORatingDelta);
    CreateNative("Multi1v1_GetNumSpawnsInArena", Native_GetNumSpawnsInArena);
    CreateNative("Multi1v1_GetArenaSpawn", Native_GetArenaSpawn);
    RegPluginLibrary("multi1v1");
    return APLRes_Success;
}

public Native_IsInArena(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);
    return g_Ranking[client] > 0;
}

public Native_GetMaximumArenas(Handle plugin, numParams) {
    return g_maxArenas;
}

public Native_GetNumActiveArenas(Handle plugin, numParams) {
    return g_arenas;
}

public Native_IsInWaitingQueue(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return Queue_Inside(g_waitingQueue, client);
}

public Native_HasStats(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return IsConnected(client) && !IsFakeClient(client) && g_FetchedPlayerInfo[client];
}

public Native_GetRating(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return _:g_Rating[client];
}

public Native_GetAwpRating(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return _:g_AwpRating[client];
}

public Native_GetRifleRating(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return _:g_RifleRating[client];
}

public Native_GetPistolRating(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return _:g_PistolRating[client];
}

public Native_GetRoundsPlayed(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return g_Wins[client] + g_Losses[client];
}

public Native_GetWins(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return g_Wins[client];
}

public Native_GetLosses(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsConnected(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", client);
    return g_Losses[client];
}

public Native_GetArenaNumber(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);
    return g_Ranking[client];
}

public Native_GetRoundsAtArena1(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);
    return g_RoundsLeader[client];
}

public Native_GetArenaPlayer1(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    if (arena <= 0)
        ThrowNativeError(SP_ERROR_PARAM, "Arena %d is not valid", arena);
    return g_ArenaPlayer1[arena];
}

public Native_GetArenaPlayer2(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    if (arena <= 0)
        ThrowNativeError(SP_ERROR_PARAM, "Arena %d is not valid", arena);
    return g_ArenaPlayer2[arena];
}

public Native_GetOpponent(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (IsValidClient(client)) {
        int arena = g_Ranking[client];
        int other = -1;
        if (client != -1 && arena != -1) {
            other = g_ArenaPlayer1[arena];
            if (other == client)
                other = g_ArenaPlayer2[arena];
        }
        return other;
    }
    return -1;
}

public Native_HasDatabase(Handle plugin, numParams) {
    return GetConVarInt(g_hUseDatabase) != 0 && g_dbConnected && db != INVALID_HANDLE;
}

public Native_GetDatabase(Handle plugin, numParams) {
    if (!Multi1v1_HasDatabase()) {
        ThrowNativeError(SP_ERROR_PARAM, "The multi1v1 database is not connected");
        return _:INVALID_HANDLE;
    } else {
        return _:CloneHandle(db, plugin);
    }
}

public Native_GivePlayerArenaWeaponsNoNades(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    RoundType roundType = RoundType:GetNativeCell(2);

    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    Client_RemoveAllWeapons(client, "", true);

    if (roundType == RoundType_Rifle) {
        GiveWeapon(client, g_PrimaryWeapon[client]);
        SetEntData(client, g_iPlayers_HelmetOffset, 1);
        Client_SetArmor(client, 100);
    } else if (roundType == RoundType_Awp) {
        GiveWeapon(client, "weapon_awp");
        SetEntData(client, g_iPlayers_HelmetOffset, 1);
        Client_SetArmor(client, 100);
    } else if (roundType == RoundType_Pistol) {
        SetEntData(client, g_iPlayers_HelmetOffset, 0);
        bool giveKevlar = IsDefaultPistol(g_SecondaryWeapon[client]);
        if (giveKevlar) {
            Client_SetArmor(client, 100);
        } else {
            Client_SetArmor(client, 0);
        }
    } else {
        LogError("Unknown round type for %N: %d", client, roundType);
    }

    int pistolBehavior = GetConVarInt(g_hPistolBehavior);

    bool giveSelected = (roundType == RoundType_Pistol) ||
                        (pistolBehavior == 0) ||
                        (pistolBehavior == 3 && roundType != RoundType_Awp);

    bool giveFallback = (pistolBehavior == 2) ||
                        (pistolBehavior == 3 && roundType == RoundType_Awp);

    if (giveSelected) {
        GiveWeapon(client, g_SecondaryWeapon[client]);
    } else if (giveFallback) {
        char defaultPistol[32];
        GetConVarString(g_hDefaultPistol, defaultPistol, sizeof(defaultPistol));
        GiveWeapon(client,  defaultPistol);
    }

    GiveWeapon(client, "weapon_knife");
}

public Native_GivePlayerArenaWeapons(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    RoundType roundType = RoundType:GetNativeCell(2);
    Multi1v1_GivePlayerArenaWeaponsNoNades(client, roundType);
    int other = Multi1v1_GetOpponent(client);
    if (IsValidClient(other) && g_GiveFlash[client] && g_GiveFlash[other]) {
        GivePlayerItem(client, "weapon_flashbang");
    }
}

public Native_Multi1v1Message(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    char buffer[1024];
    int bytesWritten = 0;

    SetGlobalTransTarget(client);
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);
    Colorize(finalMsg, sizeof(finalMsg));

    PrintToChat(client, finalMsg);

    // Reset language back (TODO: may not be needed?)
    SetGlobalTransTarget(LANG_SERVER);
}

public Native_Multi1v1MessageToAll(Handle plugin, numParams) {
    char buffer[1024];
    int bytesWritten = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            SetGlobalTransTarget(i);
            FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

            char finalMsg[1024];
            Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);
            Colorize(finalMsg, sizeof(finalMsg));

            PrintToChat(i, finalMsg);
        }
    }

    // Reset language back (TODO: may not be needed?)
    SetGlobalTransTarget(LANG_SERVER);
}

public Native_BlockRatingChanges(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockStatChanges[client] = true;
}

public Native_UnblockRatingChanges(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockStatChanges[client] = false;
}

public Native_BlockChatMessages(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockChatMessages[client] = true;
}

public Native_UnblockChatMessages(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockChatMessages[client] = false;
}

public Native_BlockMVPStars(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockMVPStars[client] = true;
}

public Native_UnblockMVPStars(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);

    g_BlockMVPStars[client] = false;
}

public Native_BlockArenaDones(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    g_BlockArenaDones[arena] = true;
}

public Native_UnblockArenaDones(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    g_BlockArenaDones[arena] = false;
}

public Native_SetArenaOffsetValue(Handle plugin, numParams) {
    g_arenaOffsetValue = GetNativeCell(1);
}

public Native_ELORatingDelta(Handle plugin, numParams) {
    float winner_rating = GetNativeCell(1);
    float loser_rating = GetNativeCell(2);
    float K = GetNativeCell(3);
    float pWinner = 1.0 / (1.0 +  Pow(10.0, (loser_rating - winner_rating)  / DISTRIBUTION_SPREAD));
    float pLoser = 1.0 - pWinner;
    float winner_delta = K * pLoser;
    return _:winner_delta;
}

public Native_GetNumSpawnsInArena(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    Handle ct = Handle:GetArrayCell(g_hCTSpawns, arena);
    Handle t = Handle:GetArrayCell(g_hTSpawns, arena);
    return Math_Min(GetArraySize(ct), GetArraySize(t));
}

public Native_GetArenaSpawn(Handle plugin, numParams) {
    float origin[3];
    float angle[3];
    int arena = GetNativeCell(1);
    int team = GetNativeCell(2);

    if (arena <= 0 || arena > Multi1v1_GetMaximumArenas())
        ThrowNativeError(SP_ERROR_PARAM, "Arena %d is invalid", arena);
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        ThrowNativeError(SP_ERROR_PARAM, "Invalid team: %d", team);

    Handle spawns;
    Handle angles;
    if (team == CS_TEAM_CT) {
        spawns = Handle:GetArrayCell(g_hCTSpawns, arena - 1);
        angles = Handle:GetArrayCell(g_hCTAngles, arena - 1);
    } else {
        spawns = Handle:GetArrayCell(g_hTSpawns, arena - 1);
        angles = Handle:GetArrayCell(g_hTAngles, arena - 1);
    }

    int count = GetArraySize(spawns);
    int index = GetRandomInt(0, count - 1);
    GetArrayArray(spawns, index, origin);
    GetArrayArray(angles, index, angle);

    SetNativeArray(3, origin, sizeof(origin));
    SetNativeArray(4, angle, sizeof(angle));
}
