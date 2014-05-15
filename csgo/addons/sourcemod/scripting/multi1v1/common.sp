#if !defined multi1v1_common
#define multi1v1_common 1

#if !defined ASSERTIONS
#define ASSERTIONS 1
#endif

new String:assertBuffer[1024];
/**
 * Generic assertion function. Change the ASSERT_FUNCTION if you want.
 */
public Assert(bool:value, const String:msg[] , any:...) {
	if (ASSERTIONS && !value) {
		VFormat(assertBuffer, sizeof(assertBuffer), msg, 3);
		LogError(assertBuffer);
	}
}

/**
 * Removes the radar element from a client's HUD.
 */
public Action:RemoveRadar(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client))
		SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}

/**
 * Function to identify if a client is valid and in game.
 */
bool:IsValidClient(client) {
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}

/**
 * Closes an adt array.
 */
CloseHandleArray(Handle:array) {
    new iSize = GetArraySize(array);
    new Handle:hZone;
    for (new i = 0 ; i < iSize; i++) {
        hZone = GetArrayCell(array, i);
        CloseHandle(hZone);
    }
}


#endif
