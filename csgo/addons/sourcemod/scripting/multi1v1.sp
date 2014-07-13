#define PLUGIN_VERSION "0.5.0"
#define UPDATE_URL "https://dl.dropboxusercontent.com/u/76035852/multi1v1-v0.5.x/csgo-multi-1v1.txt"
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <smlib>

#undef REQUIRE_PLUGIN
#include <updater>



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

/** ConVar handles **/
new Handle:g_hVerboseSpawnModes = INVALID_HANDLE;
new Handle:g_hRoundTime = INVALID_HANDLE;
new Handle:g_hBlockRadio = INVALID_HANDLE;
new Handle:g_hUseDataBase = INVALID_HANDLE;
new Handle:g_hStatsWebsite = INVALID_HANDLE;
new Handle:g_hAutoUpdate = INVALID_HANDLE;
new Handle:g_hRecordTimes = INVALID_HANDLE;
new Handle:g_hVersion = INVALID_HANDLE;

/** Saved data for database interaction - be careful when using these, they may not
  *  be fetched, check multi1v1/stats.sp for a function that checks that instead of
  *  using one of these directly.
  */
new any:g_roundsPlayed[MAXPLAYERS+1];
new Float:g_ratings[MAXPLAYERS+1];
new String:g_sqlBuffer[1024];

/** Database interactions **/
new bool:g_dbConnected = false;
new Handle:db = INVALID_HANDLE;

/** Client arrays **/
new g_Rankings[MAXPLAYERS+1] = -1;      // which arena each player is in
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false;  // Flags the teamswitches as being done by the plugin
new bool:g_AllowAWP[MAXPLAYERS+1];
new bool:g_AllowPistol[MAXPLAYERS+1];
new bool:g_GiveFlash[MAXPLAYERS+1];
new RoundType:g_Preference[MAXPLAYERS+1];
new String:g_PrimaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
new String:g_SecondaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];

/** Arena arrays **/
new bool:g_ArenaStatsUpdated[MAXPLAYERS+1] = false;
new g_ArenaPlayer1[MAXPLAYERS+1] = -1;  // who is player 1 in each arena
new g_ArenaPlayer2[MAXPLAYERS+1] = -1;  // who is player 2 in each arena
new g_ArenaWinners[MAXPLAYERS+1] = -1;  // who won each arena
new g_ArenaLosers[MAXPLAYERS+1] = -1;   // who lost each arena
new RoundType:g_roundTypes[MAXPLAYERS+1];
new bool:g_LetTimeExpire[MAXPLAYERS+1] = false;
new any:g_roundsLeader[MAXPLAYERS+1] = 0;

/** Overall global variables **/
new g_maxArenas = 0; // maximum number of arenas the map can support
new g_arenas = 1; // number of active arenas
new g_totalRounds = 0; // rounds played on this map so far
new bool:g_RoundFinished = false;
new Handle:g_RankingQueue = INVALID_HANDLE;
new Handle:g_WaitingQueue = INVALID_HANDLE;

/** The different round types **/
enum RoundType {
    RoundType_NoPreference = -1, // not an actual round type, but a preference-only identifier
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
#include "multi1v1/generic.sp"
#include "multi1v1/queue.sp"
#include "multi1v1/spawns.sp"
#include "multi1v1/stats.sp"
#include "multi1v1/weaponmenu.sp"
#include "multi1v1/radiocommands.sp"



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
    g_hVerboseSpawnModes = CreateConVar("sm_multi1v1_verbose_spawns", "0", "Set to 1 to get info about all spawns the plugin read - useful for map creators testing against the plugin.");
    g_hRoundTime = CreateConVar("sm_multi1v1_roundtime", "30", "Roundtime (in seconds)", _, true, 5.0);
    g_hBlockRadio = CreateConVar("sm_multi1v1_block_radio", "1", "Should the plugin block radio commands from being broadcasted");
    g_hUseDataBase = CreateConVar("sm_multi1v1_use_database", "0", "Should we use a database to store stats and preferences");
    g_hRecordTimes = CreateConVar("sm_multi1v1_record_times", "0", "Should the lastTime field store when players connect?");
    g_hStatsWebsite = CreateConVar("sm_multi1v1_stats_url", "", "URL to send player stats to. For example: http://csgo1v1.splewis.net/redirect_stats/. The accountID is appened to this url for each player.");
    g_hAutoUpdate = CreateConVar("sm_multi1v1_autoupdate", "0", "Should the plugin attempt to use the auto-update plugin?");

