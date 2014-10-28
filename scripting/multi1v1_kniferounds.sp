#include <sourcemod>
#include <smlib>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"

// Whether an arena will use a knife round this round or not:
bool g_ArenaKnifeRound[MAXPLAYERS+1];

// Client settings for allowing knife rounds
bool g_AllowKnife[MAXPLAYERS+1];
Handle g_hAllowKnifeCookie = INVALID_HANDLE;

// TODO:
// convar for:
//  - whether to give a tazer or not (currently true)
//  - probability of getting a knife round (currently 0.2)

public Plugin:myinfo = {
    name = "CS:GO Multi1v1: knife round addon",
    author = "splewis",
    description = "Adds a pseudo knife-round option when both playes in an arena allow it",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    g_hAllowKnifeCookie = RegClientCookie("multi1v1_kniferounds", "Whether to allow knife round types", CookieAccess_Protected);
}

public OnClientConnected(int client) {
    g_AllowKnife[client] = false;
}

public Multi1v1_OnArenasReady() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            Multi1v1_UnblockRatingChanges(i);
        }
    }

    for (int i = 1; i <= Multi1v1_GetNumActiveArenas(); i++) {
        int p1 = Multi1v1_GetArenaPlayer1(i);
        int p2 = Multi1v1_GetArenaPlayer2(i);

        g_ArenaKnifeRound[i] = false;
        if (IsPlayer(p1) && IsPlayer(p2) && g_AllowKnife[p1] && g_AllowKnife[p2] && GetRandomFloat() < 0.2) {
            g_ArenaKnifeRound[i] = true;
            Multi1v1_BlockRatingChanges(p1);
            Multi1v1_BlockRatingChanges(p2);
        }
    }
}

public Multi1v1_AfterPlayerSpawn(int client) {
    if (!IsActivePlayer(client)) {
        return;
    }

    if (g_ArenaKnifeRound[Multi1v1_GetArenaNumber(client)]) {
        Client_RemoveAllWeapons(client, "", true);
        GivePlayerItem(client, "weapon_knife");
        GivePlayerItem(client, "weapon_taser");
        Client_SetArmor(client, 100);
    }
}

public Multi1v1_OnGunsMenuDone(int client) {
    Handle menu = CreateMenu(MenuHandler_KnifeRounds);
    SetMenuTitle(menu, "Allow knife rounds?");
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, 15);
}

public MenuHandler_KnifeRounds(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        g_AllowKnife[client] = choice;
        SetCookieBool(client, g_hAllowKnifeCookie, choice);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;
    g_AllowKnife[client] = GetCookieBool(client, g_hAllowKnifeCookie);
}
