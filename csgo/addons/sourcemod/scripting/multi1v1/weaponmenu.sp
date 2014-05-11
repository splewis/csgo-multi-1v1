#include <sourcemod>
#include "roundTypes.sp"

#define WEAPON_LENGTH 32
new String:g_primaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:g_secondaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new RoundType:g_roundTypes[MAXPLAYERS + 1];

new Handle:g_hAllowPistolCookie = INVALID_HANDLE;
new Handle:g_hAllowAWPCookie = INVALID_HANDLE;
new Handle:g_hPreferenceCookie = INVALID_HANDLE;
new Handle:g_hRifleCookie = INVALID_HANDLE;
new Handle:g_hPistolCookie = INVALID_HANDLE;
new Handle:g_hSetCookies = INVALID_HANDLE;

new bool:g_AllowAWP[MAXPLAYERS+1];
new bool:g_AllowPistol[MAXPLAYERS+1];
new RoundType:g_Preference[MAXPLAYERS+1];

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

	if (pref1 == pref2) {
		roundType = pref1;
	} else {
		// create array of "allowed" round types
		new Handle:types = CreateArray();
		if (g_AllowAWP[client1] && g_AllowAWP[client2])
			PushArrayCell(types, RoundType_Awp);
		if (g_AllowPistol[client1] && g_AllowPistol[client2])
			PushArrayCell(types, RoundType_Pistol);
		PushArrayCell(types, RoundType_Rifle);

		// pick a random value from the allowed round types
		new len = GetArraySize(types);
		new index = GetRandomInt(0, len - 1);
		roundType = GetArrayCell(types, index);
		CloseHandle(types);
	}

	return roundType;
}

/**
 * Sets a cookie, checking if it isn't cached yet.
 */
public SafeSetCookie(client, Handle:cookie, String:value[]) {
	if (AreClientCookiesCached(client)) {
		SetClientCookie(client, cookie, value);
	}
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
		if (StrEqual("yes", info)) {
			g_AllowAWP[client] = true;
		} else {
			g_AllowAWP[client] = false;
		}

		SafeSetCookie(client, g_hAllowAWPCookie, info);
		PistolMenu(client);
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
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

		if (StrEqual("yes", info)) {
			g_AllowPistol[client] = true;
		} else {
			g_AllowPistol[client] = false;
		}

		SafeSetCookie(client, g_hAllowPistolCookie, info);

		if (g_AllowPistol[client] || g_AllowAWP[client]) {
			PreferenceMenu(client);
		} else {
			g_Preference[client] = RoundType_Rifle;
			SafeSetCookie(client, g_hPreferenceCookie, "rifle");
			RifleChoiceMenu(client);
		}
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}

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

		SafeSetCookie(client, g_hPreferenceCookie, info);
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
 * Rifle weapon handler - updates primaryWeapon.
 */
public MenuHandler_RifleChoice(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_primaryWeapon[client] = info;
		SafeSetCookie(client, g_hRifleCookie, info);
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
	AddMenuItem(menu, "weapon_hkp2000", "P2000");
	AddMenuItem(menu, "weapon_usp_silencer", "USP");
	AddMenuItem(menu, "weapon_glock", "Glock");
	AddMenuItem(menu, "weapon_p250", "P250");
	AddMenuItem(menu, "weapon_cz75a", "CZ75");
	AddMenuItem(menu, "weapon_deagle", "Deagle");
	AddMenuItem(menu, "weapon_fiveseven", "Five-Seven");
	AddMenuItem(menu, "weapon_tec9", "Tec9");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/**
 * Pistol choice handler - updates secondary weapon.
 */
public MenuHandler_PistolChoice(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		new any:client = param1;
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_secondaryWeapon[client] = info;
		SafeSetCookie(client, g_hPistolCookie, info);
		SafeSetCookie(client, g_hSetCookies, "yes");
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