    /** Config file **/
    AutoExecConfig(true, "multi1v1", "sourcemod/multi1v1");

    /** Version cvar **/
    g_hVersion = CreateConVar("sm_multi1v1_version", PLUGIN_VERSION, "Current multi1v1 version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hVersion, PLUGIN_VERSION);

    /** Cookies **/
    g_hAllowPistolCookie = RegClientCookie("multi1v1_allowpistol", "Multi-1v1 allow pistol rounds", CookieAccess_Protected);
    g_hAllowAWPCookie = RegClientCookie("multi1v1_allowawp", "Multi-1v1 allow AWP rounds", CookieAccess_Protected);
    g_hPreferenceCookie = RegClientCookie("multi1v1_preference", "Multi-1v1 round-type preference", CookieAccess_Protected);
    g_hRifleCookie = RegClientCookie("multi1v1_rifle", "Multi-1v1 rifle choice", CookieAccess_Protected);
    g_hPistolCookie = RegClientCookie("multi1v1_pistol", "Multi-1v1 pistol choice", CookieAccess_Protected);
    g_hFlashCookie = RegClientCookie("multi1v1_flashbang", "Multi-1v1 allow flashbangs in rounds", CookieAccess_Protected);
    g_hSetCookies = RegClientCookie("multi1v1_setprefs", "Multi-1v1 if prefs are saved", CookieAccess_Protected);

    /** Hooks **/
    HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
    HookEvent("player_connect_full", Event_OnFullConnect);
    HookEvent("player_spawn", Event_OnPlayerSpawn);
    HookEvent("player_death", Event_OnPlayerDeath);
    HookEvent("round_prestart", Event_OnRoundPreStart);
    HookEvent("round_poststart", Event_OnRoundPostStart);
    HookEvent("round_end", Event_OnRoundEnd);
    HookEvent("cs_win_panel_match", Event_MatchOver);

    /** Commands **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");
    AddCommandListener(Command_TeamJoin, "jointeam");
    AddRadioCommandListeners();
    RegConsoleCmd("sm_stats", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rank", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rating", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_guns", Command_Guns, "Displays gun/round selection menu");

    if (GetConVarInt(g_hAutoUpdate) != 0 && LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnLibraryAdded(const String:name[]) {
    if (GetConVarInt(g_hAutoUpdate) != 0 && LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnMapStart() {
    if (!g_dbConnected && GetConVarInt(g_hUseDataBase) != 0) {
        DB_Connect();
    }
    Spawns_MapStart();
    g_arenas = 1;
    g_totalRounds = 0;
    g_RoundFinished = false;
    for (new i = 0; i <= MAXPLAYERS; i++) {
        g_ArenaPlayer1[i] = -1;
        g_ArenaPlayer2[i] = -1;
        g_ArenaWinners[i] = -1;
        g_ArenaLosers[i] = -1;
    }
    g_WaitingQueue = Queue_Init();
    ServerCommand("exec gamemode_competitive.cfg");
    ServerCommand("exec sourcemod/multi1v1/game_cvars.cfg");
}

public OnMapEnd() {
    Spawns_MapEnd();
    Queue_Destroy(g_WaitingQueue);
}

public OnClientPostAdminCheck(client) {
    if (IsClientInGame(client) && !IsFakeClient(client) && GetConVarInt(g_hUseDataBase) != 0 && g_dbConnected) {
        DB_AddPlayer(client);
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
 * Round pre-start, sets up who goes in which arena for this round.
 */
public Event_OnRoundPreStart(Handle:event, const String:name[], bool:dontBroadcast) {
    // Here we add each player to the queue in their new ranking
    g_RankingQueue = Queue_Init();

    //  top arena
    AddPlayer(g_ArenaWinners[1]);
    AddPlayer(g_ArenaWinners[2]);

    // middle arenas
    for (new i = 2; i <= g_arenas - 1; i++) {
        AddPlayer(g_ArenaLosers[i - 1]);
        AddPlayer(g_ArenaWinners[i + 1]);
    }

    // bottom arena
    if (g_arenas >= 1) {
        AddPlayer(g_ArenaLosers[g_arenas - 1]);
        AddPlayer(g_ArenaLosers[g_arenas]);
    }

    while (Queue_Length(g_RankingQueue) < 2*g_maxArenas && Queue_Length(g_WaitingQueue) > 0) {
        new client = Queue_Dequeue(g_WaitingQueue);
        AddPlayer(client);
    }

    for (new i = 0; i < Queue_Length(g_WaitingQueue); i++) {
        new client = GetArrayCell(g_WaitingQueue, i);
        PrintToChat(client, " Sorry, all the arenas are currently \x03full.");
        PrintToChat(client, " You are in position \x04%d \x01in the waiting queue", i+1);
    }

    new leader = Queue_Peek(g_RankingQueue);
    if (IsValidClient(leader))
        g_roundsLeader[leader]++;

    // Player placement logic for this round
    g_arenas = 0;
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = Queue_Dequeue(g_RankingQueue);
        new p2 = Queue_Dequeue(g_RankingQueue);
        g_ArenaPlayer1[arena] = p1;
        g_ArenaPlayer2[arena] = p2;
        g_roundTypes[arena] = GetRoundType(p1, p2);

        new bool:realp1 = IsValidClient(p1);
        new bool:realp2 = IsValidClient(p2);

        if (realp1) {
            g_Rankings[p1] = arena;
        }

        if (realp2) {
            g_Rankings[p2] = arena;
        }

        if (realp1 || realp2) {
            g_arenas++;
        }
    }

    Queue_Destroy(g_RankingQueue);
}

/**
 * Round poststart - puts players in their arena and gives them weapons.
 */
public Event_OnRoundPostStart(Handle:event, const String:name[], bool:dontBroadcast) {
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
        g_ArenaStatsUpdated[i] = false;
        g_LetTimeExpire[i] = false;
    }

