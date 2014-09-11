#define MENU_TIME_LENGTH 15

char g_Rifles[][][] = {
    {"weapon_ak47", "AK47", "T"},
    {"weapon_m4a1", "M4A4", "CT"},
    {"weapon_m4a1_silencer", "M4A1-S", "CT"},
    {"weapon_famas", "Famas", "CT"},
    {"weapon_galilar", "Galil", "T"},
    {"weapon_aug", "AUG", "CT"},
    {"weapon_sg556", "SG553", "T"}
};

char g_Pistols[][][] = {
    {"weapon_hkp2000", "P2000/USP", "CT"},
    {"weapon_glock", "Glock", "T"},
    {"weapon_p250", "P250", "ANY"},
    {"weapon_fiveseven", "Five-Seven", "CT"},
    {"weapon_cz75a", "CZ75", "ANY"},
    {"weapon_deagle", "Deagle", "ANY"}
};

static TeamStringToTeam(char teamString[]) {
    if (StrEqual(teamString, "CT", false))
        return CS_TEAM_CT;
    else if (StrEqual(teamString, "T", false))
        return CS_TEAM_T;
    else
        return -1;
}

public int GetWeaponTeam(char weapon[]) {
    for (new i = 0; i < sizeof(g_Rifles); i++) {
        if (StrEqual(weapon[0], g_Rifles[i][0])) {
            return TeamStringToTeam(g_Rifles[i][2][0]);
        }
    }
    for (new i = 0; i < sizeof(g_Pistols); i++) {
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
        Handle types = CreateArray();

        AddRounds_CheckAllowed(types, client1, client2, RoundType_Awp, g_AllowAWP);
        AddRounds_CheckAllowed(types, client1, client2, RoundType_Pistol, g_AllowPistol);
        AddRounds(types, client1, client2, RoundType_Rifle);

        // pick a random value from the allowed round types
        roundType = RoundType:GetArrayCell(types, GetArrayRandomIndex(types));
        CloseHandle(types);
    }

    return roundType;
}

public RoundType GetRandomRoundType() {
    Handle types = CreateArray();
    PushArrayCell(types, RoundType_Rifle);
    PushArrayCell(types, RoundType_Awp);
    PushArrayCell(types, RoundType_Pistol);
    RoundType choice = GetArrayCell(types, GetArrayRandomIndex(types));
    CloseHandle(types);
    return choice;
}

static AddRounds(Handle types, int client1, int client2, RoundType roundType) {
    PushArrayCell(types, roundType);
    if (g_Preference[client1] == roundType || g_Preference[client2] == roundType)
        PushArrayCell(types, roundType);
}

static AddRounds_CheckAllowed(Handle types, int client1, int client2, RoundType roundType, bool allowed[]) {
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
    for (int i = 0; i < sizeof(g_Rifles); i++)
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
    for (int i = 0; i < sizeof(g_Pistols); i++)
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
 * Pistol choice handler - updates secondary weapon.
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
    strcopy(g_PrimaryWeapon[client], sizeof(cookieValue), cookieValue);

    GetClientCookie(client, g_hPistolCookie, cookieValue, sizeof(cookieValue));
    strcopy(g_SecondaryWeapon[client], sizeof(cookieValue), cookieValue);
}
