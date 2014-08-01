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
    if (IsValidClient(client))
        return GetOpponent(client);
    return -1;
}

public Native_HasDatabase(Handle:plugin, numParams) {
    return GetConVarInt(g_hUseDataBase) != 0 && g_dbConnected && db != INVALID_HANDLE;
}

public Native_GetDatabase(Handle:plugin, numParams) {
    return _:db;
}
