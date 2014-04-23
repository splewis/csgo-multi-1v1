/**
 * This file handles inserting boxes to block off zones for a map.
 * Config files are stored in addons/sourcemod/configs/brush/<MAPNAME>.cfg
 *
 */

#include <sourcemod>
#define BOX_NAME_LENGTH 128

new Handle:g_hBoxes = INVALID_HANDLE;		// array of the box entities spawned
new Handle:g_hNames = INVALID_HANDLE;		// name given to the box wall from the file
new Handle:g_hLocations1 = INVALID_HANDLE;  // 1st vector of box wall from the file
new Handle:g_hLocations2 = INVALID_HANDLE;  // 2nd vector of box wall from the file


public Boxes_MapInit() {
	g_hNames = CreateArray(BOX_NAME_LENGTH);
	g_hLocations1 = CreateArray(3);
	g_hLocations2 = CreateArray(3);
	Boxes_ParseMapConfig();
}

public Float:fmin(Float:x, Float:y) {
	if (x < y)
		return x;
	else
		return y;
}

public Float:fmax(Float:x, Float:y) {
	if (x > y)
		return x;
	else
		return y;
}

public Boxes_AddBoxes() {
	g_hBoxes = CreateArray();
	for (new i = 0; i < GetArraySize(g_hLocations1); i++) {
		new Float:loc1[3];
		new Float:loc2[3];
		GetArrayArray(g_hLocations1, i, loc1);
		GetArrayArray(g_hLocations2, i, loc2);

		new Float:x_0 = fmin(loc1[0], loc2[0]);
		new Float:y_0 = fmin(loc1[1], loc2[1]);
		new Float:z_0 = fmin(loc1[2], loc2[2]);

		new Float:x_f = fmax(loc1[0], loc2[0]);
		new Float:y_f = fmax(loc1[1], loc2[1]);
		new Float:z_f = fmax(loc1[2], loc2[2]);

		new Float:dx = 72.0;
		new Float:dy = 72.0;
		new Float:dz = 72.0;

		new Float:x = x_0;
		while (x <= x_f) {
			new Float:y = y_0;
			while (y <= y_f) {
				new Float:z = z_0;
				while (z <= z_f) {
					loc1[0] = x;
					loc1[1] = y;
					loc1[2] = z;
					loc2[0] = 0.0;
					loc2[1] = 0.0;
					loc2[2] = 0.0;
					// TODO: should this be a prop_static?
					CreateEntity("prop_dynamic_override", "models/props/props_crates/wooden_crate_64x64_dirt.mdl", loc1, loc2);
					z += dz;
				}
				y += dy;
			}
			x += dx;
		}
	}
}

bool:CreateEntity(const String:entType[], String:modelName[129], Float:point[3], Float:angle[3]) {
	new prop = -1;
	if (!IsModelPrecached(modelName)) {
    	if (!PrecacheModel(modelName)) {
    		return false;
    	}
    }
	// create new entity
	prop = CreateEntityByName(entType);

	if (IsValidEntity(prop)) {
		DispatchKeyValue(prop, "model", modelName);
		DispatchKeyValue(prop, "solid", "6");
		DispatchKeyValueVector(prop, "angles", angle);

		DispatchSpawn(prop);
		AcceptEntityInput(prop, "TurnOn", prop, prop, 0);
		TeleportEntity(prop, point, NULL_VECTOR, NULL_VECTOR);

		PushArrayCell(g_hBoxes, prop);
	} else {
		return false;
	}

	return true;
}

Boxes_ParseMapConfig() {
	CloseHandleArray(g_hLocations1);
	ClearArray(g_hLocations1);
	CloseHandleArray(g_hLocations2);
	ClearArray(g_hLocations2);

	decl String:sConfigFile[PLATFORM_MAX_PATH], String:sMap[128];
	GetCurrentMap(sMap, sizeof(sMap));
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/csgo1v1/%s.boxes", sMap);

	new Handle:kv = CreateKeyValues("BoxLocations");
	FileToKeyValues(kv, sConfigFile);
	if (!KvGotoFirstSubKey(kv)) {
		CloseHandle(kv);
		return;
	}

	new Float:vec[3];

	do {
		decl String:sBuffer[32];
		KvGetSectionName(kv, sBuffer, sizeof(sBuffer));
		PushArrayString(g_hNames, sBuffer)
		KvGetVector(kv, "location1", vec);
		PushArrayArray(g_hLocations1, vec, 3);
		KvGetVector(kv, "location2", vec);
		PushArrayArray(g_hLocations2, vec, 3);
	} while (KvGotoNextKey(kv));

	CloseHandle(kv);
}
