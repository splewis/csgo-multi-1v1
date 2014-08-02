#define UPDATE_URL "https://dl.dropboxusercontent.com/u/76035852/multi1v1-v1.x/csgo-multi-1v1.txt"
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

#define WEAPON_LENGTH 32
#define K_FACTOR 8.0
#define DISTRIBUTION_SPREAD 1000.0
#define DEFAULT_RATING 1500.0
#define TABLE_NAME "multi1v1_stats"

/** ConVar handles **/
new Handle:g_hAutoUpdate = INVALID_HANDLE;
new Handle:g_hBlockRadio = INVALID_HANDLE;
new Handle:g_hDatabaseName = INVALID_HANDLE;
new Handle:g_hGunsMenuOnFirstConnct = INVALID_HANDLE;
new Handle:g_hRoundTime = INVALID_HANDLE;
new Handle:g_hStatsWebsite = INVALID_HANDLE;
new Handle:g_hUseDataBase = INVALID_HANDLE;
new Handle:g_hVerboseSpawnModes = INVALID_HANDLE;
new Handle:g_hVersion = INVALID_HANDLE;

/** Saved data for database interaction - be careful when using these, they may not
 *  be fetched, check multi1v1/stats.sp for a function that checks that instead of
 *  using one of these directly.
 */
new bool:g_FetchedPlayerInfo[MAXPLAYERS+1];
new any:g_Wins[MAXPLAYERS+1];
new any:g_Losses[MAXPLAYERS+1];
new Float:g_Rating[MAXPLAYERS+1];

/** Database interactions **/
new bool:g_dbConnected = false;
new Handle:db = INVALID_HANDLE;

/** Client arrays **/
new g_Ranking[MAXPLAYERS+1] = -1;      // which arena each player is in
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false;  // Flags the teamswitches as being done by the plugin
new bool:g_AllowAWP[MAXPLAYERS+1];
new bool:g_AllowPistol[MAXPLAYERS+1];
new bool:g_GiveFlash[MAXPLAYERS+1];
new bool:g_GunsSelected[MAXPLAYERS+1];
new RoundType:g_Preference[MAXPLAYERS+1];
new String:g_PrimaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
new String:g_SecondaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
new bool:g_BlockStatChanges[MAXPLAYERS+1];
new bool:g_BlockChatMessages[MAXPLAYERS+1];

/** Arena arrays **/
new bool:g_ArenaStatsUpdated[MAXPLAYERS+1] = false;
new g_ArenaPlayer1[MAXPLAYERS+1] = -1;  // who is player 1 in each arena
new g_ArenaPlayer2[MAXPLAYERS+1] = -1;  // who is player 2 in each arena
new g_ArenaWinners[MAXPLAYERS+1] = -1;  // who won each arena
new g_ArenaLosers[MAXPLAYERS+1] = -1;   // who lost each arena
new RoundType:g_roundTypes[MAXPLAYERS+1];
new bool:g_LetTimeExpire[MAXPLAYERS+1] = false;
new any:g_RoundsLeader[MAXPLAYERS+1] = 0;

/** Overall global variables **/
new g_arenaOffsetValue = 0;
new g_roundStartTime = 0;
new g_maxArenas = 0; // maximum number of arenas the map can support
new g_arenas = 1; // number of active arenas
new g_totalRounds = 0; // rounds played on this map so far
new bool:g_roundFinished = false;
new Handle:g_rankingQueue = INVALID_HANDLE;
new Handle:g_waitingQueue = INVALID_HANDLE;

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

/** Fowards **/
new Handle:g_hOnPreArenaRankingsSet = INVALID_HANDLE;
new Handle:g_hOnPostArenaRankingsSet = INVALID_HANDLE;
new Handle:g_hAfterPlayerSpawn = INVALID_HANDLE;
new Handle:g_hOnRoundWon = INVALID_HANDLE;

/** Constant offsets values **/
new g_iPlayers_HelmetOffset;

/** multi1v1 function includes **/
#include "include/multi1v1.inc"
#include "multi1v1/generic.sp"
#include "multi1v1/natives.sp"
#include "multi1v1/queue.sp"
#include "multi1v1/radiocommands.sp"
#include "multi1v1/spawns.sp"
#include "multi1v1/stats.sp"
#include "multi1v1/weaponmenu.sp"




