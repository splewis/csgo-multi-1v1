#define PLUGIN_VERSION "0.1.0"
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <smlib>



/***********************
 *                     *
 *  Global Variables   *
 *                     *
 ***********************/

#define WEAPON_LENGTH 32  // length of a weapon name string
#define HIDE_RADAR_BIT 1<<12

/** Assertions/debug info **/
new String:assertBuffer[1024];
#if !defined ASSERT_MODE
#define ASSERT_MODE LogError  // ThrowError is a good value for testing
#endif

/** Saved data for database interaction - be careful when using these, they may not
  *  be fetched, check multi1v1/stats.sp for a function that checks that instead of
  *  using one of these directly.
  */
new Float:g_ratings[MAXPLAYERS+1];
new Float:g_pistolRatings[MAXPLAYERS+1];
new Float:g_rifleRatings[MAXPLAYERS+1];
new Float:g_awpRatings[MAXPLAYERS+1];
new g_playerIDs[MAXPLAYERS+1];
new String:g_sqlBuffer[1024];

/** Database interactions **/
new bool:g_dbConnected = false;
new Handle:db = INVALID_HANDLE;

/** ConVar handles **/
new Handle:g_hCvarVersion = INVALID_HANDLE;
new Handle:g_hDefaultRatingVar = INVALID_HANDLE;
new Handle:g_hRoundTimeVar = INVALID_HANDLE;
new Handle:g_hUseDatabase = INVALID_HANDLE;

/** Client arrays **/
new g_Rankings[MAXPLAYERS+1] = -1;      // which arena each player is in
new g_RoundsLeader[MAXPLAYERS+1] = 0;   // number of rounds each player has been the winner
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false;  // Flags the teamswitches as being done by the plugin
new bool:g_isWaiting[MAXPLAYERS+1] = false;
new bool:g_SittingOut[MAXPLAYERS+1] = false;
new bool:g_AllowAWP[MAXPLAYERS+1];
new bool:g_AllowPistol[MAXPLAYERS+1];
new bool:g_GiveFlash[MAXPLAYERS+1];
new RoundType:g_Preference[MAXPLAYERS+1];
new String:g_primaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
new String:g_secondaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];

/** Arena arrays **/
new g_ArenaPlayer1[MAXPLAYERS+1] = -1;  // who is player 1 in each arena
new g_ArenaPlayer2[MAXPLAYERS+1] = -1;  // who is player 2 in each arena
new g_ArenaWinners[MAXPLAYERS+1] = -1;  // who won each arena
new g_ArenaLosers[MAXPLAYERS+1] = -1;   // who lost each arena
new RoundType:g_roundTypes[MAXPLAYERS+1];
new bool:g_LetTimeExpire[MAXPLAYERS+1] = false;

/** Overall global variables **/
new g_maxArenas = 0; // maximum number of arenas the map can support
new g_Arenas = 1; // number of active arenas
new g_TotalRounds = 0; // rounds played on this map so far
new g_LastWinner = -1; // winner of the previous round
new g_Score = 0; // the streak of the current winner
new g_HighestScore = 0; // the longest streak on the map so far
new bool:g_RoundFinished = false;
new g_numWaitingPlayers = 0;
new Handle:g_hQueue = INVALID_HANDLE;

/** The different round types **/
enum RoundType {
    RoundType_Rifle = 0,
    RoundType_Awp = 1,
    RoundType_Pistol = 2
};

/** Weapon menu choice cookies **/
new Handle:g_hAllowPistolCookie = INVALID_HANDLE;
new Handle:g_hAllowAWPCookie = INVALID_HANDLE;
new Handle:g_hPreferenceCookie = INVALID_HANDLE;
new Handle:g_hRifleCookie = INVALID_HANDLE;
new Handle:g_hPistolCookie = INVALID_HANDLE;
new Handle:g_hFlashCookie = INVALID_HANDLE;
new Handle:g_hSetCookies = INVALID_HANDLE;

/** Handles to arrays of vectors of spawns/angles **/
new Handle:g_hTSpawns = INVALID_HANDLE;
new Handle:g_hTAngles = INVALID_HANDLE;
new Handle:g_hCTSpawns = INVALID_HANDLE;
new Handle:g_hCTAngles = INVALID_HANDLE;

