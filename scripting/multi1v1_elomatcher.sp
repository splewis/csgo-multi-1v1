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

OnPreArenaRankingsSet(Handle rankingQueue) {
    // TODO: take this (empty) adt array and fill in players, matched
    // according to their elo rankins.
    // Relevent functions:
    //
    // native bool HasDatabase();
    // native bool HasStats(client);
    // native float GetRating(client);
    // native bool IsActivePlayer(client);
    //
    // It might be a good idea to do *nothing* if HasDatabase is false.
    // It's okay to *not* add players to the queue as well.
    //
    // Use IsInArena to determine who should be added.
    // Also check for players in the queue (GetQueue())
    // if there is space for them (GetMaximumArenas() * 2).

    LogError("[OnPreArenaRankingsSet] Unimplemented");
}
