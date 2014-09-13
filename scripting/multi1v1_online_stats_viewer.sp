#pragma semicolon 1
#include <sourcemod>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"

Handle g_hStatsWebsite = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "[Multi1v1] online stats viewer",
    author = "splewis",
    description = "Opens up a motd-style panel for players to view their 1v1 stats",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");
    g_hStatsWebsite = CreateConVar("sm_multi1v1_stats_url", "", "URL to send player stats to. For example: http://csgo1v1.splewis.net/redirect_stats/. The accountID is appened to this url for each player.");
    AutoExecConfig(true, "multi1v1_online_stats_viewer", "sourcemod/multi1v1");
    RegConsoleCmd("sm_stats", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rank", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rating", Command_Stats, "Displays a players multi-1v1 stats");
}

public Action Command_Stats(int client, args) {
    char arg1[32];
    if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
        int target = FindTarget(client, arg1, true, false);
        if (target != -1) {
            ShowStatsForPlayer(client, target);
        }
    } else {
        ShowStatsForPlayer(client, client);
    }

    return Plugin_Handled;
}

public Action OnClientSayCommand(client, const char command[], const char sArgs[]) {
    char chatTriggers[][] = { "rank", ".rank" };
    for (int i = 0; i < sizeof(chatTriggers); i++) {
        if (strcmp(sArgs[0], chatTriggers[i], false) == 0) {
            ShowStatsForPlayer(client, client);
        }
    }
    return Plugin_Continue;
}

public void ShowStatsForPlayer(int client, target) {
    char url[255];
    GetConVarString(g_hStatsWebsite, url, sizeof(url));
    if (StrEqual(url, "")) {
        Multi1v1Message(client, "Sorry, there is no stats website for this server.");
        return;
    }

    char player_url[255];
    Format(player_url, sizeof(player_url), "%s%d", url, GetSteamAccountID(target));
    ShowMOTDPanel(client, "Multi1v1 Stats", player_url, MOTDPANEL_TYPE_URL);
    QueryClientConVar(client, "cl_disablehtmlmotd", CheckMOTDAllowed, client);
}

public void CheckMOTDAllowed(QueryCookie cookie, int client, ConVarQueryResult result, const char cvarName[], const char cvarValue[]) {
    if (!StrEqual(cvarValue, "0")) {
        Multi1v1Message(client, "You must have {LIGHT_GREEN}cl_disablehtmlmotd 0 {NORMAL}to use that command.");
    }
}
