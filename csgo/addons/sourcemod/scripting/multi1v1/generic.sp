#define PLUGIN_VERSION "1.0.0-dev"
#define MESSAGE_PREFIX "[\x05Multi1v1\x01] "
#define HIDE_RADAR_BIT 1<<12
#define INTEGER_STRING_LENGTH 20 // max number of digits a 64-bit integer can use up as a string
                                 // this is for converting ints to strings when setting menu values/cookies

#include <clientprefs>

new String:g_sqlBuffer[1024];

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
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

/**
 * Returns if a player is on an active/player team.
 */
public bool:IsPlayer(client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

/**
 * Returns if a player is on an active/player team.
 */
public bool:IsActivePlayer(client) {
    if (!IsPlayer(client))
        return false;
    new client_team = GetClientTeam(client);
    return (client_team == CS_TEAM_CT) || (client_team == CS_TEAM_T);
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

/**
 * Returns a random index from an array.
 */
public any:GetArrayRandomIndex(Handle:array) {
    new len = GetArraySize(array);
    if (len == 0)
        ThrowError("Can't get random index from empty array");
    return GetRandomInt(0, len - 1);
}

/**
 * Returns a random element from an array.
 */
public any:GetArrayCellRandom(Handle:array) {
    return GetArrayCell(array, GetArrayRandomIndex(array));
}

/**
 * Pushes an element to an array multiple times.
 */
public PushArrayCellReplicated(Handle:array, any:value, any:times) {
    for (new i = 0; i < times; i++)
        PushArrayCell(array, value);
}

public any:Min(any:x, any:y) {
    return (x < y) ? x : y;
}

/**
 * Given an array of vectors, returns the index of the index
 * that minimizes the euclidean distance between the vectors.
 */
public NearestNeighborIndex(Float:vec[3], Handle:others) {
    new closestIndex = -1;
    new Float:closestDistance = 1.0e300;
    for (new i = 0; i < GetArraySize(others); i++) {
        new Float:tmp[3];
        GetArrayArray(others, i, tmp);
        new Float:dist = GetVectorDistance(vec, tmp);
        if (dist < closestDistance) {
            closestDistance = dist;
            closestIndex = i;
        }
    }

    return closestIndex;
}

/**
 * Closes all handles within an array of handles.
 */
public CloseHandleArray(Handle:array) {
    for (new i = 0; i < GetArraySize(array); i++) {
        new Handle:tmp = GetArrayCell(array, i);
        CloseHandle(tmp);
    }
    CloseHandle(array);
}

/**
 * Creates a table given an array of table arguments.
 */
public SQL_CreateTable(Handle:db_connection, String:table_name[], String:fields[][], num_fields) {
    Format(g_sqlBuffer, sizeof(g_sqlBuffer), "CREATE TABLE IF NOT EXISTS %s (", table_name);
    for (new i = 0; i < num_fields; i++) {
        StrCat(g_sqlBuffer, sizeof(g_sqlBuffer), fields[i]);
        if (i != num_fields - 1)
            StrCat(g_sqlBuffer, sizeof(g_sqlBuffer), ", ");
    }
    StrCat(g_sqlBuffer, sizeof(g_sqlBuffer), ");");
    SQL_FastQuery(db_connection, g_sqlBuffer);
}
