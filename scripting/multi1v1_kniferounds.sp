#include <sourcemod>
#include <smlib>
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"

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
    // add convars here
}

public Multi1v1_OnRoundTypesAdded() {
    Multi1v1_AddRoundType("Knife", "knife", KnifeHandler, Multi1v1_NullChoiceMenu, true, false);
}

public void KnifeHandler(int client) {
    Client_RemoveAllWeapons(client, "", true);
    Client_SetArmor(client, 100);
    GivePlayerItem(client, "weapon_knife");
}
