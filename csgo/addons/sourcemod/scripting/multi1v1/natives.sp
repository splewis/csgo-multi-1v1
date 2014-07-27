// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
   CreateNative("GetMaxArenas", Native_GetMaxArenas);
   CreateNative("GetNumActiveArenas", Native_GetNumActiveArenas);
   CreateNative("IsInWaitingQueue", Native_IsInWaitingQueue);
   CreateNative("GetWaitingQueue", Native_GetWaitingQueue);
   CreateNative("HasStats", Native_HasStats);
   CreateNative("GetRating", Native_GetRating);
   CreateNative("GetArenaNumber", Native_GetArenaNumber);
   CreateNative("GetRoundsAtArena1", Native_GetRoundsAtArena1);
   CreateNative("GetOpponent", Native_GetOpponent);
   RegPluginLibrary("multi1v1");
   return APLRes_Success;
}

public Native_GetMaxArenas(Handle:plugin, numParams) {
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
