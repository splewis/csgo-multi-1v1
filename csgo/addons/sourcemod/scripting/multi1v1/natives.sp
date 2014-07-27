// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
   CreateNative("HasStats", Native_HasStats);
   CreateNative("GetRating", Native_GetRating);
   CreateNative("GetRifleRating", Native_GetRifleRating);
   CreateNative("GetAwpRating", Native_GetAwpRating);
   CreateNative("GetPistolRating", Native_GetPistolRating);
   CreateNative("GetArenaNumber", Native_GetArenaNumber);
   CreateNative("GetRoundsAtArena1", Native_GetRoundsAtArena1);
   CreateNative("GetOpponent", Native_GetOpponent);
   RegPluginLibrary("multi1v1");
   return APLRes_Success;
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

public Native_GetAwpRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_AwpRating[client];
}

public Native_GetPistolRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_PistolRating[client];
}

public Native_GetRifleRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_RifleRating[client];
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