/** multi1v1 function includes **/
#include "multi1v1/queue.sp"
#include "multi1v1/spawns.sp"
#include "multi1v1/stats.sp"
#include "multi1v1/weaponmenu.sp"



/***********************
 *                     *
 * Sourcemod functions *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "CS:GO Multi-1v1",
    author = "splewis",
    description = "Multi-arena 1v1 laddering",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    /** ConVars **/
    g_hRoundTimeVar = CreateConVar("sm_multi1v1_roundtime", "30", "Roundtime (in seconds)", _, true, 5.0);
    g_hUseDatabase = CreateConVar("sm_multi1v1_use_database", "1", "Should we use a database to store stats and preferences");
    g_hDefaultRatingVar = CreateConVar("sm_multi1v1_default_rating", "1500.0", "ELO rating a player starts with", _, true, 300.0, true, 10000.0);
    g_hCvarVersion = CreateConVar("sm_multi1v1_version", PLUGIN_VERSION, "Current multi1v1 version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    /** Cookies **/
    g_hAllowPistolCookie = RegClientCookie("multi1v1_allowpistol", "Multi-1v1 allow pistol rounds", CookieAccess_Protected);
    g_hAllowAWPCookie = RegClientCookie("multi1v1_allowawp", "Multi-1v1 allow AWP rounds", CookieAccess_Protected);
    g_hPreferenceCookie = RegClientCookie("multi1v1_preference", "Multi-1v1 round-type preference", CookieAccess_Protected);
    g_hRifleCookie = RegClientCookie("multi1v1_rifle", "Multi-1v1 rifle choice", CookieAccess_Protected);
    g_hPistolCookie = RegClientCookie("multi1v1_pistol", "Multi-1v1 pistol choice", CookieAccess_Protected);
    g_hFlashCookie = RegClientCookie("multi1v1_flashbang", "Multi-1v1 pistol choice", CookieAccess_Protected);
    g_hSetCookies = RegClientCookie("multi1v1_setprefs", "Multi-1v1 if prefs are saved", CookieAccess_Protected);

    /** Client command hooks **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");
    AddCommandListener(OnJoinTeamCommand, "jointeam");

    /** Event hooks **/
    HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
    HookEvent("player_connect_full", Event_OnFullConnect);
    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_death", Event_OnPlayerDeath);
    HookEvent("round_start", Event_OnRoundStart);
    HookEvent("round_end", Event_OnRoundEnd);
}

