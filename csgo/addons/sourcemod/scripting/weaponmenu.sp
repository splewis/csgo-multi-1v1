#include <sourcemod>

#define WEAPON_LENGTH 24
new String:g_backupWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:g_primaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:g_secondaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];

/**
 * Hook for player chat actions.
 */
public Action:Command_Say(client, const String:command[], argc) {
	decl String:text[192];
	if (GetCmdArgString(text, sizeof(text)) < 1)
		return Plugin_Continue;
	StripQuotes(text);
	if (strcmp(text[0], "guns", false) == 0 || strcmp(text[0], "!guns", false) == 0) {
		PrimaryMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

/**
 * Primary weapon choice menu.
 */
public PrimaryMenu(client) {
	new Handle:menu = CreateMenu(Weapon_MenuHandler_Primary);
	SetMenuTitle(menu, "Choose your primary weapon:");
	AddMenuItem(menu, "weapon_ak47", "AK47");
	AddMenuItem(menu, "weapon_m4a1", "M4A4");
	AddMenuItem(menu, "weapon_m4a1_silencer", "M4A1-S");
	AddMenuItem(menu, "weapon_awp", "AWP");
	AddMenuItem(menu, "weapon_famas", "Famas");
	AddMenuItem(menu, "weapon_galilar", "Galil");
	AddMenuItem(menu, "weapon_aug", "AUG");
	AddMenuItem(menu, "weapon_sg556", "SG553");
	AddMenuItem(menu, "weapon_ssg08", "SSG08");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

/**
 * Displays secondary menu to a player
 */
public SecondaryMenu(client) {
	new Handle:menu = CreateMenu(Weapon_MenuHandler_Secondary);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "Choose your secondary weapon:");
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
 * Primary weapon handler - updates primaryWeapon and sets the backup weapon if needed.
 */
public Weapon_MenuHandler_Primary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));

		if (!StrEqual(g_primaryWeapon[param1], "weapon_awp")) {
			g_backupWeapon[param1] = g_primaryWeapon[param1];
		}

		g_primaryWeapon[param1] = info;
		if (StrEqual(info, "weapon_awp")) {
			PrintToChat(param1, "You will be able to AWP \x07only if your opponent is also AWPing. \x01Otherwise, you will get your current weapon.");
		}
		SecondaryMenu(param1);
	}
}

/**
 * Secondary weapon handler - updates secondary weapon and informs player when they get the weapons.
 */
public Weapon_MenuHandler_Secondary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		g_secondaryWeapon[param1] = info;
		PrintToChat(param1, "You will get your new weapons next spawn.");
	}
}

/**
 * Generic chat message about what to type to get the guns menu.
 */
public Action:Timer_PrintGunsMessage(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client)) {
		PrintToChat(client, "Type \x04guns\x01 into chat to select new weapons.");
	}
	return Plugin_Handled;
}