/***********************
 *                     *
 * Sourcemod functions *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "[Multi1v1] Base plugin",
    author = "splewis",
    description = "Multi-arena 1v1 laddering",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    /** ConVars **/
    g_hDatabaseName = CreateConVar("sm_multi1v1_db_name", "multi1v1", "Name of the database configuration in configs/databases.cfg to use.");
    g_hVerboseSpawnModes = CreateConVar("sm_multi1v1_verbose_spawns", "0", "Set to 1 to get info about all spawns the plugin read - useful for map creators testing against the plugin.");
    g_hRoundTime = CreateConVar("sm_multi1v1_roundtime", "30", "Roundtime (in seconds)", _, true, 5.0);
    g_hBlockRadio = CreateConVar("sm_multi1v1_block_radio", "1", "Should the plugin block radio commands from being broadcasted");
    g_hUseDataBase = CreateConVar("sm_multi1v1_use_database", "0", "Should we use a database to store stats and preferences");
    g_hAutoUpdate = CreateConVar("sm_multi1v1_autoupdate", "0", "Should the plugin attempt to use the auto-update plugin?");
    g_hStatsWebsite = CreateConVar("sm_multi1v1_stats_url", "", "URL to send player stats to. For example: http://csgo1v1.splewis.net/redirect_stats/. The accountID is appened to this url for each player.");
    g_hGunsMenuOnFirstConnct = CreateConVar("sm_multi1v1_guns_menu_first_connect", "0", "Should players see the guns menu automatically on their first connect?");

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

    /** Commands **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");
    AddCommandListener(Command_TeamJoin, "jointeam");
    AddRadioCommandListeners();
    RegConsoleCmd("sm_guns", Command_Guns, "Displays gun/round selection menu");
    RegConsoleCmd("sm_stats", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rank", Command_Stats, "Displays a players multi-1v1 stats");
    RegConsoleCmd("sm_rating", Command_Stats, "Displays a players multi-1v1 stats");

    /** Fowards **/
    g_hOnPreArenaRankingsSet = CreateGlobalForward("OnPreArenaRankingsSet", ET_Ignore, Param_Cell);
    g_hOnPostArenaRankingsSet = CreateGlobalForward("OnPostArenaRankingsSet", ET_Ignore, Param_Cell);
    g_hAfterPlayerSpawn = CreateGlobalForward("AfterPlayerSpawn", ET_Ignore, Param_Cell);
    g_hOnRoundWon = CreateGlobalForward("OnRoundWon", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    /** Compute any constant offsets **/
    g_iPlayers_HelmetOffset = FindSendPropOffs("CCSPlayer", "m_bHasHelmet");

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
    Spawns_MapStart();
    g_waitingQueue = Queue_Init();
    if (!g_dbConnected && GetConVarInt(g_hUseDataBase) != 0) {
        DB_Connect();
    }

    g_arenaOffsetValue = 0;
    g_arenas = 1;
    g_totalRounds = 0;
    g_roundFinished = false;
    for (new i = 0; i <= MAXPLAYERS; i++) {
        g_ArenaPlayer1[i] = -1;
        g_ArenaPlayer2[i] = -1;
        g_ArenaWinners[i] = -1;
        g_ArenaLosers[i] = -1;
    }
    ServerCommand("exec gamemode_competitive.cfg");
    ServerCommand("exec sourcemod/multi1v1/game_cvars.cfg");
}

public OnMapEnd() {
    Queue_Destroy(g_waitingQueue);
    Spawns_MapEnd();
}

