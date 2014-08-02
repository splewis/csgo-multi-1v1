#pragma semicolon 1
#include <sourcemod>


/** multi1v1 function includes **/
#include "multi1v1/generic.sp"
#include "multi1v1/queue.sp"
#include "multi1v1/spawns.sp"


public Plugin:myinfo = {
    name = "[Multi1v1] Base plugin",
    author = "splewis",
    description = "Multi-arena 1v1 laddering",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    ThrowError("[OnPluginStart] Unimplemented tests");
}
