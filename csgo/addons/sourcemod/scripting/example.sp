#define PLUGIN_VERSION "1.0.0"
#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include "include/multi1v1.inc"

public Plugin:myinfo = {
    name = "Multi-1v1 example module",
    author = "splewis",
    description = "CS:GO Multi-1v1 example module plugin",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");
}

public OnPreArenaRestart(Handle:queue) {
    PrintToServer("Called OnPreArenaRestart");
}

public OnRankingQueueSet(Handle:queue) {
    PrintToServer("Called OnRankingQueueSet");
    for (new i = 0; i < GetArraySize(queue); i++) {
        new client = GetArrayCell(queue, i);
        if (IsClientInGame(client) && HasStats(client)) {
            PrintToServer("%N has rating %f", client, GetRating(client));
        }
    }
}

public OnPostArenaRestart() {
    PrintToServer("Called OnPostArenaRestart");
}
