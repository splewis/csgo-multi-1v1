#include <sourcemod>

#define WEAPON_LENGTH 24
new String:g_primaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:g_secondaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new RoundType:g_roundTypes[MAXPLAYERS + 1];

enum RoundType {
	RoundType_Rifle = 0,
	RoundType_Awp = 1,
	RoundType_Pistol = 2
};

new bool:g_AllowAWP[MAXPLAYERS+1];
new bool:g_AllowPistol[MAXPLAYERS+1];
new RoundType:g_Preference[MAXPLAYERS+1];


/**
 * Hook for player chat actions.
 */
public Action:Command_Say(client, const String:command[], argc) {
	decl String:text[192];
	if (GetCmdArgString(text, sizeof(text)) < 1)
		return Plugin_Continue;
	StripQuotes(text);
	if (strcmp(text[0], "guns", false) == 0 || strcmp(text[0], "!guns", false) == 0) {
		AWPMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public AWPMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_AWP);
	SetMenuTitle(menu, "Allow AWP rounds?");
	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_AWP(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		if (StrEqual("yes", info))
			g_AllowAWP[client] = true;
		else
			g_AllowAWP[client] = false;

		PistolMenu(client);
	}
}

public PistolMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_Pistol);
	SetMenuTitle(menu, "Allow pistol rounds?");
	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Pistol(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));

		if (StrEqual("yes", info))
			g_AllowPistol[client] = true;
		else
			g_AllowPistol[client] = false;

		if (g_AllowPistol[client] || g_AllowAWP[client])
			PreferenceMenu(client);
		else
			RifleChoiceMenu(client);
	}
}

/**
 * Primary weapon choice menu.
 */
public PreferenceMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_Preference);
	SetMenuTitle(menu, "Choose your preference:");
	AddMenuItem(menu, "rifle", "Rifle Rounds");
	if (g_AllowAWP[client])
		AddMenuItem(menu, "awp", "AWP Rounds");
	if (g_AllowPistol[client])
		AddMenuItem(menu, "pistol", "Pistol Rounds");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_Preference(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));

		if (StrEqual("rifle", info))
			g_Preference[client] = RoundType_Rifle;
		else if (StrEqual("awp", info))
			g_Preference[client] = RoundType_Awp;
		else
			g_Preference[client] = RoundType_Pistol;

		RifleChoiceMenu(client);
	}
}

/**
 * Primary weapon choice menu.
 */
public RifleChoiceMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_RifleChoice);
	SetMenuTitle(menu, "Choose your favorite rifle:");
	AddMenuItem(menu, "weapon_ak47", "AK47");
	AddMenuItem(menu, "weapon_m4a1", "M4A4");
	AddMenuItem(menu, "weapon_m4a1_silencer", "M4A1-S");
	AddMenuItem(menu, "weapon_famas", "Famas");
	AddMenuItem(menu, "weapon_galilar", "Galil");
	AddMenuItem(menu, "weapon_aug", "AUG");
	AddMenuItem(menu, "weapon_sg556", "SG553");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/**
 * Displays secondary menu to a player
 */
public PistolChoiceMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_PistolChoice);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "Choose your favorite pistol:");
	AddMenuItem(menu, "weapon_hkp2000", "P2000");
	AddMenuItem(menu, "weapon_usp_silencer", "USP");
	AddMenuItem(menu, "weapon_glock", "Glock");
	AddMenuItem(menu, "weapon_p250", "P250");
	AddMenuItem(menu, "weapon_cz75a", "CZ75");
	AddMenuItem(menu, "weapon_deagle", "Deagle");
	AddMenuItem(menu, "weapon_fiveseven", "Five-Seven");
	AddMenuItem(menu, "weapon_tec9", "Tec-9");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/**
 * Primary weapon handler - updates primaryWeapon.
 */
public MenuHandler_RifleChoice(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_primaryWeapon[client] = info;
		PistolChoiceMenu(client);
	}
}

/**
 * Secondary weapon handler - updates secondary weapon.
 */
public MenuHandler_PistolChoice(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_secondaryWeapon[client] = info;
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

/**
 * Generic chat message about what to type to get the guns menu.
 */
public Action:Timer_PrintGunsMessage(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client)) {
		PrintToChat(client, " \x01\x0B\x05Type \x04guns \x05into chat to select new weapons.");
	}
	return Plugin_Handled;
}

/**
 * Generic chat message about what to type to get the guns menu using the hint text.
 */
public Action:Timer_PrintGunsHint(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client)) {
		PrintHintText(client, "Type guns into chat to select new weapons.");
	}
	return Plugin_Handled;
}

public RoundType:GetRoundType(client1, client2) {
	if (!IsValidClient(client1) || !IsValidClient(client2))
		return RoundType_Rifle;

	new RoundType:roundType = RoundType_Rifle;
	new RoundType:pref1 = g_Preference[client1];
	new RoundType:pref2 = g_Preference[client2];

	if (pref1 == pref2) {
		roundType = pref1;
	} else {
		new Handle:types = CreateArray();
		if (g_AllowAWP[client1] && g_AllowAWP[client2])
			PushArrayCell(types, RoundType_Awp);
		if (g_AllowPistol[client1] && g_AllowPistol[client2])
			PushArrayCell(types, RoundType_Pistol);
		PushArrayCell(types, RoundType_Rifle);

		new len = GetArraySize(types);
		new index = GetRandomInt(0, len - 1);
		roundType = GetArrayCell(types, index);
		CloseHandle(types);
	}

	return roundType;
}

