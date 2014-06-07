/**
 * Loads the spawn positions from the map and updates global spawn arrays.
 */
public Spawns_MapStart() {
    g_hTSpawns = CreateArray(3);
    g_hTAngles = CreateArray(3);
    g_hCTSpawns = CreateArray(3);
    g_hCTAngles = CreateArray(3);

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
            }  else if (StrEqual(sClassName, "info_player_counterterrorist")) {
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
    if (g_maxArenas <= 1) {
        LogError("Only found %d arenas for this map - %d T spawns and %d CT spawns", g_maxArenas, t, ct);
    } else {
        LogMessage("Found %d CT spawns and %d T spawns - using %d arenas", ct, t, g_maxArenas);
    }
}

Spawns_MapEnd() {
    CloseHandle(g_hTSpawns);
    CloseHandle(g_hTAngles);
    CloseHandle(g_hCTSpawns);
    CloseHandle(g_hCTAngles);
}