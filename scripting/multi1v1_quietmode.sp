#pragma semicolon 1
#include <sourcemod>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"


public Plugin:myinfo = {
    name = "[Multi1v1] quiet mode",
    author = "splewis",
    description = "Changes voice chat so players only hear their opponents",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPostArenaRankingsSet(Handle rankingQueue) {
    // TODO:
    // For each client, set it so:
    //  - they can hear their opponent
    //  - they can't hear anyone else
    //  Using SetListenOverride() and GetOpponent()
    LogError("[OnPostArenaRankingsSet] Unimplemented");
}
