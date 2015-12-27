#include <sourcemod>
#include "include/multi1v1.inc"
#include "include/logdebug.inc"
#include "include/priorityqueue.inc"

#include "multi1v1/version.sp"
#include "multi1v1/generic.sp"

#pragma semicolon 1
#pragma newdecls required

int g_ClientPartners[MAXPLAYERS+1];

// Mapping of receiving client -> who sent the last request.
// -1 if there is no request.
int g_OutstandingPartnerRequests[MAXPLAYERS+1];
bool g_HasOutstandingPartnerRequest[MAXPLAYERS+1];

// Arena-data.
int g_ClientArenas[MAXPLAYERS+1]; // which arena the client is currently in
int g_ArenasTeam1Clients[MAXPLAYERS+1][2];
int g_ArenasTeam2Clients[MAXPLAYERS+1][2];

public Plugin myinfo = {
    name = "CS:GO Multi1v1: 2v2 arenas modification",
    author = "splewis",
    description = "TODO",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "2v2arenas");
    LoadTranslations("common.phrases");
    LoadTranslations("multi1v1.phrases");

    RegConsoleCmd("sm_group", Command_Group, "TODO");
    RegConsoleCmd("sm_partner", Command_Group, "TODO");
    RegConsoleCmd("sm_accept", Command_Accept, "TODO");
    RegConsoleCmd("sm_reject", Command_Reject, "TODO");
}

public void OnMapStart() {
    for (int i = 1; i <= Multi1v1_GetMaximumArenas(); i++) {
        g_ArenasTeam1Clients[i][0] = -1;
        g_ArenasTeam1Clients[i][1] = -1;
        g_ArenasTeam2Clients[i][0] = -1;
        g_ArenasTeam2Clients[i][1] = -1;
    }
}

public void OnClientConnected(int client) {
    g_HasOutstandingPartnerRequest[client] = false;
    g_ClientPartners[client] = -1;
    g_OutstandingPartnerRequests[client] = -1;
    g_ClientArenas[client] = -1;
}

// Performs error checking to ensure spawns have enough arenas.
public void Multi1v1_OnSpawnsFound(ArrayList ctOrigins, ArrayList ctAngles, ArrayList tOrigins, ArrayList tAngles) {
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    bool displayedMapName = false; // To make sure the map name is only displayed once.
    int numArenas = Multi1v1_GetMaximumArenas();

    for (int i = 1; i <= numArenas; i++) {
        int numSpawns = Multi1v1_GetNumSpawnsInArena(i);
        if (numSpawns < 2) {
            if (!displayedMapName) {
                LogError("Issues with 2v2's on map: %s", mapName);
                displayedMapName = true;
            }

            LogError("Arena %d does not have enough spawns for 2v2 support (%d spawns per team).",
                     i, numSpawns);
        }
    }
}

public void Multi1v1_OnPostArenaRankingsSet(Handle rankingQueue) {
    ClearArray(rankingQueue); // so multi1v1 doesn't place players
}

/**
 * Logic for clients joining groups.
 */
public Action Command_Group(int client, int args) {
    if (g_HasOutstandingPartnerRequest[client]) {
        Multi1v1_Message(client, "You already have an outstanding partner request");
        return Plugin_Handled;
    }

    char arg1[32];
    if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
        int target = FindTarget(client, arg1, true, false);
        if (target != -1) {
            if (g_OutstandingPartnerRequests[target]) {
                g_ClientPartners[client] = target;
                Multi1v1_Message(client, "Sent partner request to %N", target);
                CreateTimer(15.0, Timer_ClearPartnerRequest, GetClientSerial(client));
            } else {
                Multi1v1_Message(client, "You already have an outstanding partner request");
            }
        }
    } else {
        Multi1v1_Message(client, "Unknown target.");
    }

    return Plugin_Handled;
}

public Action Command_Accept(int client, int args) {
    int sender = g_OutstandingPartnerRequests[client];
    if (IsPlayer(sender) && g_HasOutstandingPartnerRequest[sender]) {

    }
    return Plugin_Handled;
}


public Action Command_Reject(int client, int args) {
    int sender = g_OutstandingPartnerRequests[client];
    if (IsPlayer(sender) && g_HasOutstandingPartnerRequest[sender]) {

    }
    return Plugin_Handled;
}

public Action Timer_ClearPartnerRequest(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    g_HasOutstandingPartnerRequest[client] = false;
    return Plugin_Handled;
}

bool ArePartners(int client1, int client2) {
    return IsPlayer(client1) && IsPlayer(client2) &&
    g_ClientPartners[client1] == client2 &&
    g_ClientPartners[client2] == client1;
}

bool HasPartner(int client) {
    return ArePartners(client, g_ClientPartners[client]);
}
