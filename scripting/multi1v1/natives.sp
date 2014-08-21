// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    CreateNative("IsInArena", Native_IsInArena);
    CreateNative("GetMaximumArenas", Native_GetMaximumArenas);
    CreateNative("GetNumActiveArenas", Native_GetNumActiveArenas);
    CreateNative("IsInWaitingQueue", Native_IsInWaitingQueue);
    CreateNative("HasStats", Native_HasStats);
    CreateNative("GetRating", Native_GetRating);
    CreateNative("GetArenaNumber", Native_GetArenaNumber);
    CreateNative("GetRoundsAtArena1", Native_GetRoundsAtArena1);
    CreateNative("GetOpponent", Native_GetOpponent);
    CreateNative("GetRoundsPlayed", Native_GetRoundsPlayed);
    CreateNative("GetWins", Native_GetWins);
    CreateNative("GetLosses", Native_GetLosses);
    CreateNative("HasDatabase", Native_HasDatabase);
    CreateNative("GetDatabase", Native_GetDatabase);
    CreateNative("GivePlayerArenaWeapons", Native_GivePlayerArenaWeapons);
    CreateNative("Multi1v1Message", Native_Multi1v1Message);
    CreateNative("Multi1v1MessageToAll", Native_Multi1v1MessageToAll);
    CreateNative("BlockRatingChanges", Native_BlockRatingChanges);
    CreateNative("UnblockRatingChanges", Native_UnblockRatingChanges);
    CreateNative("BlockChatMessages", Native_BlockChatMessages);
    CreateNative("UnblockChatMessages", Native_UnblockChatMessages);
    CreateNative("SetArenaOffsetValue", Native_SetArenaOffsetValue);
    CreateNative("ELORatingDelta", Native_ELORatingDelta);
    CreateNative("GetNumSpawnsInArena", Native_GetNumSpawnsInArena);
    CreateNative("GetArenaSpawn", Native_GetArenaSpawn);
    RegPluginLibrary("multi1v1");
    return APLRes_Success;
}

public Native_IsInArena(Handle plugin, numParams) {
    int client = GetNativeCell(0);
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
    return Queue_Inside(g_waitingQueue, client);
}

public Native_HasStats(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    return IsPlayer(client) && g_FetchedPlayerInfo[client];
}

public Native_GetRating(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_Rating[client];
}

public Native_GetRoundsPlayed(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Wins[client] + g_Losses[client];
}

public Native_GetWins(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Wins[client];
}

public Native_GetLosses(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Losses[client];
}
public Native_GetArenaNumber(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        return -1;
    else
        return g_Ranking[client];
}

public Native_GetRoundsAtArena1(Handle plugin, numParams) {
    int client =  GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_RoundsLeader[client];
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
    return _:db;
}

public Native_GivePlayerArenaWeapons(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    RoundType roundType = RoundType:GetNativeCell(2);

    Client_RemoveAllWeapons(client, "", true);
    if (roundType == RoundType_Rifle) {
        GivePlayerItem(client, g_PrimaryWeapon[client]);
    } else if (roundType == RoundType_Awp) {
        GivePlayerItem(client, "weapon_awp");
    } else if (roundType == RoundType_Pistol) {
        // Do nothing!
    } else {
        LogError("Unknown round type for %N: %d", client, roundType);
    }

    GiveVestHelm(client, roundType);
    GivePlayerItem(client, g_SecondaryWeapon[client]);

    int other = GetOpponent(client);
    if (IsValidClient(other) && g_GiveFlash[client] && g_GiveFlash[other]) {
        GivePlayerItem(client, "weapon_flashbang");
    }

    GivePlayerItem(client, "weapon_knife");
}

public Native_Multi1v1Message(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    PrintToChat(client, finalMsg);
}

public Native_Multi1v1MessageToAll(Handle plugin, numParams) {
    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    PrintToChatAll(finalMsg);
}

public Native_BlockRatingChanges(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    g_BlockStatChanges[client] = true;
}

public Native_UnblockRatingChanges(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    g_BlockStatChanges[client] = false;
}

public Native_BlockChatMessages(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    g_BlockChatMessages[client] = true;
}

public Native_UnblockChatMessages(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    g_BlockChatMessages[client] = false;
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
    return Min(GetArraySize(ct), GetArraySize(t));
}

public Native_GetArenaSpawn(Handle plugin, numParams) {
    int arena = GetNativeCell(1);
    int team = GetNativeCell(2);
    float origin[3];
    float angle[3];
    GetNativeArray(3, origin, sizeof(origin));
    GetNativeArray(4, angle, sizeof(angle));
    GetSpawn(arena, team, origin, angle);
}
