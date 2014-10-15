#define MENU_TIME_LENGTH 15
#define WEAPON_MAX 16
#define WEAPON_NAME_LENGTH 32

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
    // Opening the file
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

static TeamStringToTeam(char teamString[]) {
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
public int GetWeaponTeam(const char weapon[]) {
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
public GiveWeaponMenu(client) {
    AWPMenu(client);
}

/**
 * Returns an appropriate round type for a pair of clients.
 */
public RoundType GetRoundType(int client1, int client2) {
    if (!IsPlayer(client1) || !IsPlayer(client2))
        return RoundType_Rifle;

    RoundType roundType = RoundType_Rifle;
    RoundType pref1 = RoundType:g_Preference[client1];
    RoundType pref2 = RoundType:g_Preference[client2];

    if (pref1 == pref2 && pref1 != RoundType_NoPreference) {
        roundType = pref1;
    } else {
        // create array of "allowed" round types
        ArrayList types = ArrayList();

        AddRounds_CheckAllowed(types, client1, client2, RoundType_Awp, g_AllowAWP);
        AddRounds_CheckAllowed(types, client1, client2, RoundType_Pistol, g_AllowPistol);
        AddRounds(types, client1, client2, RoundType_Rifle);

        // pick a random value from the allowed round types
        roundType = RoundType:GetArrayCell(types, GetArrayRandomIndex(types));
        CloseHandle(types);
    }

    return roundType;
}

/**
 * Returns a completely random round type.
 */
public RoundType GetRandomRoundType() {
    ArrayList types = ArrayList();
    types.Push(RoundType_Rifle);
    types.Push(RoundType_Awp);
    types.Push(RoundType_Pistol);
    RoundType choice = types.Get(GetArrayRandomIndex(types));
    CloseHandle(types);
    return choice;
}

static AddRounds(ArrayList types, int client1, int client2, RoundType roundType) {
    types.Push(roundType);
    if (g_Preference[client1] == roundType || g_Preference[client2] == roundType)
        types.Push(roundType);
}

static AddRounds_CheckAllowed(ArrayList types, int client1, int client2, RoundType roundType, bool allowed[]) {
    if (allowed[client1] && allowed[client2]) {
        AddRounds(types, client1, client2, roundType);
    }
}

/**
 * Displays the AWP menu to the client.
 */
public AWPMenu(client) {
    Handle menu = CreateMenu(MenuHandler_AWP);
    SetMenuTitle(menu, "Allow AWP rounds?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for the allow awps menu.
 */
public MenuHandler_AWP(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        g_AllowAWP[client] = choice;
        SetCookieBool(client, g_hAllowAWPCookie, choice);
        PistolMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Displays the allow pistol menu to the client.
 */
public PistolMenu(client) {
    Handle menu = CreateMenu(MenuHandler_Pistol);
    SetMenuTitle(menu, "Allow pistol rounds?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for the allow pistol menu.
 */
public MenuHandler_Pistol(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        g_AllowPistol[client] = choice;
        SetCookieBool(client, g_hAllowPistolCookie, choice);

        if (g_AllowPistol[client] || g_AllowAWP[client]) {
            PreferenceMenu(client);
        } else {
            g_Preference[client] = RoundType_Rifle;
            SetCookieInt(client, g_hPreferenceCookie, _:RoundType_Rifle);
            RifleChoiceMenu(client);
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Displays the round-type preference menu to a client.
 */
public PreferenceMenu(client) {
    Handle menu = CreateMenu(MenuHandler_Preference);
    SetMenuTitle(menu, "Choose your preference:");
    AddMenuInt(menu, _:RoundType_NoPreference, "No Preference");
    AddMenuInt(menu, _:RoundType_Rifle, "Rifle Rounds");
    if (g_AllowAWP[client])
        AddMenuInt(menu, _:RoundType_Awp, "AWP Rounds");
    if (g_AllowPistol[client])
        AddMenuInt(menu, _:RoundType_Pistol, "Pistol Rounds");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for round-type preference menu.
 */
public MenuHandler_Preference(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        RoundType choice = RoundType:GetMenuInt(menu, param2);
        g_Preference[client] = choice;
        SetCookieInt(client, g_hPreferenceCookie, _:choice);
        RifleChoiceMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Primary weapon choice menu.
 */
public RifleChoiceMenu(int client) {
    Handle menu = CreateMenu(MenuHandler_RifleChoice);
    SetMenuTitle(menu, "Choose your favorite rifle:");
    SetMenuExitButton(menu, true);
    for (int i = 0; i < g_numRifles; i++)
        AddMenuItem(menu, g_Rifles[i][0], g_Rifles[i][1]);

    DisplayMenu(menu, client, MENU_TIME_LENGTH);
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
        SetClientCookie(client, g_hRifleCookie, info);
        PistolChoiceMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Displays pistol menu to a player
 */
public PistolChoiceMenu(int client) {
    Handle menu = CreateMenu(MenuHandler_PistolChoice);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Choose your favorite pistol:");
    for (int i = 0; i < g_numPistols; i++)
        AddMenuItem(menu, g_Pistols[i][0], g_Pistols[i][1]);

    DisplayMenu(menu, client, MENU_TIME_LENGTH);
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
        SetClientCookie(client, g_hPistolCookie, info);
        FlashbangChoiceMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Displays flashbang menu to a player
 */
public FlashbangChoiceMenu(int client) {
    Handle menu = CreateMenu(MenuHandler_FlashChoice);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Give players flashbangs?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Flashbang choice handler - updates flashbang preference.
 */
public MenuHandler_FlashChoice(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        g_GiveFlash[client] = choice;
        SetCookieBool(client, g_hFlashCookie, choice);
        FinishGunsMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public FinishGunsMenu(int client) {
    SetCookieBool(client, g_hSetCookies, true);
    g_GunsSelected[client] = true;
    Call_StartForward(g_hOnGunsMenuDone);
    Call_PushCell(client);
    Call_Finish();
}

/**
 * Sets all the weapon choices based on the client's cookies.
 */
public UpdatePreferencesOnCookies(int client) {
    if (!GetCookieBool(client, g_hSetCookies))
        return;

    g_GunsSelected[client] = true;
    g_AllowAWP[client] = GetCookieBool(client, g_hAllowAWPCookie);
    g_AllowPistol[client] = GetCookieBool(client, g_hAllowPistolCookie);
    g_Preference[client] = RoundType:GetCookieInt(client, g_hPreferenceCookie);
    g_GiveFlash[client] = GetCookieBool(client, g_hFlashCookie);

    char cookieValue[WEAPON_LENGTH];
    GetClientCookie(client, g_hRifleCookie, cookieValue, sizeof(cookieValue));
    if (IsAllowedRifle(cookieValue))
        strcopy(g_PrimaryWeapon[client], sizeof(cookieValue), cookieValue);

    GetClientCookie(client, g_hPistolCookie, cookieValue, sizeof(cookieValue));
    if (IsAllowedPistol(cookieValue))
        strcopy(g_SecondaryWeapon[client], sizeof(cookieValue), cookieValue);
}

/**
 * Gives a player a weapon, taking care of getting them the appropriate skin.
 */
public GiveWeapon(int client, const char weapon[]) {
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
public bool IsDefaultPistol(const char weapon[]) {
    char defaultPistols[][] = {
        "weapon_glock",
        "weapon_hkp2000",
        "weapon_usp_silencer"
    };
    for (int i = 0; i < 3; i++) {
        if (StrEqual(weapon, defaultPistols[i])) {
            return true;
        }
    }
    return false;
}

static bool IsAllowedRifle(char weapon[]) {
    for (int i = 0; i < sizeof(g_Rifles); i++) {
        if (StrEqual(g_Rifles[i][0], weapon, false)) {
            return true;
        }
    }
    return false;
}

static bool IsAllowedPistol(char weapon[]) {
    for (int i = 0; i < sizeof(g_Pistols); i++) {
        if (StrEqual(g_Pistols[i][0], weapon, false)) {
            return true;
        }
    }
    return false;
}
