#define WEAPON_MAX 16

// Stored data from the weapons config file.
// Each array has 3 elements:
//  0: game's name of the weapon (e.g. "weapon_ak47")
//  1: player-readable name of the weapon (e.g. "AK47")
//  2: team the weapon belongs to (e.g. "T", "CT", or "ANY")
int g_numRifles;
char g_Rifles[WEAPON_MAX][3][WEAPON_NAME_LENGTH];
int g_numPistols;
char g_Pistols[WEAPON_MAX][3][WEAPON_NAME_LENGTH];

/**
 * Initializes weapon-related data on map start.
 * This includes the server-specific weapon config file configs/multi1v1_weapons.cfg.
 */
public void Weapons_MapStart() {
    g_numPistols = 0;
    g_numRifles = 0;

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/multi1v1_weapons.cfg");

    if (!FileExists(configFile)) {
        LogError("The weapon config file does not exist: %s", configFile);
        LoadBackupConfig();
        return;
    }

    Handle kv = CreateKeyValues("Weapons");
    FileToKeyValues(kv, configFile);

    // Parse the rifles section
    if (!KvJumpToKey(kv, "Rifles")) {
        LogError("The weapon config file did not contain a \"Rifles\" section: %s", configFile);
        CloseHandle(kv);
        LoadBackupConfig();
        return;
    }
    if (!KvGotoFirstSubKey(kv)) {
        LogError("No rifles were found.");
    }
    do {
        KvGetSectionName(kv, g_Rifles[g_numRifles][0], WEAPON_NAME_LENGTH);
        KvGetString(kv, "name", g_Rifles[g_numRifles][1], WEAPON_NAME_LENGTH, g_Rifles[g_numRifles][0]);
        KvGetString(kv, "team", g_Rifles[g_numRifles][2], WEAPON_NAME_LENGTH, "ANY");
        g_numRifles++;
    } while (KvGotoNextKey(kv));
    KvRewind(kv);

    // Parse the pistols section
    if (!KvJumpToKey(kv, "Pistols")) {
        LogError("The weapon config file did not contain a \"Pistols\" section: %s", configFile);
        CloseHandle(kv);
        LoadBackupConfig();
        return;
    }

    if (!KvGotoFirstSubKey(kv)) {
        LogError("No pistols were found.");
    }
    do {
        KvGetSectionName(kv, g_Pistols[g_numPistols][0], WEAPON_NAME_LENGTH);
        KvGetString(kv, "name", g_Pistols[g_numPistols][1], WEAPON_NAME_LENGTH, g_Pistols[g_numPistols][0]);
        KvGetString(kv, "team", g_Pistols[g_numPistols][2], WEAPON_NAME_LENGTH, "ANY");
        g_numPistols++;
    } while (KvGotoNextKey(kv));

    CloseHandle(kv);
}

/**
 * A simple backup with just a few weapons so bad config files don't totally break the server.
 */
static void LoadBackupConfig() {
    LogError("Plugin forced to fallback to backup weapons only");
    g_Rifles[0][0] = "weapon_ak47";
    g_Rifles[0][1] = "AK47";
    g_Rifles[0][2] = "T";
    g_Rifles[1][0] = "weapon_m4a1";
    g_Rifles[1][1] = "M4A1";
    g_Rifles[1][2] = "CT";
    g_numRifles = 2;

    g_Pistols[0][0] = "weapon_glock";
    g_Pistols[0][1] = "Glock";
    g_Pistols[0][2] = "T";
    g_Pistols[1][0] = "weapon_p250";
    g_Pistols[1][1] = "P250";
    g_Pistols[1][2] = "ANY";
    g_numPistols = 2;
}

static TeamStringToTeam(const char[] teamString) {
    if (StrEqual(teamString, "CT", false))
        return CS_TEAM_CT;
    else if (StrEqual(teamString, "T", false))
        return CS_TEAM_T;
    else
        return -1;
}

/**
 * Returns the cstrike team a weapon is intended for, or -1 if any can use the weapon.
 * This is only valid for weapons in the server's weapons config file.
 */
public int GetWeaponTeam(const char[] weapon) {
    for (new i = 0; i < g_numRifles; i++) {
        if (StrEqual(weapon[0], g_Rifles[i][0])) {
            return TeamStringToTeam(g_Rifles[i][2][0]);
        }
    }
    for (new i = 0; i < g_numPistols; i++) {
        if (StrEqual(weapon[0], g_Pistols[i][0])) {
            return TeamStringToTeam(g_Pistols[i][2][0]);
        }
    }
    return -1;
}

/**
 * Opens up the weapon menu for a client.
 */
public GiveWeaponMenu(int client) {
    g_CurrentRoundTypeMenuIndex[client] = -1;
    g_WaitingOnRoundAllow[client] = false;
    RifleChoiceMenu(client);
}

/**
 * Displays the round-type preference menu to a client.
 */
public GivePreferenceMenu(int client) {
    Handle menu = CreateMenu(MenuHandler_Preference);
    SetMenuTitle(menu, "Choose your preference:");
    AddMenuInt(menu, -1, "No Preference");

    int count = 0;
    for (int i = 0; i < g_numRoundTypes; i++) {
        if (g_AllowedRoundTypes[client][i] || !g_RoundTypeOptional[i]) {
            count++;
            char buffer[128];
            Format(buffer, sizeof(buffer), "%s rounds", g_RoundTypeDisplayNames[i]);
            AddMenuInt(menu, i, buffer);
        }
    }

    if (count >= 2) {
        DisplayMenu(menu, client, MENU_TIME_LENGTH);
    } else {
        CloseHandle(menu);
        FinishGunsMenu(client);
    }
}

