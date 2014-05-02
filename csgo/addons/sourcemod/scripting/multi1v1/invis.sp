#include <sourcemod>

new bool:g_Invis[MAXPLAYERS+1];

public Action:Command_ToggleInvis(client, args) {
    g_Invis[client] = !g_Invis[client];
    if (g_Invis[client]) {
        SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
        PrintToChat(client, "Invis enabled");
    } else {
        SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
        PrintToChat(client, "Invis disabled");
    }
}

public Action:Hook_SetTransmit(client, entity) {
    if (client == entity) {
        return Plugin_Continue;
    }
    return Plugin_Handled;
}
