#include <sourcemod>

new g_numSpawns = 0;
new g_maxArenas = 0;
new Handle:g_hSpawns = INVALID_HANDLE;
new Handle:g_hAngles = INVALID_HANDLE;

public Spawns_MapInit() {
	g_numSpawns = 0;
	g_maxArenas = 0;
	g_hSpawns = CreateArray(3);
	g_hAngles = CreateArray(3);
	Spawns_ParseMapConfig();
}

Spawns_ParseMapConfig() {
	CloseHandleArray(g_hSpawns);
	CloseHandleArray(g_hAngles);
	ClearArray(g_hSpawns);
	ClearArray(g_hAngles);

	decl String:cfgFile[PLATFORM_MAX_PATH], String:sMap[128];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, cfgFile, sizeof(cfgFile), "configs/multi1v1/%s.cfg", sMap);


	if (!FileExists(cfgFile)) {
		LogMessage("No multi1v1-config file (%s).", cfgFile);
		ClearArray(g_hSpawns);
		ClearArray(g_hAngles);
		return;
	}

	new count = 0;
	new String:buffer[127];
	new Float:vec[3];
	new Handle:KV = CreateKeyValues(cfgFile);

	if (FileToKeyValues(KV, cfgFile) && KvGotoFirstSubKey(KV, false)) {
		do {
			count++;
			KvGetSectionName(KV, buffer, sizeof(buffer));
			KvGetVector(KV, "origin", vec);
			PushArrayArray(g_hSpawns, vec);
			KvGetVector(KV, "angle", vec);
			PushArrayArray(g_hAngles, vec);
		} while (KvGotoNextKey(KV, false));
	}

	g_numSpawns = count;
	g_maxArenas = count / 2;

	CloseHandle(KV);
}

stock CloseHandleArray(Handle:adt_array) {
	new iSize = GetArraySize(adt_array);
	new Handle:hZone;
	for (new i = 0 ; i < iSize; i++) {
		hZone = GetArrayCell(adt_array, i);
		CloseHandle(hZone);
	}
}
