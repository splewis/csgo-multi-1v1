// See include/multi1v1.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    CreateNative("Multi1v1Message", Native_Multi1v1Message);
    CreateNative("Multi1v1MessageToAll", Native_Multi1v1MessageToAll);
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
    CreateNative("GetPlayerRifle", Native_GetPlayerRifle);
    CreateNative("GetPlayerPistol", Native_GetPlayerPistol);
    CreateNative("DoesPlayerAllowFlashbangs", Native_DoesPlayerAllowFlashbangs);
    CreateNative("GivePlayerArenaWeapons", Native_GivePlayerArenaWeapons);
    CreateNative("HasDatabase", Native_HasDatabase);
    CreateNative("GetDatabase", Native_GetDatabase);
    CreateNative("RatingMessage", Native_RatingMessage);
    CreateNative("ForceLossMessage", Native_ForceLossMessage);
    RegPluginLibrary("multi1v1");
    return APLRes_Success;
}

public Native_Multi1v1Message(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsPlayer(client))
        return;

    decl String:buffer[1024];
    new writtenBytes;
    FormatNativeString(0, 2, 3, sizeof(buffer), writtenBytes, buffer);
    PrintToChat(client, "%s%s", MESSAGE_PREFIX, buffer);
}

public Native_Multi1v1MessageToAll(Handle:plugin, numParams) {
    decl String:buffer[1024];
    new writtenBytes;
    FormatNativeString(0, 1, 2, sizeof(buffer), writtenBytes, buffer);
    PrintToChatAll("%s%s", MESSAGE_PREFIX, buffer);
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

public Native_GetPlayerRifle(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return false;
    SetNativeString(2, g_PrimaryWeapon[client], GetNativeCell(3));
    return true;
}

public Native_GetPlayerPistol(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return false;
    SetNativeString(2, g_SecondaryWeapon[client], GetNativeCell(3));
    return true;
}

public Native_DoesPlayerAllowFlashbangs(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    if (!IsValidClient(client))
        return false;
    return g_GiveFlash[client];
}

public Native_GivePlayerArenaWeapons(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    new RoundType:roundType = RoundType:GetNativeCell(2);
    if (!IsValidClient(client))
        return;
    GivePlayerArenaWeapons(client, roundType);
}

public Native_HasDatabase(Handle:plugin, numParams) {
    return GetConVarInt(g_hUseDataBase) != 0 && g_dbConnected && db != INVALID_HANDLE;
}

public Native_GetDatabase(Handle:plugin, numParams) {
    return _:db;
}

public Native_RatingMessage(Handle:plugin, numParams) {
    new winner = GetNativeCell(1);
    new loser = GetNativeCell(2);
    new int_winner = GetNativeCell(3);
    new int_loser = GetNativeCell(4);
    new int_delta = GetNativeCell(5);
    RatingMessage(winner, loser, int_winner, int_loser, int_delta);
}

public Native_ForceLossMessage(Handle:plugin, numParams) {
    new winner = GetNativeCell(1);
    new int_rating = GetNativeCell(2);
    new int_delta = GetNativeCell(3);
    ForceLossMessage(winner, int_rating, int_delta);
}
