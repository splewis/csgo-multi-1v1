
public Action:Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay) {
    new shooterIndex = TE_ReadNum("m_iPlayer") + 1;
    PrintToChatAll("shot by %N", shooterIndex);

    // Check which clients need to be excluded.
    decl newClients[MaxClients], client, i;
    new newTotal = 0;

    for (i = 0; i < numClients; i++) {
        client = Players[i];
        if (CanSee(shooterIndex, i)) {
            // client should be able to hear it
            newClients[newTotal] = client;
            newTotal++;
        }
    }

    // No clients were excluded.
    if (newTotal == numClients)
        return Plugin_Continue;

    // All clients were excluded and there is no need to broadcast.
    else if (newTotal == 0)
        return Plugin_Stop;

    // Re-broadcast to clients that still need it.
    decl Float:vTemp[3];
    TE_Start("Shotgun Shot");
    TE_ReadVector("m_vecOrigin", vTemp);
    TE_WriteVector("m_vecOrigin", vTemp);
    TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
    TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
    TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
    TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
    TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
    TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
    TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
    TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
    TE_Send(newClients, newTotal, delay);

    return Plugin_Stop;
}



public bool:CanSee(entity, client) {
    if (!IsValidClient(entity) || !IsValidClient(client) || entity == client)
        return true;

    // block the transmisson
    if (GetOpponent(entity) != client)
        return false;

    // transmit by default
    return true;

}

public Action:Hook_SetTransmit(entity, client) {
    return CanSee(entity, client) ? Plugin_Continue : Plugin_Handled;
}
