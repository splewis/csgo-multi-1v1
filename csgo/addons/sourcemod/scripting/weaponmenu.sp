#include <sourcemod>

#define WEAPON_LENGTH 24
new String:primaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:secondaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];

public Action:Command_guns(client, args) {
	PrimaryMenu(client);
}

public Action:Command_Say(client, const String:command[], argc) {
	decl String:text[192];
	if (GetCmdArgString(text, sizeof(text)) < 1)
		return Plugin_Continue;
	StripQuotes(text);
	if (strcmp(text[0], "guns", false) == 0) {
		Command_guns(client, 0);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public PrimaryMenu(client) {
	new Handle:menu = CreateMenu(Weapon_MenuHandler_Primary);
	SetMenuTitle(menu, "Choose your primary weapon:");
	AddMenuItem(menu, "weapon_ak47", "AK47");
	AddMenuItem(menu, "weapon_m4a1", "M4A4");
	AddMenuItem(menu, "weapon_m4a1_silencer", "M4A1-S");
	AddMenuItem(menu, "weapon_famas", "Famas");
	AddMenuItem(menu, "weapon_galilar", "Galil");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

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
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Weapon_MenuHandler_Primary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		primaryWeapon[param1] = info;
		SecondaryMenu(param1);
	}
}

public Weapon_MenuHandler_Secondary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		secondaryWeapon[param1] = info;
		PrintToChat(param1, "You will get your new weapons next spawn.");
	}
}

public Action:Timer_PrintGunsMessage(Handle:timer, any:client) {
	if (IsValidClient(client)) {
		PrintToChat(client, "Type \x04guns\x01 into chat to select new weapons.");
	}
	return Plugin_Handled;
}
