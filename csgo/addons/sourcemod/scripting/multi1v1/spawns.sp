#include <sourcemod>

new g_numSpawns = 0;
new g_maxArenas = 0;
new Handle:g_hTSpawns = INVALID_HANDLE;
new Handle:g_hTAngles = INVALID_HANDLE;
new Handle:g_hCTSpawns = INVALID_HANDLE;
new Handle:g_hCTAngles = INVALID_HANDLE;

public Spawns_MapInit() {
	g_numSpawns = 0;
	g_maxArenas = 0;

	g_hTSpawns = CreateArray(3);
	g_hTAngles = CreateArray(3);
	g_hCTSpawns = CreateArray(3);
	g_hCTAngles = CreateArray(3);

	ClearArray(g_hTSpawns);
	ClearArray(g_hTAngles);
	ClearArray(g_hCTSpawns);
	ClearArray(g_hCTAngles);

	new ct = 0;
	new t = 0;

	new maxEnt = GetMaxEntities();
	decl String:sClassName[64], Float:fVec[3];
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

	g_numSpawns = t + ct;
	g_maxArenas = g_numSpawns / 2;
}

stock CloseHandleArray(Handle:adt_array) {
	new iSize = GetArraySize(adt_array);
	new Handle:hZone;
	for (new i = 0 ; i < iSize; i++) {
		hZone = GetArrayCell(adt_array, i);
		CloseHandle(hZone);
	}
}
