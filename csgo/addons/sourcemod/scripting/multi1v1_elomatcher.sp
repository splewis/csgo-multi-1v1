#pragma semicolon 1
#include <sourcemod>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"


public Plugin:myinfo = {
    name = "[Multi1v1] elo-rating arena matcher",
    author = "splewis",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

OnPostArenaRankingsSet(Handle:rankingQueue) {

}