    GameRules_SetProp("m_iRoundTime", GetConVarInt(g_hRoundTime), 4, 0, true);

    // Fetch all the ratings
    // it can be expensive, so we try to get them all during freeze time where it isn't much of an issue
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i) && g_ratings[i] < MIN_RATING) {
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

    new team = onCT ? CS_TEAM_CT : CS_TEAM_T;
    SwitchPlayerTeam(client, team);
    GetSpawn(arena, team, spawn, angles);

    CS_RespawnPlayer(client);
    TeleportEntity(client, spawn, angles, NULL_VECTOR);

    new score = 0;
    // Arbitrary scores for ordering players in the scoreboard
    if (g_ArenaPlayer1[arena] == client)
        score = 3*g_arenas - 3*arena + 1;
    else
        score = 3*g_arenas - 3*arena;

    CS_SetClientContributionScore(client, score);

    // Set clan tags to the arena number
    decl String:buffer[32];
    Format(buffer, sizeof(buffer), "Arena %d", arena);
    CS_SetClientClanTag(client, buffer);
    CS_SetMVPCount(client, g_roundsLeader[client]);

    if (IsValidClient(other)) {
        PrintToChat(client, " You are in arena \x04%d\x01, facing off against \x03%N", arena, other);
    } else {
        PrintToChat(client, " You are in arena \x04%d\x01 with \x07no opponent", arena);
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
    g_totalRounds++;
    g_RoundFinished = true;

    // If time ran out and we have no winners/losers, set them
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = g_ArenaPlayer1[arena];
        new p2 = g_ArenaPlayer2[arena];
        if (g_ArenaWinners[arena] == -1) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
            if (IsValidClient(p1) && !IsFakeClient(p1) && IsValidClient(p2) && !IsFakeClient(p2) && IsOnTeam(p1) && IsOnTeam(p2)) {
                g_LetTimeExpire[p1] = true;
                g_LetTimeExpire[p2] = true;
            }
        }
        new winner = g_ArenaWinners[arena];
        new loser = g_ArenaLosers[arena];
        if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {

            // also skip the update if we already did it (a player got a kill earlier in the round)
            if (winner != loser && GetConVarInt(g_hUseDataBase) != 0 && !g_ArenaStatsUpdated[arena]) {
                DB_RoundUpdate(winner, loser, g_LetTimeExpire[winner]);
                g_ArenaStatsUpdated[arena] = true;
            }
        }

    }
}