/**
 * Menu Handler for round-type preference menu.
 */
public MenuHandler_Preference(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        g_Preference[client] = choice;

        if (choice == -1) {
            SetCookieStringByName(client, "multi1v1_preference", "none");
        } else {
            SetCookieStringByName(client, "multi1v1_preference", g_RoundTypeNames[choice]);
        }
        FinishGunsMenu(client);

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void FinishGunsMenu(int client) {
    g_GunsSelected[client] = true;
    Call_StartForward(g_hOnGunsMenuDone);
    Call_PushCell(client);
    Call_Finish();
}

/**
 * Primary weapon choice menu.
 */
public RifleChoiceMenu(int client) {
    if (GetConVarInt(g_hRifleMenu) == 0) {
        PistolChoiceMenu(client);
    } else {
        Handle menu = CreateMenu(MenuHandler_RifleChoice);
        SetMenuTitle(menu, "Choose your favorite rifle:");
        SetMenuExitButton(menu, true);
        for (int i = 0; i < g_numRifles; i++)
            AddMenuItem(menu, g_Rifles[i][0], g_Rifles[i][1]);

        DisplayMenu(menu, client, MENU_TIME_LENGTH);
    }
}

/**
 * Rifle weapon handler - updates primaryWeapon.
 */
public MenuHandler_RifleChoice(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char info[WEAPON_LENGTH];
        GetMenuItem(menu, param2, info, sizeof(info));
        g_PrimaryWeapon[client] = info;
        SetCookieStringByName(client, "multi1v1_rifle", info);
        PistolChoiceMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Displays pistol menu to a player
 */
public PistolChoiceMenu(int client) {
    if (GetConVarInt(g_hPistolMenu) == 0) {
        ReturnMenuControl(client);
    } else {
        Handle menu = CreateMenu(MenuHandler_PistolChoice);
        SetMenuExitButton(menu, true);
        SetMenuTitle(menu, "Choose your favorite pistol:");
        for (int i = 0; i < g_numPistols; i++)
            AddMenuItem(menu, g_Pistols[i][0], g_Pistols[i][1]);

        DisplayMenu(menu, client, MENU_TIME_LENGTH);
    }
}

/**
 * Pistol choice handler - updates secondary weapon.
 */
public MenuHandler_PistolChoice(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char info[WEAPON_LENGTH];
        GetMenuItem(menu, param2, info, sizeof(info));
        g_SecondaryWeapon[client] = info;
        SetCookieStringByName(client, "multi1v1_pistol", info);
        ReturnMenuControl(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Sets all the weapon choices based on the client's cookies.
 */
public UpdatePreferencesOnCookies(int client) {
    g_GunsSelected[client] = true;

    for (int i = 0; i < g_numRoundTypes; i++) {
        char cookieName[128];
        Format(cookieName, sizeof(cookieName), "multi1v1_allow%s", g_RoundTypeNames[i]);
        g_AllowedRoundTypes[client][i] = GetCookieBoolByName(client, cookieName);
    }

    char cookieValue[WEAPON_LENGTH];
    GetCookieStringByName(client, "multi1v1_rifle", cookieValue, sizeof(cookieValue));
    if (IsAllowedRifle(cookieValue))
        strcopy(g_PrimaryWeapon[client], sizeof(cookieValue), cookieValue);

    GetCookieStringByName(client, "multi1v1_pistol", cookieValue, sizeof(cookieValue));
    if (IsAllowedPistol(cookieValue))
        strcopy(g_SecondaryWeapon[client], sizeof(cookieValue), cookieValue);

    GetCookieStringByName(client, "multi1v1_preference", cookieValue, sizeof(cookieValue));
    g_Preference[client] = Multi1v1_GetRoundTypeIndex(cookieValue);

    if (StrEqual(cookieValue, "") && GetConVarInt(g_hGunsMenuOnFirstConnct) != 0)
        GiveWeaponMenu(client);
}

/**
 * Gives a player a weapon, taking care of getting them the appropriate skin.
 */
public GiveWeapon(int client, const char[] weapon) {
    int playerteam = GetEntProp(client, Prop_Data, "m_iTeamNum");
    int weaponteam = GetWeaponTeam(weapon);
    if (weaponteam > 0)
        SetEntProp(client, Prop_Data, "m_iTeamNum", weaponteam);
    GivePlayerItem(client, weapon);
    SetEntProp(client, Prop_Data, "m_iTeamNum", playerteam);
}

/**
 * Returns if the given weapon is a default starting pistol.
 */
public bool IsDefaultPistol(const char[] weapon) {
    char defaultPistols[][] = {
        "weapon_glock",
        "weapon_hkp2000",
        "weapon_usp_silencer"
    };
    for (int i = 0; i < sizeof(defaultPistols); i++) {
        if (StrEqual(weapon, defaultPistols[i])) {
            return true;
        }
    }
    return false;
}

static bool IsAllowedRifle(const char[] weapon) {
    for (int i = 0; i < g_numRifles; i++) {
        if (StrEqual(g_Rifles[i][0], weapon, false)) {
            return true;
        }
    }
    return false;
}

static bool IsAllowedPistol(const char[] weapon) {
    for (int i = 0; i < g_numPistols; i++) {
        if (StrEqual(g_Pistols[i][0], weapon, false)) {
            return true;
        }
    }
    return false;
}