public OnClientPostAdminCheck(client) {
    if (IsPlayer(client) && GetConVarInt(g_hUseDataBase) != 0 && g_dbConnected) {
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
    g_roundStartTime = GetTime();

    // Here we add each player to the queue in their new ranking
    g_rankingQueue = Queue_Init();

    Call_StartForward(g_hOnPreArenaRankingsSet);
    Call_PushCell(g_rankingQueue);
    Call_Finish();

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

    while (Queue_Length(g_rankingQueue) < 2*g_maxArenas && Queue_Length(g_waitingQueue) > 0) {
        new client = Queue_Dequeue(g_waitingQueue);
        AddPlayer(client);
    }

    for (new i = 0; i < Queue_Length(g_waitingQueue); i++) {
        new client = GetArrayCell(g_waitingQueue, i);
        Multi1v1Message(client, "Sorry, all the arenas are currently \x03full.");
        Multi1v1Message(client, "You are in position \x04%d \x01in the waiting queue", i + 1);
    }

    Call_StartForward(g_hOnPostArenaRankingsSet);
    Call_PushCell(g_rankingQueue);
    Call_Finish();

    new leader = Queue_Peek(g_rankingQueue);
    if (IsValidClient(leader) && Queue_Length(g_rankingQueue) >= 2)
        g_RoundsLeader[leader]++;

    // Player placement logic for this round
    g_arenas = 0;
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = Queue_Dequeue(g_rankingQueue);
        new p2 = Queue_Dequeue(g_rankingQueue);
        g_ArenaPlayer1[arena] = p1;
        g_ArenaPlayer2[arena] = p2;
        g_roundTypes[arena] = GetRoundType(p1, p2);

        new bool:realp1 = IsValidClient(p1);
        new bool:realp2 = IsValidClient(p2);

        if (realp1) {
            g_Ranking[p1] = arena;
        }

        if (realp2) {
            g_Ranking[p2] = arena;
        }

        if (realp1 || realp2) {
            g_arenas++;
        }
    }

    Queue_Destroy(g_rankingQueue);
}

/**
 * Function to add a player to the ranking queue with some validity checks.
 */
public AddPlayer(client) {
    new bool:player = IsPlayer(client);
    new bool:space = Queue_Length(g_rankingQueue) < 2 *g_maxArenas;
    new bool:alreadyin = Queue_Inside(g_rankingQueue, client);
    if (player && space && !alreadyin) {
        Queue_Enqueue(g_rankingQueue, client);
    }

    if (GetConVarInt(g_hGunsMenuOnFirstConnct) != 0 && player && !g_GunsSelected[client]) {
        GiveWeaponMenu(client);
    }
}

/**
 * Round poststart - puts players in their arena and gives them weapons.
 */