public OnMapStart() {
    ServerCommand("exec sourcemod/multi1v1.cfg");
    if (!g_dbConnected && GetConVarInt(g_hUseDatabase) != 0) {
        DB_Connect();
    }
    Spawns_MapInit();
    g_Arenas = 1;
    g_TotalRounds = 0;
    g_LastWinner = -1;
    g_Score = 0;
    g_HighestScore = 0;
    g_RoundFinished = false;
    g_numWaitingPlayers = 0;
    for (new i = 0; i <= MAXPLAYERS; i++) {
        g_RoundsLeader[i] = 0;
        g_ArenaPlayer1[i] = -1;
        g_ArenaPlayer2[i] = -1;
        g_ArenaWinners[i] = -1;
        g_ArenaLosers[i] = -1;
    }
    GameRules_SetProp("m_bWarmupPeriod", false, _, _, true);
    GameRules_SetPropFloat("m_fWarmupPeriodEnd", GetGameTime(), _, true);
    CreateTimer(1.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public OnMapEnd() {
}

/**
 * Called once a client is authorized and fully in-game, and
 * after all post-connection authorizations have been performed.
 */
public OnClientPostAdminCheck(client) {
    if (IsClientInGame(client) && !IsFakeClient(client) && GetConVarInt(g_hUseDatabase) != 0) {
        DB_AddPlayer(client, GetConVarFloat(g_hDefaultRatingVar));
    }
}



/***********************
 *                     *
 *     Event Hooks     *
 *                     *
 ***********************/

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
public Event_OnFullConnect(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
}

/**
 * Silences team join/switch events.
 */
public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast) {
    dontBroadcast = true;
    return Plugin_Changed;
}

/**
 * RoundStart Event, sets up the players for each arena.
 */
public Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
    g_RoundFinished = false;

    for (new arena = 1; arena <= g_maxArenas; arena++) {
        g_ArenaWinners[arena] = -1;
        g_ArenaLosers[arena] = -1;
        if (g_ArenaPlayer2[arena] == -1) {
            g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
        }
    }

    for (new i = 1; i <= g_maxArenas; i++) {
        new p1 = g_ArenaPlayer1[i];
        new p2 = g_ArenaPlayer2[i];
        if (IsValidClient(p1)) {
            SetupPlayer(p1, i, p2, true);
        }
        if (IsValidClient(p2)) {
            SetupPlayer(p2, i, p1, false);
        }
    }

    for (new i = 1; i <= MAXPLAYERS; i++) {
        g_LetTimeExpire[i] = false;
    }

    GameRules_SetProp("m_iRoundTime", GetConVarInt(g_hRoundTimeVar), 4, 0, true);

    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i) && g_ratings[i] < 200.0) {
            DB_FetchRatings(i);
        }
    }

    CreateTimer(1.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

/**
 * Sets a player up for the round:
 *  - spawns them to the right arena with the right angles
 *  - sets the score/mvp count
 *  - prints out who the opponent is
 */
public SetupPlayer(client, arena, other, bool:onCT) {
    new Float:angles[3];
    new Float:spawn[3];

    if (onCT) {
        SwitchPlayerTeam(client, CS_TEAM_CT);
        GetArrayArray(g_hCTSpawns, arena - 1, spawn);
        GetArrayArray(g_hCTAngles, arena - 1, angles);
    } else {
        SwitchPlayerTeam(client, CS_TEAM_T);
        GetArrayArray(g_hTSpawns, arena - 1, spawn);
        GetArrayArray(g_hTAngles, arena - 1, angles);
    }

    CS_RespawnPlayer(client);
    TeleportEntity(client, spawn, angles, NULL_VECTOR);

    new score = 0;
    if (g_ArenaPlayer1[arena] == client)
        score = 3*g_Arenas - 3*arena + 1;
    else
        score = 3*g_Arenas - 3*arena;
    CS_SetClientContributionScore(client, score);
    CS_SetMVPCount(client, g_RoundsLeader[client]);

    decl String:buffer[32];
    Format(buffer, sizeof(buffer), "Arena %d", arena);
    CS_SetClientClanTag(client, buffer);

    if (IsValidClient(other)) {
        PrintToChat(client, "You are in arena \x04%d\x01, facing off against \x03%N", arena, other);
    } else {
        PrintToChat(client, "You are in arena \x04%d\x01 with \x07no opponent", arena);
    }
}

/**
 * RoundEnd event, updates the global variables for the next round.
 * Specifically:
 *  - updates ratings for this round
 *  - throws all the players into a queue according to their standing from this round
 *  - updates globals g_Rankings, g_ArenaPlayer1, g_ArenaPlayer2 for the next round setup
 */
public Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
    g_TotalRounds++;
    g_RoundFinished = true;

    // If time ran out and we have no winners/losers, set them
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = g_ArenaPlayer1[arena];
        new p2 = g_ArenaPlayer2[arena];
        if (g_ArenaWinners[arena] == -1) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
            if (IsValidClient(p1) && !IsFakeClient(p1) && IsValidClient(p2) && !IsFakeClient(p2)) {
                g_LetTimeExpire[p1] = true;
                g_LetTimeExpire[p2] = true;
            }
        }
        new winner = g_ArenaWinners[arena];
        new loser = g_ArenaLosers[arena];
        if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {
            if (winner != loser && GetConVarInt(g_hUseDatabase) != 0) {
                DB_RoundUpdate(winner, loser, g_roundTypes[arena]);
            }
        }

    }

    // Here we add each player to the queue in their new ranking
    g_hQueue = Queue_Init();

    //  top arena
    AddPlayer(g_ArenaWinners[1]);
    AddPlayer(g_ArenaWinners[2]);

    // middle arenas
    for (new i = 2; i <= g_Arenas - 1; i++) {
        AddPlayer(g_ArenaLosers[i - 1]);
        AddPlayer(g_ArenaWinners[i + 1]);
    }

    // bottom arena
    if (g_maxArenas >= 1) {
        AddPlayer(g_ArenaLosers[g_maxArenas - 1]);
        AddPlayer(g_ArenaLosers[g_maxArenas]);
    }

    // Add anyone that got missed
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && Queue_Find(g_hQueue, i) == -1)
            AddPlayer(i);
    }

    // Set leader and scoring information
    new leader = Queue_Peek(g_hQueue);
    if (IsValidClient(leader) && Queue_Length(g_hQueue) >= 2) {
        g_RoundsLeader[leader]++;
        CS_SetMVPCount(leader, g_RoundsLeader[leader]);
        if (g_LastWinner == leader && Queue_Length(g_hQueue) >= 2) {
            g_Score++;
            if (g_Score > g_HighestScore) {
                g_HighestScore = g_Score;
                PrintToChatAll(" \x01\x0B\x03%N \x01has set a record of leading \x04%d \x01rounds in a row!", leader, g_Score);
            } else {
                PrintToChatAll(" \x01\x0B\x03%N \x01has stayed at the top for \x04%d \x01rounds in a row!", leader, g_Score);
            }
        } else {
            g_Score = 1;
            PrintToChatAll("The new leader is \x06%N\x01", leader);
        }
    }
    g_LastWinner = leader;

    // Player placement logic for this round
    g_Arenas = 0;
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = Queue_Dequeue(g_hQueue);
        new p2 = Queue_Dequeue(g_hQueue);
        g_ArenaPlayer1[arena] = p1;
        g_ArenaPlayer2[arena] = p2;
        g_roundTypes[arena] = GetRoundType(p1, p2);

        new bool:realp1 = IsValidClient(p1);
        new bool:realp2 = IsValidClient(p2);

        if (realp1) {
            g_isWaiting[p1] = false;
            g_Rankings[p1] = arena;
        }

        if (realp2) {
            g_isWaiting[p2] = false;
            g_Rankings[p2] = arena;
        }

        if (realp1 || realp2) {
            g_Arenas++;
        }
    }

    // clear the queue
    g_numWaitingPlayers = 0;
    while (!Queue_IsEmpty(g_hQueue)) {
        new client = Queue_Dequeue(g_hQueue);
        // TODO: tell the client why they can't get in
        // remark them as waiting
        g_Rankings[client] = -1;
        g_isWaiting[client] = true;
        g_numWaitingPlayers++;
    }
    Queue_Destroy(g_hQueue);
}

