#include <sourcemod>

new g_maxArenas = 0; // maximum number of arenas the map can support

// Handles to arrays of vectors of spawns/angles:
new Handle:g_hTSpawns = INVALID_HANDLE;
new Handle:g_hTAngles = INVALID_HANDLE;
new Handle:g_hCTSpawns = INVALID_HANDLE;
new Handle:g_hCTAngles = INVALID_HANDLE;

/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public Spawns_MapInit() {
	g_maxArenas = 0;

	g_hTSpawns = CreateArray(3);
	g_hTAngles = CreateArray(3);
	g_hCTSpawns = CreateArray(3);
	g_hCTAngles = CreateArray(3);

	CloseHandleArray(g_hTSpawns);
	CloseHandleArray(g_hTAngles);
	CloseHandleArray(g_hCTSpawns);
	CloseHandleArray(g_hCTAngles);

	ClearArray(g_hTSpawns);
	ClearArray(g_hTAngles);
	ClearArray(g_hCTSpawns);
	ClearArray(g_hCTAngles);

	// spawn counts
	new ct = 0;
	new t = 0;

	new maxEnt = GetMaxEntities();
	decl String:sClassName[64], Float:fVec[3];

	// check if each entity is a spawn and add it
	for (new i = MaxClients; i < maxEnt; i++) {
		if (IsValidEdict(i) && IsValidEntity(i) && GetEdictClassname(i, sClassName, sizeof(sClassName))) {
			if (StrEqual(sClassName, "info_player_terrorist")) {
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVec);
				PushArrayArray(g_hTSpawns, fVec);
				GetEntPropVector(i, Prop_Data, "m_angRotation", fVec);
				PushArrayArray(g_hTAngles, fVec);
				t++;
			}
			else if (StrEqual(sClassName, "info_player_counterterrorist")) {
				GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVec);
				PushArrayArray(g_hCTSpawns, fVec);
				GetEntPropVector(i, Prop_Data, "m_angRotation", fVec);
				PushArrayArray(g_hCTAngles, fVec);
				ct++;
			}
		}
	}

	new minSpawns = (ct < t) ? ct : t;
	g_maxArenas = minSpawns;
}

CloseHandleArray(Handle:array) {
	new iSize = GetArraySize(array);
	new Handle:hZone;
	for (new i = 0 ; i < iSize; i++) {
		hZone = GetArrayCell(array, i);
		CloseHandle(hZone);
	}
}
