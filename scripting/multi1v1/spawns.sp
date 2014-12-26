#define SAME_ARENA_THRESHOLD 1600.0

/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public void Spawns_MapStart() {
    // Note: these are arrays of arrays!
    // Each index corresponds to the data for THAT arena.
    // Example: g_hTspawns[0] has a handle to another adt array - that array contains
    //   the 3-vectors of spawns.
    g_hTSpawns = CreateArray();
    g_hTAngles = CreateArray();
    g_hCTSpawns = CreateArray();
    g_hCTAngles = CreateArray();

    bool verbose = GetConVarInt(g_hVerboseSpawnModes) != 0;

    int maxEnt = GetMaxEntities();
    char sClassName[64];
    float spawn[3];
    float angle[3];

    // Check if each entity is a spawn and add it
    for (int i = MaxClients; i < maxEnt; i++) {
        bool valid = IsValidEdict(i) && IsValidEntity(i);
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

    int ct = GetArraySize(g_hCTSpawns);
    int t = GetArraySize(g_hTSpawns);
    g_maxArenas = (ct < t) ? ct : t;

    bool[] takenTSpawns = new bool[g_maxArenas];
    for (int i = 0; i < g_maxArenas; i++)
        takenTSpawns[i] = false;


    // Looping through CT spawn clusters, matching the nearest T spawn cluster to each
    for (int i = 0; i < g_maxArenas; i++) {
        Handle ct_spawns = GetArrayCell(g_hCTSpawns, i);

        int closestIndex = -1;
        float closestDist = 0.0;

        for (int j = 0; j < g_maxArenas; j++) {
            if (takenTSpawns[j])
                continue;

            Handle t_spawns = GetArrayCell(g_hTSpawns, j);
            float vec1[3];
            float vec2[3];
            GetArrayArray(ct_spawns, 0, vec1);
            GetArrayArray(t_spawns, 0, vec2);
            float dist = GetVectorDistance(vec1, vec2);

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
        for (int i = 0; i < g_maxArenas; i++) {
            LogMessage("Cluster %d:", i + 1);

            Handle ct_spawns = GetArrayCell(g_hCTSpawns, i);
            for (int j = 0; j < GetArraySize(ct_spawns); j++) {
                float vec[3];
                GetArrayArray(ct_spawns, j, vec);
                LogMessage("  CT Spawn %d: %f %f %f", j + 1, vec[0], vec[1], vec[2]);
            }

            Handle t_spawns = GetArrayCell(g_hTSpawns, i);
            for (int j = 0; j < GetArraySize(t_spawns); j++) {
                float vec[3];
                GetArrayArray(t_spawns, j, vec);
                LogMessage("  T Spawn  %d: %f %f %f", j + 1, vec[0], vec[1], vec[2]);
            }

        }
    }

    if (g_maxArenas <= 0) {
        LogError("No arenas could be found for this map!");
    }

}

static void AddSpawn(float spawn[3], float angle[3], Handle spawnList, Handle angleList) {
    for (int i = 0; i < GetArraySize(spawnList); i++) {
        Handle spawns = Handle:GetArrayCell(spawnList, i);
        Handle angles = Handle:GetArrayCell(angleList, i);
        int closestIndex = NearestNeighborIndex(spawn, spawns);

        if (closestIndex >= 0) {
            float closestSpawn[3];
            GetArrayArray(spawns, closestIndex, closestSpawn);
            float dist = GetVectorDistance(spawn, closestSpawn);

            if (dist < SAME_ARENA_THRESHOLD) {
                PushArrayArray(spawns, spawn);
                PushArrayArray(angles, angle);
                return;
            }
        }
    }

    Handle spawns = CreateArray(3);
    Handle angles = CreateArray(3);
    PushArrayArray(spawns, spawn);
    PushArrayArray(angles, angle);
    PushArrayCell(spawnList, spawns);
    PushArrayCell(angleList, angles);
}

public void Spawns_MapEnd() {
    CloseHandleArray(g_hTSpawns);
    CloseHandleArray(g_hTAngles);
    CloseHandleArray(g_hCTSpawns);
    CloseHandleArray(g_hCTAngles);
}
