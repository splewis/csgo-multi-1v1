#define MENU_TIME_LENGTH 15

new String:g_Rifles[][][] = {
    {"weapon_ak47", "AK47"},
    {"weapon_m4a1", "M4A4"},
    {"weapon_m4a1_silencer", "M4A1-S"},
    {"weapon_famas", "Famas"},
    {"weapon_galilar", "Galil"},
    {"weapon_aug", "AUG"},
    {"weapon_sg556", "SG553"}
};

new String:g_Pistols[][][] = {
    {"weapon_hkp2000", "P2000"},
    {"weapon_usp_silencer", "USP"},
    {"weapon_glock", "Glock"},
    {"weapon_p250", "P250"},
    {"weapon_cz75a", "CZ75"},
    {"weapon_deagle", "Deagle"},
    {"weapon_fiveseven", "Five-Seven"}
};

/**
 * Opens up the weapon menu for a client.
 */
public GiveWeaponMenu(client) {
    AWPMenu(client);
}

/**
 * Returns an appropriate round type for a pair of clients.
 */
public RoundType:GetRoundType(any:client1, any:client2) {
    if (!IsValidClient(client1) || !IsValidClient(client2) || IsFakeClient(client1) || IsFakeClient(client2))
        return RoundType_Rifle;

    new RoundType:roundType = RoundType_Rifle;
    new RoundType:pref1 = g_Preference[client1];
    new RoundType:pref2 = g_Preference[client2];

    if (pref1 == pref2 && pref1 != RoundType_NoPreference) {
        roundType = pref1;
    } else {
        // create array of "allowed" round types
        new Handle:types = CreateArray();

        AddRounds_CheckAllowed(types, client1, client2, RoundType_Awp, g_AllowAWP);
        AddRounds_CheckAllowed(types, client1, client2, RoundType_Pistol, g_AllowPistol);
        AddRounds(types, client1, client2, RoundType_Rifle);

        // pick a random value from the allowed round types
        roundType = RoundType:GetArrayCellRandom(types);
        CloseHandle(types);
    }

    return roundType;
}

public RoundType:GetRandomRoundType() {
    new Handle:types = CreateArray();
    PushArrayCell(types, RoundType_Rifle);
    PushArrayCell(types, RoundType_Awp);
    PushArrayCell(types, RoundType_Pistol);
    new RoundType:choice = GetArrayCellRandom(types);
    CloseHandle(types);
    return choice;
}

static AddRounds(Handle:types, client1, client2, RoundType:roundType) {
    PushArrayCell(types, roundType);
    if (g_Preference[client1] == roundType || g_Preference[client2] == roundType)
        PushArrayCell(types, roundType);
}

static AddRounds_CheckAllowed(Handle:types, client1, client2, RoundType:roundType, bool:allowed[]) {
    if (allowed[client1] && allowed[client2]) {
        AddRounds(types, client1, client2, roundType);
    }
}

/**
 * Displays the AWP menu to the client.
 */
public AWPMenu(client) {
    new Handle:menu = CreateMenu(MenuHandler_AWP);
    SetMenuTitle(menu, "Allow AWP rounds?");
    AddMenuBool(menu ,true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for the allow awps menu.
 */
public MenuHandler_AWP(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new bool:choice = GetMenuBool(menu, param2);
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
    new Handle:menu = CreateMenu(MenuHandler_Pistol);
    SetMenuTitle(menu, "Allow pistol rounds?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for the allow pistol menu.
 */
public MenuHandler_Pistol(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new bool:choice = GetMenuBool(menu, param2);
        g_AllowPistol[client] = choice;
        SetCookieBool(client, g_hAllowPistolCookie, choice);

        if (g_AllowPistol[client] || g_AllowAWP[client]) {
            PreferenceMenu(client);
        } else {
            g_Preference[client] = RoundType_Rifle;
            SetCookieInt(client, g_hPreferenceCookie, RoundType_Rifle);
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
    new Handle:menu = CreateMenu(MenuHandler_Preference);
    SetMenuTitle(menu, "Choose your preference:");
    AddMenuInt(menu, RoundType_NoPreference, "No Preference");
    AddMenuInt(menu, RoundType_Rifle, "Rifle Rounds");
    if (g_AllowAWP[client])
        AddMenuInt(menu, RoundType_Awp, "AWP Rounds");
    if (g_AllowPistol[client])
        AddMenuInt(menu, RoundType_Pistol, "Pistol Rounds");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Menu Handler for round-type preference menu.
 */
public MenuHandler_Preference(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new RoundType:choice = GetMenuInt(menu, param2);
        g_Preference[client] = choice;
        SetCookieInt(client, g_hPreferenceCookie, choice);
        RifleChoiceMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Primary weapon choice menu.
 */
public RifleChoiceMenu(client) {
    new Handle:menu = CreateMenu(MenuHandler_RifleChoice);
    SetMenuTitle(menu, "Choose your favorite rifle:");
    SetMenuExitButton(menu, true);
    for (new i = 0; i < sizeof(g_Rifles); i++)
        AddMenuItem(menu, g_Rifles[i][0], g_Rifles[i][1]);

    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Rifle weapon handler - updates primaryWeapon.
 */
public MenuHandler_RifleChoice(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        decl String:info[WEAPON_LENGTH];
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
public PistolChoiceMenu(any:client) {
    new Handle:menu = CreateMenu(MenuHandler_PistolChoice);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Choose your favorite pistol:");
    for (new i = 0; i < sizeof(g_Pistols); i++)
        AddMenuItem(menu, g_Pistols[i][0], g_Pistols[i][1]);

    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Pistol choice handler - updates secondary weapon.
 */
public MenuHandler_PistolChoice(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new any:client = param1;
        decl String:info[WEAPON_LENGTH];
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
public FlashbangChoiceMenu(any:client) {
    new Handle:menu = CreateMenu(MenuHandler_FlashChoice);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Give players flashbangs?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

/**
 * Pistol choice handler - updates secondary weapon.
 */
public MenuHandler_FlashChoice(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new any:client = param1;
        new bool:choice = GetMenuBool(menu, param2);
        g_GiveFlash[client] = choice;
        SetCookieBool(client, g_hFlashCookie, choice);
        FinishGunsMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public FinishGunsMenu(client) {
    SetCookieBool(client, g_hSetCookies, true);
    g_GunsSelected[client] = true;
}

/**
 * Sets all the weapon choices based on the client's cookies.
 */
public UpdatePreferencesOnCookies(client) {
    if (!GetCookieBool(client, g_hSetCookies))
        return;

    g_GunsSelected[client] = true;
    g_AllowAWP[client] = GetCookieBool(client, g_hAllowAWPCookie);
    g_AllowPistol[client] = GetCookieBool(client, g_hAllowPistolCookie);
    g_Preference[client] = RoundType:GetCookieInt(client, g_hPreferenceCookie);
    g_GiveFlash[client] = GetCookieBool(client, g_hFlashCookie);

    decl String:sCookieValue[WEAPON_LENGTH];
    GetClientCookie(client, g_hRifleCookie, sCookieValue, sizeof(sCookieValue));
    strcopy(g_PrimaryWeapon[client], sizeof(sCookieValue), sCookieValue);

    GetClientCookie(client, g_hPistolCookie, sCookieValue, sizeof(sCookieValue));
    strcopy(g_SecondaryWeapon[client], sizeof(sCookieValue), sCookieValue);
}
