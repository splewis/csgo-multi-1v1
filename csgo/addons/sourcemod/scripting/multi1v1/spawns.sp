/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public Spawns_MapStart() {
    g_hTSpawns = CreateArray(3);
    g_hTAngles = CreateArray(3);
    g_hCTSpawns = CreateArray(3);
    g_hCTAngles = CreateArray(3);

    new numTSpawns = 0;
    new numCTSpawns = 0;

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
                numTSpawns++;
            }  else if (StrEqual(sClassName, "info_player_counterterrorist")) {
                GetEntPropVector(i, Prop_Data, "m_vecOrigin", fVec);
                PushArrayArray(g_hCTSpawns, fVec);
                GetEntPropVector(i, Prop_Data, "m_angRotation", fVec);
                PushArrayArray(g_hCTAngles, fVec);
                numCTSpawns++;
            }
        }
    }


    new minSpawns = (numCTSpawns < numTSpawns) ? numCTSpawns : numTSpawns;
    g_maxArenas = minSpawns;
    if (g_maxArenas <= 1) {
        LogError("Only found %d arenas for this map - %d T spawns and %d CT spawns", g_maxArenas, numTSpawns, numCTSpawns);
    } else {
        LogMessage("Found %d CT spawns and %d T spawns - using %d arenas", numCTSpawns, numTSpawns, g_maxArenas);
    }
}

Spawns_MapEnd() {
    CloseHandle(g_hTSpawns);
    CloseHandle(g_hTAngles);
    CloseHandle(g_hCTSpawns);
    CloseHandle(g_hCTAngles);
}
