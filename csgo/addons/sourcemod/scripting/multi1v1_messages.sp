#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include "multi1v1/generic.sp"
#include "multi1v1/queue.sp"
#include "include/multi1v1.inc"

public Plugin:myinfo = {
    name = "[Multi1v1] Chat messages module",
    author = "splewis",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");
    HookEvent("cs_win_panel_match", Event_MatchOver);
}

public OnRankingQueueSet(Handle:queue) {
    new Handle:waitingQueue = GetWaitingQueue();
    for (new i = 0; i < Queue_Length(waitingQueue); i++) {
        new client = GetArrayCell(waitingQueue, i);
        Multi1v1Message(client, "Sorry, all the arenas are currently \x03full.");
        Multi1v1Message(client, "You are in position \x04%d \x01in the waiting queue", i + 1);
    }
}

public OnPostArenaRestart() {
    for (new i = 1; i <= MaxClients; i++) {
        new other = GetOpponent(i);
        new arena = GetArenaNumber(i);
        if (IsValidClient(other)) {
            Multi1v1Message(i, "You are in arena \x04%d\x01, facing off against \x03%N", arena, other);
        } else {
            Multi1v1Message(i, "You are in arena \x04%d\x01 with \x07no opponent", arena);
        }
    }
}

public OnRatingChange(winner, loser, bool:forceLoss, Float:delta) {
    if (!HasStats(winner) || !HasStats(loser))
        return;

    new int_delta = RoundToNearest(delta);
    new int_winner = RoundToNearest(GetRating(winner)) + int_delta;
    new int_loser = RoundToNearest(GetRating(loser)) + int_delta;

    if (forceLoss) {
        ForceLossMessage(winner, int_delta, int_winner);
        ForceLossMessage(loser, int_delta, int_loser);
    } else {
        Multi1v1Message(winner, "\x04You \x01(rating \x04%d\x01, \x06+%d\x01) beat \x03%N \x01(rating \x03%d\x01, \x02-%d\x01)",
                      int_winner, delta, loser, int_loser, delta);
        Multi1v1Message(loser,  "\x04You \x01(rating \x04%d\x01, \x07-%d\x01) lost to \x03%N \x01(rating \x03%d\x01, \x06+%d\x01)",
                      int_loser, delta, winner, int_winner, delta);
    }
}

static ForceLossMessage(client, any:rating, any:delta) {
    Multi1v1Message(client, "\x04You \x01(rating \x04%d\x01, \x07-%d\x01) let time run out",
                    rating, delta);
}

public Event_MatchOver(Handle:event, const String:name[], bool:dontBroadcast) {
    new maxClient = -1;
    new maxScore = -1;
    for (new i = 1; i <= MaxClients; i++) {
        if (!IsPlayer(i))
            return;

        new score = GetRoundsAtArena1(i);
        if (maxClient == -1 || score > maxScore) {
            maxClient = i;
            maxScore = score;
        }
    }

    if (IsPlayer(maxClient))
        Multi1v1MessageToAll("\x04%N \x01had the most wins \x03(%d) \x01in arena 1 this map",
                           maxClient, maxScore);
}
