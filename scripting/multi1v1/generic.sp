#tryinclude "../include/multi1v1_version.inc"
#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "1.0.0-dev"
#endif

#define MESSAGE_PREFIX "[\x05Multi1v1\x01] "
#define HIDE_RADAR_BIT 1<<12
#define INTEGER_STRING_LENGTH 20 // max number of digits a 64-bit integer can use up as a string
                                 // this is for converting ints to strings when setting menu values/cookies

char g_ColorNames[][] = {"{NORMAL}", "{DARK_RED}", "{PURPLE}", "{GREEN}", "{MOSS_GREEN}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}", "{DARK_BLUE}", "{PURPLE}", "{CARRIAGE_RETURN}"};
char g_ColorCodes[][] =    {"\x01",     "\x02",      "\x03",   "\x04",         "\x05",     "\x06",          "\x07",        "\x08",   "\x09",     "\x0B",         "\x0C",        "\x0E",     "\n"};

#include <clientprefs>
#include <cstrike>

/**
 * Removes the radar element from a client's HUD.
 */
public Action RemoveRadar(Handle timer, int client) {
    if (IsValidClient(client) && !IsFakeClient(client)) {
        int flags = GetEntProp(client, Prop_Send, "m_iHideHUD");
        SetEntProp(client, Prop_Send, "m_iHideHUD", flags | (HIDE_RADAR_BIT));
    }
    return Plugin_Continue;
}

/**
 * Function to identify if a client is valid and in game.
 */
stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsConnected(int client) {
    return client > 0 && client <= MaxClients && IsClientConnected(client) && !IsFakeClient(client);
}

/**
 * Returns if a player is on an active/player team.
 */
stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

/**
 * Returns if a player is on an active/player team.
 */
stock bool IsActivePlayer(int client) {
    if (!IsPlayer(client))
        return false;
    int client_team = GetClientTeam(client);
    return (client_team == CS_TEAM_CT) || (client_team == CS_TEAM_T);
}

/**
 * Adds an integer to a menu as a string choice.
 */
