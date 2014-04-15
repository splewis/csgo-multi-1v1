#include <sourcemod>
new Handle:g_hAngles = INVALID_HANDLE;

public Angles_MapInit() {
	g_hAngles = CreateArray(2);
	ParseMapConfig();
}

ParseMapConfig() {
	CloseHandleArray(g_hAngles);
	ClearArray(g_hAngles);

	decl String:cfgFile[PLATFORM_MAX_PATH], String:sMap[128];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, cfgFile, sizeof(cfgFile), "configs/csgo1v1/%s.angles", sMap);


	if (!FileExists(cfgFile)) {
		LogMessage("No spawns file (%s).", cfgFile);
		ClearArray(g_hAngles);
		return;
	}

	new Float:vec[3];
	new Handle:KV = CreateKeyValues(cfgFile);
	LogMessage("%s", cfgFile);
	if (FileToKeyValues(KV, cfgFile) && KvGotoFirstSubKey(KV, false)) {
		do { // load spawns
			KvGetVector(KV, NULL_STRING, vec);
			PushArrayArray(g_hAngles, vec);
			LogMessage("%f %f %f", vec[0], vec[1], vec[2]);
		} while (KvGotoNextKey(KV, false));
	}
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