/**
 * Player death event, updates g_arenaWinners/g_arenaLosers for the arena that was just decided.
 */
public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new arena = g_Rankings[victim];

    if ((!IsValidClient(attacker) || !IsClientInGame(attacker) || attacker == victim) && arena != -1) {
        new p1 = g_ArenaPlayer1[arena];
        new p2 = g_ArenaPlayer2[arena];

        if (victim == p1) {
            if (IsValidClient(p2)) {
                g_ArenaWinners[arena] = p2;
                g_ArenaLosers[arena] = p1;
            } else {
                g_ArenaWinners[arena] = p1;
                g_ArenaLosers[arena] = -1;
            }
        }

        if (victim == p2) {
            if (IsValidClient(p1)) {
                g_ArenaWinners[arena] = p1;
                g_ArenaLosers[arena] = p2;
            } else {
                g_ArenaWinners[arena] = p2;
                g_ArenaLosers[arena] = -1;
            }
        }

    } else {
        if (arena != -1) {
            g_ArenaWinners[arena] = attacker;
            g_ArenaLosers[arena] = victim;
        }
    }

}

/**
 * Player spawn event - gives the appropriate weapons to a player for his arena.
 * Warning: do NOT assume this is called before or after the round start event!
 */
public Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE)
        return;

    Client_RemoveAllWeapons(client, "", true);

    new arena = g_Rankings[client];
    Assert(arena != -1, "player %N had arena -1 on his spawn", client);
    new RoundType:roundType = (arena == -1) ? RoundType_Rifle : g_roundTypes[arena];

    if (roundType == RoundType_Rifle) {
        if (GivePlayerItem(client, g_primaryWeapon[client]) == -1)
            GivePlayerItem(client, "weapon_ak47");
    } else if (roundType == RoundType_Awp) {
        GivePlayerItem(client, "weapon_awp");
    } else if (roundType == RoundType_Pistol) {
        RemoveVestHelm(client);
    }

    if (GivePlayerItem(client, g_secondaryWeapon[client]) == -1)
        GivePlayerItem(client, "weapon_glock");

    new other = GetOpponent(client);
    if (IsValidClient(other) && g_GiveFlash[client] && g_GiveFlash[other]) {
        GivePlayerItem(client, "weapon_flashbang");
    }

    GivePlayerItem(client, "weapon_knife");

    if (g_LetTimeExpire[client] && g_TotalRounds >= 3) {
        // PrintToChat(client, " \x01\x0B\x04You let time run out last round. You will be punished and get \x031HP \x04this round.");
        // SetEntityHealth(client, 1);
        g_LetTimeExpire[client] = false;
    }

    CreateTimer(0.0, RemoveRadar, client);
}