stock void AddMenuInt(Handle menu, int value, const char[] display) {
    char buffer[INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    AddMenuItem(menu, buffer, display);
}

/**
 * Gets an integer to a menu from a string choice.
 */
stock int GetMenuInt(Handle menu, int param2) {
    char choice[INTEGER_STRING_LENGTH];
    GetMenuItem(menu, param2, choice, sizeof(choice));
    return StringToInt(choice);
}

/**
 * Adds a boolean to a menu as a string choice.
 */
stock void AddMenuBool(Handle menu, bool value, const char[] display) {
    int convertedInt = value ? 1 : 0;
    AddMenuInt(menu, convertedInt, display);
}

/**
 * Gets a boolean to a menu from a string choice.
 */
stock bool GetMenuBool(Handle menu, int param2) {
    return GetMenuInt(menu, param2) != 0;
}

/**
 * Returns a handle to a cookie with the given name, creating it if it doesn't exist.
 */
stock Handle FindNamedCookie(const char[] cookieName) {
    Handle cookie = FindClientCookie(cookieName);
    if (cookie == INVALID_HANDLE) {
        cookie = RegClientCookie(cookieName, "multi1v1 cookie", CookieAccess_Protected);
    }
    return cookie;
}

/**
 * Sets the value of a client cookie given the cookie name.
 */
stock void SetCookieStringByName(int client, const char[] cookieName, const char[] value) {
    Handle cookie = FindNamedCookie(cookieName);
    SetClientCookie(client, cookie, value);
    CloseHandle(cookie);
}

/**
 * Gets the value of a client cookie given the cookie name.
 */
stock void GetCookieStringByName(int client, const char[] cookieName, char[] buffer, int length) {
    Handle cookie = FindNamedCookie(cookieName);
    GetClientCookie(client, cookie, buffer, length);
    CloseHandle(cookie);
}

/**
 * Sets a cookie to an integer value by converting it to a string.
 */
stock void SetCookieIntByName(int client, const char[] cookieName, int value) {
    char buffer[INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    SetCookieStringByName(client, cookieName, buffer);
}

/**
 * Fetches the value of a cookie that is an integer.
 */
stock int GetCookieIntByName(int client, const char[] cookieName) {
    char buffer[INTEGER_STRING_LENGTH];
    GetCookieStringByName(client, cookieName, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

/**
 * Sets a cookie to a boolean value.
 */
stock void SetCookieBoolByName(int client, const char[] cookieName, bool value) {
    int convertedInt = value ? 1 : 0;
    SetCookieIntByName(client, cookieName, convertedInt);
}

/**
 * Gets a cookie that represents a boolean.
 */
stock bool GetCookieBoolByName(int client, const char[] cookieName) {
    return GetCookieIntByName(client, cookieName) != 0;
}

/**
 * Sets a cookie to an integer value by converting it to a string.
 */
stock void SetCookieInt(int client, Handle cookie, int value) {
    char buffer[INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    SetClientCookie(client, cookie, buffer);
}

/**
 * Fetches the value of a cookie that is an integer.
 */
stock int GetCookieInt(int client, Handle cookie) {
    char buffer[INTEGER_STRING_LENGTH];
    GetClientCookie(client, cookie, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

/**
 * Sets a cookie to a boolean value.
 */
stock void SetCookieBool(int client, Handle cookie, bool value) {
    int convertedInt = value ? 1 : 0;
    SetCookieInt(client, cookie, convertedInt);
}

/**
 * Gets a cookie that represents a boolean.
 */
stock bool GetCookieBool(int client, Handle cookie) {
    return GetCookieInt(client, cookie) != 0;
}

/**
 * Returns a random index from an array.
 */
stock int GetArrayRandomIndex(Handle array) {
    int len = GetArraySize(array);
    if (len == 0)
        ThrowError("Can't get random index from empty array");
    return GetRandomInt(0, len - 1);
}

/**
 * Pushes an element to an array multiple times.
 */
stock void PushArrayCellReplicated(Handle array, int value, int times) {
    for (int i = 0; i < times; i++)
        PushArrayCell(array, value);
}

/**
 * Given an array of vectors, returns the index of the index
 * that minimizes the euclidean distance between the vectors.
 */
stock int NearestNeighborIndex(const float vec[3], Handle others) {
    int closestIndex = -1;
    float closestDistance = 0.0;
    for (int i = 0; i < GetArraySize(others); i++) {
        float tmp[3];
        GetArrayArray(others, i, tmp);
        float dist = GetVectorDistance(vec, tmp);
        if (closestIndex < 0 || dist < closestDistance) {
            closestDistance = dist;
            closestIndex = i;
        }
    }

    return closestIndex;
}

/**
 * Closes all handles within an array of handles.
 */
stock void CloseHandleArray(Handle array) {
    for (int i = 0; i < GetArraySize(array); i++) {
        Handle tmp = GetArrayCell(array, i);
        CloseHandle(tmp);
    }
    CloseHandle(array);
}

/**
 * Creates a table given an array of table arguments.
 */
stock void SQL_CreateTable(Handle db_connection, const char[] table_name, const char[][] fields, int num_fields) {
    char buffer[1024];
    Format(buffer, sizeof(buffer), "CREATE TABLE IF NOT EXISTS %s (", table_name);
    for (int i = 0; i < num_fields; i++) {
        StrCat(buffer, sizeof(buffer), fields[i]);
        if (i != num_fields - 1)
            StrCat(buffer, sizeof(buffer), ", ");
    }
    StrCat(buffer, sizeof(buffer), ")");

    if (!SQL_FastQuery(db_connection, buffer)) {
        char err[255];
        SQL_GetError(db_connection, err, sizeof(err));
        LogError(err);
    }
}

/**
 * Adds a new field to a table.
 */
stock void SQL_AddColumn(Handle db_connection, const char[] table_name, const char[] column_info) {
    char buffer[1024];
    Format(buffer, sizeof(buffer), "ALTER TABLE %s ADD COLUMN %s", table_name, column_info);
    if (!SQL_FastQuery(db_connection, buffer)) {
        char err[255];
        SQL_GetError(db_connection, err, sizeof(err));
        if (StrContains(err, "Duplicate column name", false) == -1) {
            LogError(err);
        }
    }
}

/**
 * Sets the primary key for a table.
 */
stock void SQL_UpdatePrimaryKey(Handle db_connection, const char[] table_name, const char[] primary_key) {
    char buffer[1024];
    Format(buffer, sizeof(buffer), "ALTER TABLE %s DROP PRIMARY KEY, ADD PRIMARY KEY (%s)", table_name, primary_key);
    if (!SQL_FastQuery(db_connection, buffer)) {
        char err[255];
        SQL_GetError(db_connection, err, sizeof(err));
        LogError(err);
    }
}

/**
 * Applies colorized characters across a string to replace color tags.
 */
stock void Colorize(char[] msg, int size) {
    for (int i = 0; i < sizeof(g_ColorNames); i ++) {
        ReplaceString(msg, size, g_ColorNames[i], g_ColorCodes[i]);
    }
}

// Thanks to KissLick https://forums.alliedmods.net/member.php?u=210752
/**
 * Splits a string to the right at the first occurance of a substring.
 */
stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen) {
    int index = StrContains(source, split);
    if (index == -1)
        return false;

    index += strlen(split);
    strcopy(part, partLen, source[index]);
    return true;
}

stock void Client_SetHelmet(int client, bool helmet) {
    int offset = FindSendPropOffs("CCSPlayer", "m_bHasHelmet");
    SetEntData(client, offset, helmet);
}