public Event_OnRoundPostStart(Handle:event, const String:name[], bool:dontBroadcast) {
    g_roundFinished = false;
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

    // round time is bu a special cvar since mp_roundtime has a lower bound of 1 minutes
    GameRules_SetProp("m_iRoundTime", GetConVarInt(g_hRoundTime), 4, 0, true);

    // Fetch all the ratings
    // it can be expensive, so we try to get them all during freeze time where it isn't much of an issue
    if (GetConVarInt(g_hUseDataBase) != 0) {
        if (!g_dbConnected)
            DB_Connect();
        if (g_dbConnected) {
            for (new i = 1; i <= MaxClients; i++) {
                if (IsValidClient(i) && !IsFakeClient(i) && !g_FetchedPlayerInfo[i]) {
                    DB_FetchRatings(i);
                }
            }
        }
    }

    for (new i = 1; i <= MaxClients; i++) {
        if (!IsActivePlayer(i) || g_BlockChatMessages[i])
            continue;

        new other = GetOpponent(i);
        new arena = g_Ranking[i];
        if (IsValidClient(other)) {
            Multi1v1Message(i, "You are in arena \x04%d\x01, facing off against \x03%N", arena - g_arenaOffsetValue, other);
        } else {
            Multi1v1Message(i, "You are in arena \x04%d\x01 with \x07no opponent", arena - g_arenaOffsetValue);
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
    CS_SetMVPCount(client, g_RoundsLeader[client]);
}

/**
 * RoundEnd event, updates the global variables for the next round.
 * Specifically:
 *  - updates ratings for this round
 *  - throws all the players into a queue according to their standing from this round
 *  - updates globals g_Ranking, g_ArenaPlayer1, g_ArenaPlayer2 for the next round setup
 */
public Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
    g_totalRounds++;
    g_roundFinished = true;

    // If time ran out and we have no winners/losers, set them
    for (new arena = 1; arena <= g_maxArenas; arena++) {
        new p1 = g_ArenaPlayer1[arena];
        new p2 = g_ArenaPlayer2[arena];
        if (g_ArenaWinners[arena] == -1) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
            if (IsActivePlayer(p1) && IsActivePlayer(p2)) {
                g_LetTimeExpire[p1] = true;
                g_LetTimeExpire[p2] = true;
            }
        }
        new winner = g_ArenaWinners[arena];
        new loser = g_ArenaLosers[arena];
        if (IsPlayer(winner) && IsPlayer(loser)) {

            // also skip the update if we already did it (a player got a kill earlier in the round)
            if (winner != loser && !g_ArenaStatsUpdated[arena]) {
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
    new arena = g_Ranking[victim];

    if (!IsValidClient(attacker) || attacker == victim) {
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

    new arena = g_Ranking[client];
    if (arena == -1)
        LogError("player %N had arena -1 on his spawn", client);

    new RoundType:roundType = (arena == -1) ? RoundType_Rifle : g_roundTypes[arena];
    GivePlayerArenaWeapons(client, roundType);
    CreateTimer(0.1, RemoveRadar, client);

    Call_StartForward(g_hAfterPlayerSpawn);
    Call_PushCell(client);
    Call_Finish();
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

    Queue_Drop(g_waitingQueue, client);
    new arena = g_Ranking[client];
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
        new arena = g_Ranking[client];
        g_Ranking[client] = -1;
        UpdateArena(arena);
    } else {
        // Player first joining the game, mark them as waiting to join
        JoinGame(client);
    }
    return Plugin_Handled;
}

public JoinGame(client) {
    if (IsValidClient(client)) {
        Queue_Enqueue(g_waitingQueue, client);
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

    new String:gunsChatCommands[][] = { "gun", "guns", ".guns", ".setup", "GUNS", "!GUNS", "!guns" };

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
 * Switches a client to a new team.
 */
public SwitchPlayerTeam(client, team) {
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
 * Removes helmet and kevlar if the client has an upgraded pistol.
 */
public RemoveVestHelm(client) {
    if (!IsValidClient(client))
        return;

    // remove helmet
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
    if (g_roundFinished)
        return Plugin_Stop;

    // check every arena, if it is still ongoing mark allDone as false
    new nPlayers = 0;
    new bool:allDone = true;
    for (new arena = 1; arena <= g_maxArenas; arena++) {

        new any:p1 = g_ArenaPlayer1[arena];
        new any:p2 = g_ArenaPlayer2[arena];
        new bool:hasp1 = IsActivePlayer(p1);
        new bool:hasp2 = IsActivePlayer(p2);

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
            allDone = false;
            break;
        }
    }

    new bool:normalFinish = allDone && nPlayers >= 2;

    // So the round ends for the first players that join
    new bool:waitingPlayers = nPlayers < 2 && Queue_Length(g_waitingQueue) > 0;

    // This check is a sanity check on when the round passes what the round time cvar allowed
    new freezeTimeLength = GetConVarInt(FindConVar("mp_freezetime"));
    new maxRoundLength = GetConVarInt(g_hRoundTime) + freezeTimeLength;
    new elapsedTime =  GetTime() - g_roundStartTime;

    new bool:roundTimeExpired = elapsedTime >= maxRoundLength && nPlayers >= 2;

    if (normalFinish || waitingPlayers || roundTimeExpired) {
        g_roundFinished = true;
        CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/**
 * Resets all client variables to their default.
 */
public ResetClientVariables(client) {
    g_BlockChatMessages[client] = false;
    g_BlockStatChanges[client] = false;
    g_FetchedPlayerInfo[client] = false;
    g_GunsSelected[client] = false;
    g_RoundsLeader[client] = 0;
    g_Wins[client] = 0;
    g_Losses[client] = 0;
    g_Rating[client] = 0.0;
    g_Ranking[client] = -1;
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
        new hasp1 = IsActivePlayer(p1);
        new hasp2 = IsActivePlayer(p2);

        if (hasp1 && !hasp2) {
            g_ArenaWinners[arena] = p1;
            if (!g_ArenaStatsUpdated[arena])
                DB_RoundUpdate(p1, p2, false);
            g_ArenaLosers[arena] = -1;
            g_ArenaPlayer2[arena] = -1;
            g_ArenaStatsUpdated[arena] = true;
        } else if (hasp2 && !hasp1) {
            g_ArenaWinners[arena] = p2;
            if (!g_ArenaStatsUpdated[arena])
                DB_RoundUpdate(p1, p2, false);
            g_ArenaLosers[arena] = -1;
            g_ArenaPlayer1[arena] = -1;
            g_ArenaStatsUpdated[arena] = true;
        }
    }
}
