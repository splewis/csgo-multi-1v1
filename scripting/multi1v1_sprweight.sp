#pragma semicolon 1
#include <sourcemod>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"


public Plugin:myinfo = {
    name = "[Multi1v1] smart player report weight handler",
    author = "splewis",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};


public Float:ReportWeight(reporter, victim) {
    if (!IsPlayer(reporter) || !IsPlayer(victim))
        return -1.0;

    if (!HasStats(reporter) || !HasStats(victim))
        return 2.0;

    new Float:weight = 1.0;
    #define WEIGHT(%1) if (%1) weight += 1.0

    new Float:reporter_rating = GetRating(reporter);
    new Float:victim_rating = GetRating(victim);
    new any:reporter_rounds = GetRoundsPlayed(reporter);
    new any:victim_rounds = GetRoundsPlayed(victim);

    WEIGHT(reporter_rating > 1700.0);
    WEIGHT(reporter_rating > 1800.0);
    WEIGHT(reporter_rating > 1900.0);
    WEIGHT(victim_rating > 1750.0);
    WEIGHT(victim_rating > 2000.0);
    WEIGHT(GetArenaNumber(victim) <= 2);
    WEIGHT(victim_rounds < 50);
    WEIGHT(victim_rounds < 100);
    WEIGHT(victim_rounds < 500);
    WEIGHT(reporter_rounds > 1000);
    WEIGHT(reporter_rounds > 3000);
    WEIGHT(reporter_rounds > 5000);
    WEIGHT(reporter_rounds > 5000);

    return weight;
}
