// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    CreateNative("GetMaximumArenas", Native_GetMaximumArenas);
    CreateNative("GetNumActiveArenas", Native_GetNumActiveArenas);
    CreateNative("IsInWaitingQueue", Native_IsInWaitingQueue);
    CreateNative("GetWaitingQueue", Native_GetWaitingQueue);
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
    RegPluginLibrary("multi1v1");
    return APLRes_Success;
}

public Native_GetMaximumArenas(Handle:plugin, numParams) {
    return g_maxArenas;
}

public Native_GetNumActiveArenas(Handle:plugin, numParams) {
    return g_arenas;
}

public Native_IsInWaitingQueue(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    return Queue_Inside(g_waitingQueue, client);
}

public Native_GetWaitingQueue(Handle:plugin, numParams) {
    return _:g_waitingQueue;
}

public Native_HasStats(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    return IsPlayer(client) && g_FetchedPlayerInfo[client];
}

public Native_GetRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_Rating[client];
}

public Native_GetRoundsPlayed(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Wins[client] + g_Losses[client];
}

public Native_GetWins(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Wins[client];
}

public Native_GetLosses(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_Losses[client];
}
public Native_GetArenaNumber(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return -1;
    else
        return g_Ranking[client];
}

public Native_GetRoundsAtArena1(Handle:plugin, numParams) {
    new client =  GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_RoundsLeader[client];
}

public Native_GetOpponent(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (IsValidClient(client)) {
        new arena = g_Ranking[client];
        new other = -1;
        if (client != -1 && arena != -1) {
            other = g_ArenaPlayer1[arena];
            if (other == client)
                other = g_ArenaPlayer2[arena];
        }
        return other;
    }
    return -1;
}

public Native_HasDatabase(Handle:plugin, numParams) {
    return GetConVarInt(g_hUseDataBase) != 0 && g_dbConnected && db != INVALID_HANDLE;
}

public Native_GetDatabase(Handle:plugin, numParams) {
    return _:db;
}

public Native_GivePlayerArenaWeapons(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    new RoundType:roundType = RoundType:GetNativeCell(2);

    Client_RemoveAllWeapons(client, "", true);
    if (roundType == RoundType_Rifle) {
       GivePlayerItem(client, g_PrimaryWeapon[client]);
    } else if (roundType == RoundType_Awp) {
        GivePlayerItem(client, "weapon_awp");
    } else if (roundType == RoundType_Pistol) {
        RemoveVestHelm(client);
    } else {
        LogError("Unknown round type for %N: %d", client, roundType);
    }

    GivePlayerItem(client, g_SecondaryWeapon[client]);

    new other = GetOpponent(client);
    if (IsValidClient(other) && g_GiveFlash[client] && g_GiveFlash[other]) {
        GivePlayerItem(client, "weapon_flashbang");
    }

    GivePlayerItem(client, "weapon_knife");
}

public Native_Multi1v1Message(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    decl String:buffer[1024];
    new bytesWritten = 0;
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    decl String:finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    PrintToChat(client, finalMsg);
}

public Native_Multi1v1MessageToAll(Handle:plugin, numParams) {
    decl String:buffer[1024];
    new bytesWritten = 0;
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    decl String:finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    PrintToChatAll(finalMsg);
}
