// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
   CreateNative("HasRating", Native_HasRating);
   CreateNative("GetRating", Native_GetRating);
   CreateNative("GetArenaNumber", Native_GetArenaNumber);
   CreateNative("GetRoundsAtArena1", Native_GetRoundsAtArena1);
   CreateNative("GetOpponent", Native_GetOpponent);
   return APLRes_Success;
}

public Native_HasRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    return IsPlayer(client) && g_FetchedPlayerInfo[client];
}

public Native_GetRating(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return _:0.0;
    else
        return _:g_ratings[client];
}

public Native_GetArenaNumber(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return -1;
    else
        return g_Rankings[client];
}

public Native_GetRoundsAtArena1(Handle:plugin, numParams) {
    new client =  GetNativeCell(1);
    if (!IsValidClient(client))
        return 0;
    else
        return g_roundsLeader[client];
}

public Native_GetOpponent(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    new other = -1;
    if (IsValidClient(client)) {
        new arena = g_Rankings[client];
        if (IsValidArena(arena)) {
            if (g_ArenaPlayer1[client] == client)
                other = g_ArenaPlayer2[client];
            else
                other = g_ArenaPlayer1[client];
        }
    }
    if (!IsValidClient(other))
        other = -1;
    return other;
}
