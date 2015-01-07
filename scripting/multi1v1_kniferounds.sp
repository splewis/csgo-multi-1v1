#include <sourcemod>
#include <smlib>
#include "include/multi1v1.inc"
#include "multi1v1/version.sp"

#pragma semicolon 1

public Plugin:myinfo = {
    name = "CS:GO Multi1v1: knife round addon",
    author = "splewis",
    description = "Adds an unranked knife round-type",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public void Multi1v1_OnRoundTypesAdded() {
    Multi1v1_AddRoundType("Knife", "knife", KnifeHandler, Multi1v1_NullChoiceMenu, true, false);
}

public void KnifeHandler(int client) {
    Client_RemoveAllWeapons(client, "", true);
    Client_SetArmor(client, 100);
    GivePlayerItem(client, "weapon_knife");
}
