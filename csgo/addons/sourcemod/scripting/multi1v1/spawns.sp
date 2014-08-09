#define SAME_ARENA_THRESHOLD 1600.0

/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public Spawns_MapStart() {
    // Note: these are arrays of arrays!
    // Each index corresponds to the data for THAT arena.
    // Example: g_hTspawns[0] has a handle to another adt array - that array contains
    //   the 3-vectors of spawns.
    g_hTSpawns = CreateArray();
    g_hTAngles = CreateArray();
    g_hCTSpawns = CreateArray();
    g_hCTAngles = CreateArray();

    new bool:verbose = GetConVarInt(g_hVerboseSpawnModes) != 0;

    new maxEnt = GetMaxEntities();
    decl String:sClassName[64];
    new Float:spawn[3];
    new Float:angle[3];

    // Check if each entity is a spawn and add it
    for (new i = MaxClients; i < maxEnt; i++) {
        new bool:valid = IsValidEdict(i) && IsValidEntity(i);
        if (valid && GetEdictClassname(i, sClassName, sizeof(sClassName))) {

            if (StrEqual(sClassName, "info_player_terrorist")) {
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", spawn);
                GetEntPropVector(i, Prop_Data, "m_angRotation", angle);
                AddSpawn(spawn, angle, g_hTSpawns, g_hTAngles);
                if (verbose)
                    LogMessage("T spawn (ent %d) %f %f %f",
                               i, spawn[0], spawn[1], spawn[2]);

            }  else if (StrEqual(sClassName, "info_player_counterterrorist")) {
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", spawn);
                GetEntPropVector(i, Prop_Data, "m_angRotation", angle);
                AddSpawn(spawn, angle, g_hCTSpawns, g_hCTAngles);
                if (verbose)
                    LogMessage("CT spawn (ent %d) %f %f %f",
                               i, spawn[0], spawn[1], spawn[2]);
            }
        }
    }

    new ct = GetArraySize(g_hCTSpawns);
    new t = GetArraySize(g_hTSpawns);
    g_maxArenas = (ct < t) ? ct : t;

    new bool:takenTSpawns[g_maxArenas];
    for (new i = 0; i < g_maxArenas; i++)
        takenTSpawns[i] = false;


    // Looping through CT spawn clusters, matching the nearest T spawn cluster to each
    for (new i = 0; i < g_maxArenas; i++) {
        new Handle:ct_spawns = GetArrayCell(g_hCTSpawns, i);

        new closestIndex = -1;
        new Float:closestDist = 0.0;

        for (new j = 0; j < g_maxArenas; j++) {
            if (takenTSpawns[j])
                continue;

            new Handle:t_spawns = GetArrayCell(g_hTSpawns, j);
            new Float:vec1[3];
            new Float:vec2[3];
            GetArrayArray(ct_spawns, 0, vec1);
            GetArrayArray(t_spawns, 0, vec2);
            new Float:dist = GetVectorDistance(vec1, vec2);

            if (closestIndex < 0 || dist < closestDist) {
                closestIndex = j;
                closestDist = dist;
            }
        }

        SwapArrayItems(g_hTSpawns, i, closestIndex);
        SwapArrayItems(g_hTAngles, i, closestIndex);
        takenTSpawns[i] = true;
    }

    // More Helpful logging for map developers
    if (verbose) {
        for (new i = 0; i < g_maxArenas; i++) {
            LogMessage("Cluster %d:", i + 1);

            new Handle:ct_spawns = GetArrayCell(g_hCTSpawns, i);
            for (new j = 0; j < GetArraySize(ct_spawns); j++) {
                new Float:vec[3];
                GetArrayArray(ct_spawns, j, vec);
                LogMessage("  CT Spawn %d: %f %f %f", j, vec[0], vec[1], vec[2]);
            }

            new Handle:t_spawns = GetArrayCell(g_hTSpawns, i);
            for (new j = 0; j < GetArraySize(t_spawns); j++) {
                new Float:vec[3];
                GetArrayArray(t_spawns, j, vec);
                LogMessage("  T Spawn  %d: %f %f %f", j, vec[0], vec[1], vec[2]);
            }

        }
    }

    if (g_maxArenas <= 0) {
        LogError("No arenas could be found for this map!");
    }

}

static AddSpawn(Float:spawn[3], Float:angle[3], Handle:spawnList, Handle:angleList) {
    for (new i = 0; i < GetArraySize(spawnList); i++) {
        new Handle:spawns = Handle:GetArrayCell(spawnList, i);
        new Handle:angles = Handle:GetArrayCell(angleList, i);
        new closestIndex = NearestNeighborIndex(spawn, spawns);

        if (closestIndex >= 0) {
            new Float:closestSpawn[3];
            GetArrayArray(spawns, closestIndex, closestSpawn);
            new Float:dist = GetVectorDistance(spawn, closestSpawn);

            if (dist < SAME_ARENA_THRESHOLD) {
                PushArrayArray(spawns, spawn);
                PushArrayArray(angles, angle);
                return;
            }
        }
    }

    new Handle:spawns = CreateArray(3);
    new Handle:angles = CreateArray(3);
    PushArrayArray(spawns, spawn);
    PushArrayArray(angles, angle);
    PushArrayCell(spawnList, spawns);
    PushArrayCell(angleList, angles);
}

public GetSpawn(arena, team, Float:origin[3], Float:angle[3]) {
    if (team == CS_TEAM_CT) {
        new Handle:spawns = Handle:GetArrayCell(g_hCTSpawns, arena - 1);
        new Handle:angles = Handle:GetArrayCell(g_hCTAngles, arena - 1);
        new count = GetArraySize(spawns);
        new index = GetRandomInt(0, count - 1);
        GetArrayArray(spawns, index, origin);
        GetArrayArray(angles, index, angle);
    } else if (team == CS_TEAM_T) {
        new Handle:spawns = Handle:GetArrayCell(g_hTSpawns, arena - 1);
        new Handle:angles = Handle:GetArrayCell(g_hTAngles, arena - 1);
        new count = GetArraySize(spawns);
        new index = GetRandomInt(0, count - 1);
        GetArrayArray(spawns, index, origin);
        GetArrayArray(angles, index, angle);
    } else {
        LogError("Trying to find a spawn for a player not on a team! arena=%d, team=%d",
                 arena, team);
    }
}

Spawns_MapEnd() {
    CloseHandleArray(g_hTSpawns);
    CloseHandleArray(g_hTAngles);
    CloseHandleArray(g_hCTSpawns);
    CloseHandleArray(g_hCTAngles);
}