/**
 * Player death event, updates g_arenaWinners/g_arenaLosers for the arena that was just decided.
 */
public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new arena = g_Rankings[victim];

    if (!IsValidClient(attacker) || !IsClientInGame(attacker) || attacker == victim) {
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

    } else if (!g_ArenaStatsUpdated[arena]) {
        g_ArenaWinners[arena] = attacker;
        g_ArenaLosers[arena] = victim;
        g_ArenaStatsUpdated[arena] = true;
        DB_RoundUpdate(attacker, victim, false);
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
        if (GivePlayerItem(client, g_PrimaryWeapon[client]) == -1)
            GivePlayerItem(client, "weapon_ak47");
    } else if (roundType == RoundType_Awp) {
        GivePlayerItem(client, "weapon_awp");
    } else if (roundType == RoundType_Pistol) {
        RemoveVestHelm(client);
    }

    if (GivePlayerItem(client, g_SecondaryWeapon[client]) == -1)
        GivePlayerItem(client, "weapon_glock");

    new other = GetOpponent(client);
    if (IsValidClient(other) && g_GiveFlash[client] && g_GiveFlash[other]) {
        GivePlayerItem(client, "weapon_flashbang");
    }

    GivePlayerItem(client, "weapon_knife");

    CreateTimer(0.0, RemoveRadar, client);
}

public Event_MatchOver(Handle:event, const String:name[], bool:dontBroadcast) {
    new maxClient = -1;
    new maxScore = -1;
    for (new i = 1; i <= MaxClients; i++) {
        new score = g_roundsLeader[i];
        if (maxClient == -1 || score > maxScore) {
            maxClient = i;
            maxScore = score;
        }
    }

    if (IsValidClient(maxClient))
        PrintToChatAll(" \x04%N \x01had the most wins \x03(%d) \x01in arena 1 this map", maxClient, maxScore);
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
    if (GetConVarInt(g_hUseDataBase) != 0)
        DB_WriteRatings(client);

    Queue_Drop(g_WaitingQueue, client);
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
    UpdatePreferencesOnCookies(client);
}



/***********************
 *                     *
 *    Command Hooks    *
 *                     *
 ***********************/

/**
 * teamjoin hook - marks a player as waiting or moves them to spec if appropriate.
 */
public Action:Command_TeamJoin(client, const String:command[], argc) {
    if (!IsValidClient(client))
        return Plugin_Handled;


    decl String:arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    new team_to = StringToInt(arg);
    new team_from = GetClientTeam(client);

    // Note that if a player selects auto-select they will have team_to and team_from equal to CS_TEAM_NONE but will get auto-moved
    if (IsFakeClient(client) || g_PluginTeamSwitch[client] || (team_from == team_to && team_from != CS_TEAM_NONE)) {
        return Plugin_Continue;
    } else if ((team_from == CS_TEAM_CT && team_to == CS_TEAM_T )
            || (team_from == CS_TEAM_T  && team_to == CS_TEAM_CT)) {
        // ignore changes between T/CT
        return Plugin_Handled;
    } else if (team_to == CS_TEAM_SPECTATOR) {
        // player voluntarily joining spec
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        CS_SetClientClanTag(client, "");
        new arena = g_Rankings[client];
        g_Rankings[client] = -1;
        UpdateArena(arena);
    } else {
        // Player first joining the game, mark them as waiting to join
        JoinGame(client);
    }
    return Plugin_Handled;
}

public JoinGame(client) {
    if (IsValidClient(client)) {
        Queue_Enqueue(g_WaitingQueue, client);
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
    }
}

