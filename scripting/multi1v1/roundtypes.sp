/**
 * Roundtype runtime registration/selection code.
 */


/**
 * Returns a round type appropriate for a given pair of players.
 * This function is *NOT* pure since it uses randomness
 * to select a round type in some situations.
 */
public int GetRoundType(int client1, int client2) {
    if (g_numRoundTypes == 0) {
        ThrowError("No round types are registered");
        return -1;
    }

    if (!IsPlayer(client1) || !IsPlayer(client2)) {
        return 0;
    }

    ArrayList types = new ArrayList();
    for (int roundType = 0; roundType < g_numRoundTypes; roundType++) {
        if (!g_RoundTypeOptional[roundType]) {
            AddRounds(types, client1, client2, roundType);
        } else {
            AddRounds_CheckAllowed(types, client1, client2, roundType);
        }
    }

    int choice = 0;
    if (GetArraySize(types) > 0) {
        int index = GetArrayRandomIndex(types);
        choice = GetArrayCell(types, index);
    }
    CloseHandle(types);

    Call_StartForward(g_hOnRoundTypeDecided);
    Call_PushCell(client1);
    Call_PushCell(client2);
    Call_PushCellRef(choice);
    Call_Finish();

    return choice;
}

static AddRounds(ArrayList types, int client1, int client2, int roundType) {
    int weight = 1;

    int prefWeight = GetConVarInt(g_hPreferenceWeight);
    if (g_Preference[client1] == roundType)
        weight += prefWeight;
    if (g_Preference[client2] == roundType)
        weight += prefWeight;

    PushArrayCellReplicated(types, roundType, weight);
}

static AddRounds_CheckAllowed(ArrayList types, int client1, int client2, int roundType) {
    if (g_AllowedRoundTypes[client1][roundType] && g_AllowedRoundTypes[client2][roundType]) {
        AddRounds(types, client1, client2, roundType);
    }
}

public int AddRoundType(Handle pluginSource, const char[] displayName, const char[] internalName,
                        RoundTypeWeaponHandler weaponHandler, RoundTypeMenuHandler menuHandler,
                        bool optional, bool ranked, const char[] ratingFieldName) {

    if (g_numRoundTypes >= MAX_ROUND_TYPES) {
        LogError("Tried to add new round when %d round types already added", MAX_ROUND_TYPES);
        return -1;
    }

    g_RoundTypeSourcePlugin[g_numRoundTypes] = pluginSource;
    strcopy(g_RoundTypeDisplayNames[g_numRoundTypes], ROUND_TYPE_NAME_LENGTH, displayName);
    String_ToLower(internalName, g_RoundTypeNames[g_numRoundTypes], ROUND_TYPE_NAME_LENGTH);
    g_RoundTypeWeaponHandlers[g_numRoundTypes] = weaponHandler;
    g_RoundTypeMenuHandlers[g_numRoundTypes] = menuHandler;
    g_RoundTypeOptional[g_numRoundTypes] = optional;
    g_RoundTypeRanked[g_numRoundTypes] = ranked;
    strcopy(g_RoundTypeFieldNames[g_numRoundTypes], ROUND_TYPE_NAME_LENGTH, ratingFieldName);
    g_numRoundTypes++;
    return g_numRoundTypes - 1;
}

public void ReturnMenuControl(int client) {
    if (g_WaitingOnRoundAllow[client]) {

        g_WaitingOnRoundAllow[client] = false;
        int roundType = g_CurrentRoundTypeMenuIndex[client];

        if (g_AllowedRoundTypes[client][roundType]) {
            Handle pluginSource = g_RoundTypeSourcePlugin[roundType];
            RoundTypeMenuHandler menuHandler = g_RoundTypeMenuHandlers[roundType];
            Call_StartFunction(pluginSource, menuHandler);
            Call_PushCell(client);
            Call_Finish();
        } else {
            ReturnMenuControl(client);
        }

    } else {
        g_CurrentRoundTypeMenuIndex[client]++;
        int roundType = g_CurrentRoundTypeMenuIndex[client];
        if (roundType < g_numRoundTypes) {

            // if optional: give the menu to choose it, otherwise: carry on back to the controller
            if (g_RoundTypeOptional[roundType]) {
                GiveAllowMenu(client, roundType);
                g_WaitingOnRoundAllow[client] = true;
            } else {
                ReturnMenuControl(client);
                g_WaitingOnRoundAllow[client] = false;
            }

        } else {
            // last part of the menu:
            GivePreferenceMenu(client);
        }
    }
}

public void GiveAllowMenu(int client, int roundType) {
    Handle menu = CreateMenu(MenuHandler_AllowRoundType);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Allow %s rounds?", g_RoundTypeDisplayNames[roundType]);
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_LENGTH);
}

public MenuHandler_AllowRoundType(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        int roundType = g_CurrentRoundTypeMenuIndex[client];
        g_AllowedRoundTypes[client][roundType] = choice;
        char cookieName[128];
        GetRoundCookieName(roundType, cookieName, sizeof(cookieName));
        SetCookieBoolByName(client, cookieName, choice);
        ReturnMenuControl(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}


static void GetRoundCookieName(int roundType, char[] buffer, int length) {
    Format(buffer, length, "multi1v1_allow%s", g_RoundTypeNames[roundType]);
}



/*************************
 *                       *
 *  Default round types  *
 *                       *
 *************************/

public void AddStandardRounds() {
    AddRoundType(INVALID_HANDLE, "Rifle", "rifle", RifleHandler, Multi1v1_NullChoiceMenu, false, true, "rifleRating");
    AddRoundType(INVALID_HANDLE, "Pistol", "pistol", PistolHandler, Multi1v1_NullChoiceMenu, true, true, "pistolRating");
    AddRoundType(INVALID_HANDLE, "AWP", "awp", AwpHandler, Multi1v1_NullChoiceMenu, true, true, "awpRating");
}

public void RifleHandler(int client) {
    Client_RemoveAllWeapons(client, "", true);
    GiveWeapon(client, g_PrimaryWeapon[client]);
    SetEntData(client, g_iPlayers_HelmetOffset, 1);
    Client_SetArmor(client, 100);

    int pistolBehavior = GetConVarInt(g_hPistolBehavior);
    if (pistolBehavior != 1) {
        GiveWeapon(client, g_SecondaryWeapon[client]);
    }
    GiveWeapon(client, "weapon_knife");
}

public void PistolHandler(int client) {
    Client_RemoveAllWeapons(client, "", true);
    GiveWeapon(client, g_SecondaryWeapon[client]);
    SetEntData(client, g_iPlayers_HelmetOffset, 0);
    bool giveKevlar = IsDefaultPistol(g_SecondaryWeapon[client]);
    if (giveKevlar) {
        Client_SetArmor(client, 100);
    } else {
        Client_SetArmor(client, 0);
    }
    GiveWeapon(client, "weapon_knife");
}

public void AwpHandler(int client) {
    Client_RemoveAllWeapons(client, "", true);
    GiveWeapon(client, "weapon_awp");
    SetEntData(client, g_iPlayers_HelmetOffset, 1);

    int pistolBehavior = GetConVarInt(g_hPistolBehavior);
    if (pistolBehavior == 0) {
        GiveWeapon(client, g_SecondaryWeapon[client]);
    } else if (pistolBehavior == 2 || pistolBehavior == 3) {
        char defaultPistol[32];
        GetConVarString(g_hDefaultPistol, defaultPistol, sizeof(defaultPistol));
        GiveWeapon(client,  defaultPistol);
    }
    GiveWeapon(client, "weapon_knife");
}