/**
 * Resets variables for connecting player.
 */
public OnClientConnected(client) {
    ResetClientVariables(client);
}

/**
 * Writes back player stats and resets the player client index data.
 */
public OnClientDisconnect(client) {
    if (GetConVarInt(g_hUseDatabase) != 0)
        DB_WriteRatings(client);

    new arena = g_Rankings[client];
    UpdateArena(arena);
    ResetClientVariables(client);
}

/**
 * Updates client weapon settings according to their cookies.
 */
public OnClientCookiesCached(client) {
    if (IsFakeClient(client))
        return;

    decl String:sCookieValue[WEAPON_LENGTH];
    GetClientCookie(client, g_hSetCookies, sCookieValue, sizeof(sCookieValue));
    if (!StrEqual(sCookieValue, "yes"))
        return;

    GetClientCookie(client, g_hAllowAWPCookie, sCookieValue, sizeof(sCookieValue));
    g_AllowAWP[client] = StrEqual(sCookieValue, "yes") ? true : false;

    GetClientCookie(client, g_hAllowPistolCookie, sCookieValue, sizeof(sCookieValue));
    g_AllowPistol[client] = StrEqual(sCookieValue, "yes") ? true : false;

    GetClientCookie(client, g_hPreferenceCookie, sCookieValue, sizeof(sCookieValue));
    if (StrEqual(sCookieValue, "awp"))
        g_Preference[client] = RoundType_Awp;
    else if (StrEqual(sCookieValue, "pistol"))
        g_Preference[client] = RoundType_Pistol;
    else
        g_Preference[client] = RoundType_Rifle;

    GetClientCookie(client, g_hRifleCookie, sCookieValue, sizeof(sCookieValue));
    strcopy(g_primaryWeapon[client], sizeof(sCookieValue), sCookieValue);

    GetClientCookie(client, g_hPistolCookie, sCookieValue, sizeof(sCookieValue));
    strcopy(g_secondaryWeapon[client], sizeof(sCookieValue), sCookieValue);

    GetClientCookie(client, g_hFlashCookie, sCookieValue, sizeof(sCookieValue));
    g_GiveFlash[client] = StrEqual(sCookieValue, "yes");
}



/***********************
 *                     *
 *    Command Hooks    *
 *                     *
 ***********************/

/**
 * teamjoin hook - marks a player as waiting or moves them to spec if appropriate.
 */
public Action:OnJoinTeamCommand(client, const String:command[], argc) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    decl String:arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    new team_to = StringToInt(arg);
    new team_from = GetClientTeam(client);

    if (IsFakeClient(client) || g_PluginTeamSwitch[client] || team_from == team_to) {
        return Plugin_Continue;
    } else if ((team_from == CS_TEAM_CT && team_to == CS_TEAM_T )
            || (team_from == CS_TEAM_T  && team_to == CS_TEAM_CT)) {
        // ignore changes between T/CT
        return Plugin_Handled;
    } else if (team_to == CS_TEAM_SPECTATOR) {
        // player voluntarily joining spec
        g_SittingOut[client] = true;
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        g_isWaiting[client] = false;
        new arena = g_Rankings[client];
        g_Rankings[client] = -1;
        UpdateArena(arena);
    } else {
        // Player first joining the game, mark them as waiting to join
        AddWaiter(client);
    }
    return Plugin_Handled;
}

