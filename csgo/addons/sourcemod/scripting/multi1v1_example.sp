// This is a skeleton plugin meant to demonstrate all of the forwards
// defined by the base Multi1v1 plugin. A few of the natives may
// also be demonstrated.

#include <sourcemod>
#include <cstrike>
#include "include/multi1v1.inc"

public Plugin:myinfo = {
    name = "Multi-1v1 example module",
    author = "splewis",
    description = "CS:GO Multi-1v1 example module plugin",
    version = "1.0.0",
    url = "https://github.com/splewis/csgo-multi-1v1"
};



/** Regular sourcemod forwards you are likely to need **/

public OnPluginStart() {
}

public OnMapStart() {
}

public OnMapEnd() {
}



/** All of the multi1v1 forwards should be listed here **/

// This is called before any round-restart actions occur.
// The queue passed is the ranking queue that will be used and is empty.
// You can pass players in here safely and they will be in the front.
// Players will never be added to the queue if they are already in it.
public OnPreArenaRestart(Handle:queue) {
    PrintToServer("Called OnPreArenaRestart");
}

// This is called after the plugin finishes creating the ranking-queue.
// You can change the ordering by altering the queue array.
public OnRankingQueueSet(Handle:queue) {
    PrintToServer("Called OnRankingQueueSet");
    for (new i = 0; i < GetArraySize(queue); i++) {
        new client = GetArrayCell(queue, i);
        if (IsClientInGame(client) && HasStats(client)) {
            Multi1v1Message(i, "You have a rating of \x04%f", client, GetRating(client));
        }
    }
}

// This is the last chance to do anything before the round start.
public OnPostArenaRestart() {
    PrintToServer("Called OnPostArenaRestart");
}

// Called anytime player ratings change. This is not guaranteed to fire
// for each round, e.g., if a player disconnects in an arena or someone
// has no opponent.
// The forceLoss variable is true only if the players let time run out.
// In that case, you should consider both winner and loser 'losers' of the round.
public Action:OnRatingChange(winner, loser, bool:forceLoss, Float:delta) {
    PrintToServer("%N beat %N, delta rating=%f, force loss(time ran out)=%d",
                  winner, loser, delta, forceLoss);
    return Plugin_Continue;
}
