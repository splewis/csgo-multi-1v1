#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"
#include "multi1v1/version.sp"

#pragma semicolon 1
#pragma newdecls required

bool g_GiveFlash[MAXPLAYERS+1];
Handle g_hFlashCookie = INVALID_HANDLE;

public Plugin myinfo = {
    name = "CS:GO Multi1v1: flashbangs addon",
    author = "splewis",
    description = "Adds an option to give players flashbangs",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public void OnPluginStart() {
	g_hFlashCookie = RegClientCookie("multi1v1_flashbang", "Multi-1v1 allow flashbangs in rounds", CookieAccess_Protected);
}

public void OnClientConnected(int client) {
    g_GiveFlash[client] = false;
}

public void Multi1v1_OnGunsMenuDone(int client) {
    Handle menu = CreateMenu(MenuHandler_FlashChoice);
    SetMenuExitButton(menu, true);
    SetMenuTitle(menu, "Give players flashbangs?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, 10);
}

public int MenuHandler_FlashChoice(Handle menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        g_GiveFlash[client] = choice;
        SetCookieBool(client, g_hFlashCookie, choice);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void Multi1v1_AfterPlayerSetup(int client) {
    if (!IsActivePlayer(client)) {
        return;
    }

    int arena = Multi1v1_GetArenaNumber(client);
    int p1 = Multi1v1_GetArenaPlayer1(arena);
    int p2 = Multi1v1_GetArenaPlayer2(arena);

    if (p1 >= 0 && p2 >= 0 && g_GiveFlash[p1] && g_GiveFlash[p2]) {
        GivePlayerItem(client, "weapon_flashbang");
    }
}

public void OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;
    g_GiveFlash[client] = GetCookieBool(client, g_hFlashCookie);
}