public AddWaiter(client) {
    if (!g_isWaiting[client] && IsValidClient(client)) {
        g_SittingOut[client] = false;
        g_isWaiting[client] = true;
        g_Rankings[client] = -1;
        g_numWaitingPlayers++;
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
    }
}

/**
 * Hook for player chat actions, gives player the guns menu.
 */
public Action:Command_Say(client, const String:command[], argc) {
    decl String:text[192];
    if (GetCmdArgString(text, sizeof(text)) < 1)
        return Plugin_Continue;

    StripQuotes(text);

    new String:gunsChatCommands[][] = { "gun", "guns", "!guns", "/guns" };

    for (new i = 0; i < 4; i++) {
        if (strcmp(text[0], gunsChatCommands[i], false) == 0) {
            GiveWeaponMenu(client);
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}



/***********************
 *                     *
 *  Generic Functions  *
 *                     *
 ***********************/

/**
 *
 */
public GetOpponent(client) {
    new arena = g_Rankings[client];
    new other = -1;
    if (client != -1 && arena != -1) {
        other = g_ArenaPlayer1[arena];
        if (other == client)
            other = g_ArenaPlayer2[arena];
    }
    return other;
}

/**
 *
 */
public RemoveVestHelm(client) {
    if (!IsValidClient(client))
        return;

    // remove helmet
    new g_iPlayers_HelmetOffset = FindSendPropOffs("CCSPlayer", "m_bHasHelmet");
    SetEntData(client, g_iPlayers_HelmetOffset, 0);

    // remove kevlar if needed
    new String:kevlarAllowed[][] = {
        "weapon_glock",
        "weapon_hkp2000",
        "weapon_usp_silencer"
    };

    new bool:removeKevlar = true;
    for (new i = 0; i < 3; i++) {
        if (StrEqual(g_secondaryWeapon[client], kevlarAllowed[i])) {
            removeKevlar = false;
            break;
        }
    }

    if (removeKevlar) {
        Client_SetArmor(client, 0);
    }
}

/**
 * Timer for checking round end conditions, since rounds typically won't end naturally.
 */
public Action:Timer_CheckRoundComplete(Handle:timer) {
    // This is a check in case the round ended naturally, we won't force another end
    if (g_RoundFinished)
        return Plugin_Stop;

    // check every arena, if it is still ongoing mark AllDone as false
    new nPlayers = 0;
    new bool:AllDone = true;
    for (new arena = 1; arena <= g_maxArenas; arena++) {

        new any:p1 = g_ArenaPlayer1[arena];
        new any:p2 = g_ArenaPlayer2[arena];
        new bool:hasp1 = IsValidClient(p1) && IsOnTeam(p1);
        new bool:hasp2 = IsValidClient(p2) && IsOnTeam(p2);

        if (hasp1)
            nPlayers++;
        if (hasp2)
            nPlayers++;

        // If we don't have 2 players, mark the lone one as winner
        if (!hasp1)
            g_ArenaWinners[arena] = p2;
        if (!hasp2)
            g_ArenaWinners[arena] = p1;

        // sanity checks -> if there are 2 players and only 1 is alive we must have a winner/loser
        if (hasp1 && hasp2 && IsPlayerAlive(p1) && !IsPlayerAlive(p2)) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
        }
        if (hasp1 && hasp2 && !IsPlayerAlive(p1) && IsPlayerAlive(p2)) {
            g_ArenaWinners[arena] = p2;
            g_ArenaLosers[arena] = p1;
        }

        // this arena has 2 players and hasn't been decided yet
        if (g_ArenaWinners[arena] == -1 && hasp1 && hasp2) {
            AllDone = false;
            break;
        }
    }

    new bool:NormalFinish = AllDone && nPlayers >= 2;
    new bool:WaitingPlayers = nPlayers < 2 && g_numWaitingPlayers > 0;  // so the round ends for the first players that join

    // check if there are enough arenas, otherwise round will constantly end
    if (NormalFinish || WaitingPlayers) {
        // TODO: try putting a mp_restartgame 1 or something like that here
        CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/**
 *
 */
public AddPlayer(client) {
    if (IsValidClient(client) && !g_SittingOut[client] && !IsFakeClient(client)) {

        // if (GetClientTeam(client) == CS_TEAM_SPECTATOR && !g_isWaiting[client]) {
        //  PrintToChatAll("NOT add player %N", client);
        //  // moved to spectator without the player selecting it, e.g. moved by an afk manager
        //  return;
        // }

        Queue_Enqueue(g_hQueue, client);
    }
}

/**
 * Resets all client variables to their default.
 */
public ResetClientVariables(client) {
    if (g_isWaiting[client])
        g_numWaitingPlayers--;
    g_playerIDs[client] = 0;
    g_ratings[client] = 0.0;
    g_pistolRatings[client] = 0.0;
    g_awpRatings[client] = 0.0;
    g_rifleRatings[client] = 0.0;
    g_Rankings[client] = -1;
    g_LetTimeExpire[client] = false;
    g_SittingOut[client] = false;
    g_isWaiting[client] = false;
    g_AllowAWP[client] = false;
    g_AllowPistol[client] = false;
    g_GiveFlash[client] = false;
    g_Preference[client] = RoundType_Rifle;
    g_primaryWeapon[client] = "weapon_ak47";
    g_secondaryWeapon[client] = "weapon_glock";
    g_RoundsLeader[client] = 0;
}

/**
 * Updates an arena in case a player disconnects.
 * Checks if we should assign a winner/loser and informs the player they no longer have an opponent.
 */
public UpdateArena(arena) {
    if (arena != -1) {
        new p1 = g_ArenaPlayer1[arena];
        new p2 = g_ArenaPlayer2[arena];
        new hasp1 = IsValidClient(p1) && IsOnTeam(p1);
        new hasp2 = IsValidClient(p2) && IsOnTeam(p2);

        if (hasp1 && !hasp2) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
            PrintToChat(p1, " \x01\x0B\x03Your opponent left!");
        } else if (hasp2 && !hasp1) {
            g_ArenaWinners[arena] = p2;
            g_ArenaLosers[arena] = p1;
            PrintToChat(p2, " \x01\x0B\x03Your opponent left!");
        }
    }
}

/**
 * Switches a client to a new team.
 */
SwitchPlayerTeam(client, team) {
    new previousTeam = GetClientTeam(client);
    if (previousTeam == team)
        return;

    g_PluginTeamSwitch[client] = true;
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
    } else {
        ChangeClientTeam(client, team);
    }
    g_PluginTeamSwitch[client] = false;
}

/**
 * Returns if a player is on an active/player team.
 */
bool:IsOnTeam(client) {
    new client_team = GetClientTeam(client);
    return (client_team == CS_TEAM_CT) || (client_team == CS_TEAM_T);
}

/**
 * Generic assertion function. Change the ASSERT_FUNCTION if you want.
 */
public Assert(bool:value, const String:msg[] , any:...) {
    if (!value) {
        VFormat(assertBuffer, sizeof(assertBuffer), msg, 3);
        ASSERT_MODE (assertBuffer);
    }
}

/**
 * Removes the radar element from a client's HUD.
 */
public Action:RemoveRadar(Handle:timer, any:client) {
    if (IsValidClient(client) && !IsFakeClient(client)) {
        new flags = GetEntProp(client, Prop_Send, "m_iHideHUD");
        SetEntProp(client, Prop_Send, "m_iHideHUD", flags | (HIDE_RADAR_BIT));
    }
}

/**
 * Function to identify if a client is valid and in game.
 */
bool:IsValidClient(client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

/**
 * Closes an adt array.
 */
CloseHandleArray(Handle:array) {
    new iSize = GetArraySize(array);
    new Handle:hZone;
    for (new i = 0 ; i < iSize; i++) {
        hZone = GetArrayCell(array, i);
        CloseHandle(hZone);
    }
}