/** sm_stats command **/
public Action:Command_Stats(client, args) {
    new String:arg1[32];
    if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
        new target = FindTarget(client, arg1, true, false);
        if (target != -1) {
            ShowStatsForPlayer(client, target);
        }
    } else {
        ShowStatsForPlayer(client, client);
    }

    return Plugin_Handled;
}

/**
 * Hook for player chat actions, gives player the guns menu.
 */
public Action:Command_Say(client, const String:command[], argc) {
    decl String:text[192];
    if (GetCmdArgString(text, sizeof(text)) < 1)
        return Plugin_Continue;

    StripQuotes(text);

    new String:gunsChatCommands[][] = { "gun", "guns", ".guns", ".setup"};

    for (new i = 0; i < 4; i++) {
        if (strcmp(text[0], gunsChatCommands[i], false) == 0) {
            Command_Guns(client, 0);
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

/** sm_guns command **/
public Action:Command_Guns(client, args) {
    GiveWeaponMenu(client);
}



/*************************
 *                       *
 * Generic 1v1-Functions *
 *                       *
 *************************/

/**
 * Tries to get the player's opponent in their arena.
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
 * Removes helmet and kevlar if the client has an upgraded pistol.
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
        if (StrEqual(g_SecondaryWeapon[client], kevlarAllowed[i])) {
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
    new bool:WaitingPlayers = nPlayers < 2 && Queue_Length(g_WaitingQueue) > 0;  // so the round ends for the first players that join

    if (NormalFinish || WaitingPlayers) {
        CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/**
 * Function to add a player to the ranking queue with some validity checks.
 */
public AddPlayer(client) {
    new bool:valid = IsValidClient(client) && !IsFakeClient(client);
    new bool:space = Queue_Length(g_RankingQueue) < 2 *g_maxArenas;
    new bool:alreadyin = Queue_Inside(g_RankingQueue, client);
    if (valid && space && !alreadyin) {
        Queue_Enqueue(g_RankingQueue, client);
    }
}

/**
 * Resets all client variables to their default.
 */
public ResetClientVariables(client) {
    g_roundsPlayed[client] = 0;
    g_roundsLeader[client] = 0;
    g_ratings[client] = 0.0;
    g_Rankings[client] = -1;
    g_LetTimeExpire[client] = false;
    g_AllowAWP[client] = false;
    g_AllowPistol[client] = false;
    g_GiveFlash[client] = false;
    g_Preference[client] = RoundType_Rifle;
    g_PrimaryWeapon[client] = "weapon_ak47";
    g_SecondaryWeapon[client] = "weapon_glock";
}

/**
 * Updates an arena in case a player disconnects or leaves.
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
            if (!g_ArenaStatsUpdated[arena])
                DB_RoundUpdate(p1, p2, false);
            g_ArenaLosers[arena] = -1;
            g_ArenaPlayer2[arena] = -1;
            g_ArenaStatsUpdated[arena] = true;
            PrintToChat(p1, " \x04Your opponent left!");
        } else if (hasp2 && !hasp1) {
            g_ArenaWinners[arena] = p2;
            if (!g_ArenaStatsUpdated[arena])
                DB_RoundUpdate(p1, p2, false);
            g_ArenaLosers[arena] = -1;
            g_ArenaPlayer1[arena] = -1;
            g_ArenaStatsUpdated[arena] = true;
            PrintToChat(p2, " \x04Your opponent left!");
        }
    }
}

public any:ReportWeight(client, victim) {
    new weight = 0;
    #define WEIGHT(%1) if (%1) weight++

    WEIGHT(g_ratings[client] > 1700.0);
    WEIGHT(g_ratings[client] > 1800.0);
    WEIGHT(g_ratings[client] > 1900.0);
    WEIGHT(g_ratings[victim] > 1750.0);
    WEIGHT(g_ratings[victim] > 2000.0);
    WEIGHT(g_Rankings[victim] <= 2);
    WEIGHT(g_roundsPlayed[victim] < 500);
    WEIGHT(g_roundsPlayed[client] > 1000);
    WEIGHT(g_roundsPlayed[client] > 3000);
    WEIGHT(g_roundsPlayed[client] > 5000);
    WEIGHT(g_roundsPlayed[client] > 5000);

    return weight;
}
