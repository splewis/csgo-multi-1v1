#define INTEGER_STRING_LENGTH 20 // max number of digits a 64-bit integer can use up as a string
                                 // this is for converting ints to strings when setting menu values/cookies

/**
 * Switches a client to a new team.
 */
public SwitchPlayerTeam(client, team) {
    new previousTeam = GetClientTeam(client);
    if (previousTeam == team)
        return;

    g_PluginTeamSwitch[client] = true;
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
    } else {
        ChangeClientTeam(client, team);
    }
    g_PluginTeamSwitch[client] = false;
}

/**
 * Returns if a player is on an active/player team.
 */
public bool:IsOnTeam(client) {
    new client_team = GetClientTeam(client);
    return (client_team == CS_TEAM_CT) || (client_team == CS_TEAM_T);
}

/**
 * Generic assertion function. Change the ASSERT_FUNCTION if you want.
 */
public Assert(bool:value, const String:msg[] , any:...) {
    if (!value) {
        VFormat(assertBuffer, sizeof(assertBuffer), msg, 3);
        ASSERT_MODE (assertBuffer);
    }
}

/**
 * Removes the radar element from a client's HUD.
 */
public Action:RemoveRadar(Handle:timer, any:client) {
    if (IsValidClient(client) && !IsFakeClient(client)) {
        new flags = GetEntProp(client, Prop_Send, "m_iHideHUD");
        SetEntProp(client, Prop_Send, "m_iHideHUD", flags | (HIDE_RADAR_BIT));
    }
}

/**
 * Function to identify if a client is valid and in game.
 */
public bool:IsValidClient(client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

/**
 * Adds an integer to a menu as a string choice.
 */
public AddMenuInt(Handle:menu, any:value, String:display[]) {
    decl String:buffer[INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    AddMenuItem(menu, buffer, display);
}

/**
 * Gets an integer to a menu from a string choice.
 */
public any:GetMenuInt(Handle:menu, any:param2) {
    decl String:choice[INTEGER_STRING_LENGTH];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    return StringToInt(choice);
}

/**
 * Adds a boolean to a menu as a string choice.
 */
public AddMenuBool(Handle:menu, bool:value, String:display[]) {
    new convertedInt = value ? 1 : 0;
    AddMenuInt(menu, convertedInt, display);
}

/**
 * Gets a boolean to a menu from a string choice.
 */
public bool:GetMenuBool(Handle:menu, any:param2) {
    return GetMenuInt(menu, param2) != 0;
}

/**
 * Sets a cookie to an integer value by converting it to a string.
 */
public SetCookieInt(any:client, Handle:cookie, any:value) {
    decl String:buffer[INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    SetClientCookie(client, cookie, buffer);
}

/**
 * Fetches the value of a cookie that is an integer.
 */
public any:GetCookieInt(client, Handle:cookie) {
    decl String:buffer[INTEGER_STRING_LENGTH];
    GetClientCookie(client, cookie, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

/**
 * Sets a cookie to a boolean value.
 */
public SetCookieBool(any:client, Handle:cookie, bool:value) {
    new convertedInt = value ? 1 : 0;
    SetCookieInt(client, cookie, convertedInt);
}

/**
 * Gets a cookie that represents a boolean.
 */
public bool:GetCookieBool(any:client, Handle:cookie) {
    return GetCookieInt(client, cookie) != 0;
}
