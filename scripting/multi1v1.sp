#define UPDATE_URL "https://dl.dropboxusercontent.com/u/76035852/multi1v1-v1.x/csgo-multi-1v1.txt"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <smlib>

#include "include/queue.inc"
#include "include/multi1v1.inc"

#undef REQUIRE_PLUGIN
#include "include/updater.inc"

#pragma semicolon 1
#pragma newdecls required


/***********************
 *                     *
 *  Global Variables   *
 *                     *
 ***********************/

#define DISTRIBUTION_SPREAD 1000.0
#define K_FACTOR 8.0
#define MAX_ROUND_TYPES 16
#define MENU_TIME_LENGTH 15
#define ROUND_TYPE_NAME_LENGTH 64
#define TABLE_NAME "multi1v1_stats"
#define WEAPON_LENGTH 32

/** ConVar handles **/
ConVar g_hAutoGunsMenuBehavior;
ConVar g_hAutoUpdate;
ConVar g_hBlockRadio;
ConVar g_hDatabaseName;
ConVar g_hDatabaseServerId;
ConVar g_hDefaultPistol;
ConVar g_hExecDefaultConfig;
ConVar g_hHideGunsChatCommands;
ConVar g_hPistolBehavior;
ConVar g_hPistolMenu;
ConVar g_hPreferenceWeight;
ConVar g_hRifleMenu;
ConVar g_hRoundTime;
ConVar g_hUseChatPrefix;
ConVar g_hUseDatabase;
ConVar g_hUseMVPStars;
ConVar g_hUseTeamTags;
ConVar g_hVerboseSpawnModes;
ConVar g_hVersion;

/** Saved data for database interaction - be careful when using these, they may not
 *  be fetched, check multi1v1/stats.sp for a function that checks that instead of
 *  using one of these directly.
 */
bool g_FetchedPlayerInfo[MAXPLAYERS+1];
int g_Wins[MAXPLAYERS+1];
int g_Losses[MAXPLAYERS+1];
float g_Rating[MAXPLAYERS+1];
float g_RoundTypeRating[MAXPLAYERS+1][MAX_ROUND_TYPES];

/** Database interactions **/
bool g_dbConnected = false;
Handle db = INVALID_HANDLE;

/** Client arrays **/
int g_Ranking[MAXPLAYERS+1]; // which arena each player is in
bool g_LetTimeExpire[MAXPLAYERS+1];
bool g_PluginTeamSwitch[MAXPLAYERS+1];  // Flags the teamswitches as being done by the plugin
bool g_GivenGunsMenu[MAXPLAYERS+1];
bool g_HideStats[MAXPLAYERS+1];

bool g_WaitingOnRoundAllow[MAXPLAYERS+1];
int g_CurrentRoundTypeMenuIndex[MAXPLAYERS+1];

int g_Preference[MAXPLAYERS+1];
char g_PrimaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
char g_SecondaryWeapon[MAXPLAYERS+1][WEAPON_LENGTH];
bool g_BlockStatChanges[MAXPLAYERS+1];
bool g_BlockChatMessages[MAXPLAYERS+1];
bool g_BlockMVPStars[MAXPLAYERS+1];
bool g_BlockArenaDones[MAXPLAYERS+1];

/** Round-type data **/
int g_numRoundTypes = 0;
char g_RoundTypeNames[MAX_ROUND_TYPES][ROUND_TYPE_NAME_LENGTH];
char g_RoundTypeDisplayNames[MAX_ROUND_TYPES][ROUND_TYPE_NAME_LENGTH];
RoundTypeWeaponHandler g_RoundTypeWeaponHandlers[MAX_ROUND_TYPES];
RoundTypeMenuHandler g_RoundTypeMenuHandlers[MAX_ROUND_TYPES];
bool g_RoundTypeRanked[MAX_ROUND_TYPES];
bool g_RoundTypeOptional[MAX_ROUND_TYPES];
bool g_RoundTypeEnabled[MAX_ROUND_TYPES];
char g_RoundTypeFieldNames[MAX_ROUND_TYPES][ROUND_TYPE_NAME_LENGTH];
Handle g_RoundTypeSourcePlugin[MAX_ROUND_TYPES];
bool g_AllowedRoundTypes[MAXPLAYERS+1][MAX_ROUND_TYPES];

/** Arena arrays **/
bool g_ArenaStatsUpdated[MAXPLAYERS+1];
int g_ArenaPlayer1[MAXPLAYERS+1] = -1;  // who is player 1 in each arena
int g_ArenaPlayer2[MAXPLAYERS+1] = -1;  // who is player 2 in each arena
int g_ArenaWinners[MAXPLAYERS+1] = -1;  // who won each arena
int g_ArenaLosers[MAXPLAYERS+1] = -1;   // who lost each arena
int g_roundTypes[MAXPLAYERS+1];         // the round type being used in the arena
int g_RoundsLeader[MAXPLAYERS+1] = 0;

/** Overall global variables **/
int g_arenaOffsetValue = 0;
int g_roundStartTime = 0;
int g_maxArenas = 0; // maximum number of arenas the map can support
int g_arenas = 1; // number of active arenas
int g_totalRounds = 0; // rounds played on this map so far
bool g_roundFinished = false;
Handle g_waitingQueue = INVALID_HANDLE;

/** Handles to arrays of vectors of spawns/angles **/
Handle g_hTSpawns = INVALID_HANDLE;
Handle g_hTAngles = INVALID_HANDLE;
Handle g_hCTSpawns = INVALID_HANDLE;
Handle g_hCTAngles = INVALID_HANDLE;

/** Forwards **/
Handle g_hAfterPlayerSetup = INVALID_HANDLE;
Handle g_hAfterPlayerSpawn = INVALID_HANDLE;
Handle g_hOnArenasReady = INVALID_HANDLE;
Handle g_hOnGunsMenuDone = INVALID_HANDLE;
Handle g_hOnPostArenaRankingsSet = INVALID_HANDLE;
Handle g_hOnPreArenaRankingsSet = INVALID_HANDLE;
Handle g_hOnRoundTypeDecided = INVALID_HANDLE;
Handle g_hOnRoundTypesAdded = INVALID_HANDLE;
Handle g_hOnRoundWon = INVALID_HANDLE;
Handle g_hOnStatsCached = INVALID_HANDLE;

/** multi1v1 function includes **/
#include "multi1v1/generic.sp"
#include "multi1v1/natives.sp"
#include "multi1v1/radiocommands.sp"
#include "multi1v1/roundtypes.sp"
#include "multi1v1/spawns.sp"
#include "multi1v1/stats.sp"
#include "multi1v1/weaponlogic.sp"
#include "multi1v1/version.sp"



/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "CS:GO Multi1v1",
    author = "splewis",
    description = "Multi-arena 1v1 laddering",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-multi-1v1"
};

public void OnPluginStart() {
    LoadTranslations("common.phrases");
    LoadTranslations("multi1v1.phrases");

    /** ConVars **/
    g_hAutoGunsMenuBehavior = CreateConVar("sm_multi1v1_menu_open_behavior", "0", "Determines auto-open behavior of the guns menu. 0=never auto-open, 1=open if the client has no preference cookies saved, 2=always open on client connect");
    g_hAutoUpdate = CreateConVar("sm_multi1v1_autoupdate", "0", "Whether the plugin attempts to auto-update. Requies the \"Updater\" plugin");
    g_hBlockRadio = CreateConVar("sm_multi1v1_block_radio", "1", "Should the plugin block radio commands from being broadcasted");
    g_hDatabaseName = CreateConVar("sm_multi1v1_db_name", "multi1v1", "Name of the database configuration in configs/databases.cfg to use.");
    g_hDatabaseServerId = CreateConVar("sm_multi1v1_database_server_id", "0", "If you are storing database stats, a number to identify this server. Most users don't need to change this.");
    g_hDefaultPistol = CreateConVar("sm_multi1v1_default_pistol", "weapon_p250", "Default pistol to give if sm_multi1v1_pistol_behavior=2");
    g_hExecDefaultConfig = CreateConVar("sm_multi1v1_exec_default_config", "1", "Whether the plugin will exectue gamemode_competitive.cfg before the sourcemod/multi1v1/game_cvars.cfg file.");
    g_hHideGunsChatCommands = CreateConVar("sm_multi1v1_block_guns_chat_commands", "1", "Whether commands like \"guns\" or \"!guns\" will be blocked from showing up in chat.");
    g_hPistolBehavior = CreateConVar("sm_multi1v1_pistol_behavior", "0", "Behavior 0=always give the pistol the player selected, 1=never give pistols on non-pistol rounds, 2=always give sm_multi1v1_default_pistol on non-pistol rounds 3=give pistol choice on rifle/pistol rounds, but use sm_multi1v1_default_pistol on awp rounds");
    g_hPistolMenu = CreateConVar("sm_multi1v1_show_pistol_menu", "1", "Whether the pistol choice menu should be included in the guns menu");
    g_hPreferenceWeight = CreateConVar("sm_multi1v1_preference_weight", "1", "How much weight are given to preferences when round types are being selected. Use a higher number for a preference to be more likely, or 0 to make the preference have no effect");
    g_hRifleMenu = CreateConVar("sm_multi1v1_show_rifle_menu", "1", "Whether the rifle choice menu should be included in the guns menu");
    g_hRoundTime = CreateConVar("sm_multi1v1_roundtime", "30", "Roundtime (in seconds)", _, true, 5.0);
    g_hUseChatPrefix = CreateConVar("sm_multi1v1_use_chat_prefix", "1", "Whether to use a [Multi1v1] tag in chat messages");
    g_hUseDatabase = CreateConVar("sm_multi1v1_use_database", "0", "Whether a database is used to store player statistics");
    g_hUseMVPStars = CreateConVar("sm_multi1v1_use_mvp_stars", "1", "Whether MVP stars are updated to reflect a player's number of rounds in arena 1");
    g_hUseTeamTags = CreateConVar("sm_multi1v1_use_team_tags", "1", "Whether the team (or clan) tag is updated to reflect a player's arena numbers");
    g_hVerboseSpawnModes = CreateConVar("sm_multi1v1_verbose_spawns", "0", "Set to 1 to get info about all spawns the plugin read - useful for map creators testing against the plugin");

    /** Config file **/
    AutoExecConfig(true, "multi1v1", "sourcemod/multi1v1");

    /** Version cvar **/
    g_hVersion = CreateConVar("sm_multi1v1_version", PLUGIN_VERSION, "Current multi1v1 version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hVersion, PLUGIN_VERSION);

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
    AddCommandListener(Command_TeamJoin, "jointeam");
    AddRadioCommandListeners();
    RegConsoleCmd("sm_guns", Command_Guns, "Displays gun/round selection menu");
    RegConsoleCmd("sm_hidestats", Command_Hidestats, "Hides player stats/ratings");

    /** Fowards **/
    g_hAfterPlayerSetup = CreateGlobalForward("Multi1v1_AfterPlayerSetup", ET_Ignore, Param_Cell);
    g_hAfterPlayerSpawn = CreateGlobalForward("Multi1v1_AfterPlayerSpawn", ET_Ignore, Param_Cell);
    g_hOnArenasReady = CreateGlobalForward("Multi1v1_OnArenasReady", ET_Ignore);
    g_hOnGunsMenuDone = CreateGlobalForward("Multi1v1_OnGunsMenuDone", ET_Ignore, Param_Cell);
    g_hOnPostArenaRankingsSet = CreateGlobalForward("Multi1v1_OnPostArenaRankingsSet", ET_Ignore, Param_Cell);
    g_hOnPreArenaRankingsSet = CreateGlobalForward("Multi1v1_OnPreArenaRankingsSet", ET_Ignore, Param_Cell);
    g_hOnRoundTypeDecided = CreateGlobalForward("Multi1v1_OnRoundTypeDecided", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
    g_hOnRoundTypesAdded = CreateGlobalForward("Multi1v1_OnRoundTypesAdded", ET_Ignore);
    g_hOnRoundWon = CreateGlobalForward("Multi1v1_OnRoundWon", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hOnStatsCached = CreateGlobalForward("Multi1v1_OnStatsCached", ET_Ignore, Param_Cell);

    g_waitingQueue = Queue_Init();

    if (g_hAutoUpdate.IntValue != 0) {
        AddUpdater();
    }
}

public void OnLibraryAdded(const char[] name) {
    if (g_hAutoUpdate.IntValue != 0) {
        AddUpdater();
    }
}

static void AddUpdater() {
    if (LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public void OnMapStart() {
    Spawns_MapStart();
    Weapons_MapStart();

    Multi1v1_ClearRoundTypes();
    Multi1v1_AddStandardRounds();
    Call_StartForward(g_hOnRoundTypesAdded);
    Call_Finish();

    Queue_Clear(g_waitingQueue);

    g_arenaOffsetValue = 0;
    g_arenas = 1;
    g_totalRounds = 0;
    g_roundFinished = false;
    for (int i = 0; i <= MAXPLAYERS; i++) {
        g_ArenaPlayer1[i] = -1;
        g_ArenaPlayer2[i] = -1;
        g_ArenaWinners[i] = -1;
        g_ArenaLosers[i] = -1;
    }

    if (g_hExecDefaultConfig.IntValue != 0) {
        ServerCommand("exec gamemode_competitive.cfg");
    }
    ServerCommand("exec sourcemod/multi1v1/game_cvars.cfg");

    if (!g_dbConnected && g_hUseDatabase.IntValue != 0) {
        DB_Connect();
    }
}

public void OnMapEnd() {
    Spawns_MapEnd();
}

public void OnClientAuthorized(int client, const char[] auth) {
    if (!StrEqual(auth, "BOT") && g_hUseDatabase.IntValue != 0 && g_dbConnected) {
        DB_AddPlayer(client);
    }
}

public void OnClientConnected(int client) {
    ResetClientVariables(client);
}

public void OnClientDisconnect(int client) {
    if (g_hUseDatabase.IntValue != 0)
        DB_WriteRatings(client);

    Queue_Drop(g_waitingQueue, client);
    int arena = g_Ranking[client];
    UpdateArena(arena, client);
    ResetClientVariables(client);
}

public int OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;
    UpdatePreferencesOnCookies(client);
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
public Action Event_OnFullConnect(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
}

/**
 * Silences team join/switch events.
 */
public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    dontBroadcast = true;
    return Plugin_Changed;
}

/**
 * Round pre-start, sets up who goes in which arena for this round.
 */
public Action Event_OnRoundPreStart(Handle event, const char[] name, bool dontBroadcast) {
    g_roundStartTime = GetTime();

    // Here we add each player to the queue in their new ranking
    Handle rankingQueue = Queue_Init();

    Call_StartForward(g_hOnPreArenaRankingsSet);
    Call_PushCell(rankingQueue);
    Call_Finish();

    // top arena
    AddPlayer_NoSpec(g_ArenaWinners[1], rankingQueue);
    AddPlayer_NoSpec(g_ArenaWinners[2], rankingQueue);

    // middle arenas
    for (int i = 2; i <= g_arenas - 1; i++) {
        AddPlayer_NoSpec(g_ArenaLosers[i - 1], rankingQueue);
        AddPlayer_NoSpec(g_ArenaWinners[i + 1], rankingQueue);
    }

    // bottom arena
    if (g_arenas >= 1) {
        AddPlayer_NoSpec(g_ArenaLosers[g_arenas - 1], rankingQueue);
        AddPlayer_NoSpec(g_ArenaLosers[g_arenas], rankingQueue);
    }

    // pulls all the spectators out of the waiting queue that can we can add
    Handle playersToAdd = Queue_Init();
    while (Queue_Length(rankingQueue) + Queue_Length(playersToAdd) < 2*g_maxArenas && Queue_Length(g_waitingQueue) > 0) {
        int client = Queue_Dequeue(g_waitingQueue);
        AddPlayer(client, playersToAdd);
    }

    // sorts the spectators to add by rating
    SortADTArrayCustom(playersToAdd, spectatorSortFunction);

    // finally adds the spectators to the ranking queue
    while (Queue_Length(playersToAdd) > 0) {
        int client = Queue_Dequeue(playersToAdd);
        AddPlayer(client, rankingQueue);
    }

    int queueLength = Queue_Length(g_waitingQueue);
    for (int i = 0; i < queueLength; i++) {
        int client = GetArrayCell(g_waitingQueue, i);
        Multi1v1_Message(client, "%t", "ArenasFull");
        Multi1v1_Message(client, "%t", "QueuePosition", i + 1);
    }

    Call_StartForward(g_hOnPostArenaRankingsSet);
    Call_PushCell(rankingQueue);
    Call_Finish();

    int leader = -1;
    for (int i = 0; i < GetArraySize(rankingQueue); i++) {
        int client = GetArrayCell(rankingQueue, i);
        if (!g_BlockMVPStars[client]) {
            leader = client;
            break;
        }
    }

    if (IsValidClient(leader) && Queue_Length(rankingQueue) >= 2 && !g_LetTimeExpire[leader]) {
        g_RoundsLeader[leader]++;
    }

    // Player placement logic for this round
    g_arenas = 0;
    for (int arena = 1; arena <= g_maxArenas; arena++) {
        int p1 = Queue_Dequeue(rankingQueue);
        int p2 = Queue_Dequeue(rankingQueue);
        g_ArenaPlayer1[arena] = p1;
        g_ArenaPlayer2[arena] = p2;
        g_roundTypes[arena] = GetRoundType(arena, p1, p2);


        bool realp1 = IsValidClient(p1);
        bool realp2 = IsValidClient(p2);

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

    Queue_Destroy(rankingQueue);

    Call_StartForward(g_hOnArenasReady);
    Call_Finish();
}

public int spectatorSortFunction(int index1, int index2, Handle array, Handle hndl) {
    int client1 = GetArrayCell(array, index1);
    int client2 = GetArrayCell(array, index2);
    if (Multi1v1_HasStats(client1) && Multi1v1_HasStats(client2)) {
        return RoundToNearest(Multi1v1_GetRating(client2) - Multi1v1_GetRating(client1));
    } else {
        return client1 - client2;
    }
}

/**
 * Wrapper on the geneic AddPlayer function that doesn't allow spectators not in
 * the waiting queue to join. This is meant to deal with players being moved to spectator
 * by another plugin (e.g. afk managers).
 */
public void AddPlayer_NoSpec(int client, Handle rankingQueue) {
    if (!IsPlayer(client)) {
        return;
    }

    if (GetClientTeam(client) != CS_TEAM_SPECTATOR || Multi1v1_IsInWaitingQueue(client)) {
        AddPlayer(client, rankingQueue);
    }
}

/**
 * Function to add a player to the ranking queue with some validity checks.
 */
public void AddPlayer(int client, Handle rankingQueue) {
    if (!IsPlayer(client)) {
        return;
    }

    bool space = Queue_Length(rankingQueue) < 2 *g_maxArenas;
    bool alreadyin = Queue_Inside(rankingQueue, client);

    if (space && !alreadyin) {
        Queue_Enqueue(rankingQueue, client);
    }
}

/**
 * Round poststart - puts players in their arena and gives them weapons.
 */
public Action Event_OnRoundPostStart(Handle event, const char[] name, bool dontBroadcast) {
    g_roundFinished = false;
    for (int arena = 1; arena <= g_maxArenas; arena++) {
        g_ArenaWinners[arena] = -1;
        g_ArenaLosers[arena] = -1;
        if (g_ArenaPlayer2[arena] == -1) {
            g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
        }
    }

    for (int i = 1; i <= g_maxArenas; i++) {
        int p1 = g_ArenaPlayer1[i];
        int p2 = g_ArenaPlayer2[i];
        if (IsValidClient(p1)) {
            SetupPlayer(p1, i, p2, true);
        }
        if (IsValidClient(p2)) {
            SetupPlayer(p2, i, p1, false);
        }
    }

    for (int i = 1; i <= MaxClients; i++) {
        g_ArenaStatsUpdated[i] = false;
        g_LetTimeExpire[i] = false;
    }

    // round time is bu a special cvar since mp_roundtime has a lower bound of 1 minutes
    GameRules_SetProp("m_iRoundTime", g_hRoundTime.IntValue, 4, 0, true);

    // Fetch all the ratings
    // it can be expensive, so we try to get them all during freeze time where it isn't much of an issue
    if (g_hUseDatabase.IntValue != 0) {
        if (!g_dbConnected)
            DB_Connect();
        if (g_dbConnected) {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsValidClient(i) && !IsFakeClient(i) && !g_FetchedPlayerInfo[i]) {
                    DB_FetchRatings(i);
                }
            }
        }
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsActivePlayer(i) || g_BlockChatMessages[i])
            continue;

        int other = Multi1v1_GetOpponent(i);
        int arena = g_Ranking[i];
        if (IsValidClient(other)) {
            Multi1v1_Message(i, "%t", "FacingOff", arena - g_arenaOffsetValue, other);
        } else {
            Multi1v1_Message(i, "%t", "NoOpponent", arena - g_arenaOffsetValue);
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
public void SetupPlayer(int client, int arena, int other, bool onCT) {
    float angles[3];
    float spawn[3];

    int team = onCT ? CS_TEAM_CT : CS_TEAM_T;
    SwitchPlayerTeam(client, team);
    Multi1v1_GetArenaSpawn(arena, team, spawn, angles);

    CS_RespawnPlayer(client);
    TeleportEntity(client, spawn, angles, NULL_VECTOR);

    int score = 0;
    // Arbitrary scores for ordering players in the scoreboard
    if (g_ArenaPlayer1[arena] == client)
        score = 3*g_arenas - 3*arena + 1;
    else
        score = 3*g_arenas - 3*arena;

    CS_SetClientContributionScore(client, score);

    // Set clan tags to the arena number
    char buffer[32];
    Format(buffer, sizeof(buffer), "%T", "ArenaClanTag", LANG_SERVER, arena - g_arenaOffsetValue);

    if (g_hUseTeamTags.IntValue != 0)
        CS_SetClientClanTag(client, buffer);

    if (g_hUseMVPStars.IntValue != 0)
        CS_SetMVPCount(client, g_RoundsLeader[client]);

    Call_StartForward(g_hAfterPlayerSetup);
    Call_PushCell(client);
    Call_Finish();
}

/**
 * RoundEnd event, updates the global variables for the next round.
 * Specifically:
 *  - updates ratings for this round
 *  - throws all the players into a queue according to their standing from this round
 *  - updates globals g_Ranking, g_ArenaPlayer1, g_ArenaPlayer2 for the next round setup
 */
public Action Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    g_totalRounds++;
    g_roundFinished = true;

    // If time ran out and we have no winners/losers, set them
    for (int arena = 1; arena <= g_maxArenas; arena++) {
        int p1 = g_ArenaPlayer1[arena];
        int p2 = g_ArenaPlayer2[arena];
        if (g_ArenaWinners[arena] == -1) {
            g_ArenaWinners[arena] = p1;
            g_ArenaLosers[arena] = p2;
            if (IsActivePlayer(p1) && IsActivePlayer(p2)) {
                g_LetTimeExpire[p1] = true;
                g_LetTimeExpire[p2] = true;
            }
        }
        int winner = g_ArenaWinners[arena];
        int loser = g_ArenaLosers[arena];
        if (IsPlayer(winner) && IsPlayer(loser)) {

            // also skip the update if we already did it (a player got a kill earlier in the round)
            if (winner != loser) {
                if (winner != loser && IsPlayer(winner) && IsPlayer(loser)) {
                    Call_StartForward(g_hOnRoundWon);
                    Call_PushCell(winner);
                    Call_PushCell(loser);
                    Call_PushCell(g_LetTimeExpire[winner]);
                    Call_Finish();
                }
                if (!g_ArenaStatsUpdated[arena]) {
                    DB_RoundUpdate(winner, loser, g_LetTimeExpire[winner]);
                    g_ArenaStatsUpdated[arena] = true;
                }

            }
        }
    }
}

/**
 * Player death event, updates g_arenaWinners/g_arenaLosers for the arena that was just decided.
 */
public Action Event_OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int arena = g_Ranking[victim];

    // If we've already decided the arena, don't worry about anything else in it
    if (g_ArenaStatsUpdated[arena])
        return;

    if (!IsValidClient(attacker) || attacker == victim) {
        int p1 = g_ArenaPlayer1[arena];
        int p2 = g_ArenaPlayer2[arena];

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
        Call_StartForward(g_hOnRoundWon);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(false);
        Call_Finish();
        DB_RoundUpdate(attacker, victim, false);
    }

}

/**
 * Player spawn event - gives the appropriate weapons to a player for his arena.
 * Warning: do NOT assume this is called before or after the round start event!
 */
public Action Event_OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsActivePlayer(client))
        return;

    int arena = g_Ranking[client];
    if (arena < 1) {
        LogError("%L had arena %d on player spawn event, switching to queue/spec", client, arena);
        Queue_Enqueue(g_waitingQueue, client);
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        return;
    }

    int roundType = (arena == -1) ? 0 : g_roundTypes[arena];
    Multi1v1_GivePlayerArenaWeapons(client, roundType);
    CreateTimer(0.1, RemoveRadar, client);

    Call_StartForward(g_hAfterPlayerSpawn);
    Call_PushCell(client);
    Call_Finish();
    return;
}


public Action Event_MatchOver(Handle event, const char[] name, bool dontBroadcast) {
    int maxClient = -1;
    int maxScore = -1;
    for (int i = 1; i <= MaxClients; i++) {
        int score = g_RoundsLeader[i];
        if (IsPlayer(i) && (maxClient == -1 || score > maxScore)) {
            maxClient = i;
            maxScore = score;
        }
    }

    if (IsPlayer(maxClient)) {
        Multi1v1_MessageToAll("%t", "MostWins", maxClient, maxScore);
    }
}



/***********************
 *                     *
 *    Command Hooks    *
 *                     *
 ***********************/

/**
 * teamjoin hook - marks a player as waiting or moves them to spec if appropriate.
 */
public Action Command_TeamJoin(int client, const char[] command, int argc) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    // auto-give the guns menu if desired
    if (g_hAutoGunsMenuBehavior.IntValue != 0 && !g_GivenGunsMenu[client]) {
        GiveWeaponMenu(client);
    }

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team_to = StringToInt(arg);
    int team_from = GetClientTeam(client);

    if (IsFakeClient(client) || g_PluginTeamSwitch[client]) {
        return Plugin_Continue;

    } else if ((team_from == CS_TEAM_CT && team_to == CS_TEAM_T )
            || (team_from == CS_TEAM_T  && team_to == CS_TEAM_CT)) {
        // ignore changes between T/CT
        return Plugin_Handled;

    } else if (team_to == CS_TEAM_SPECTATOR) {
        // player voluntarily joining spec
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        int arena = g_Ranking[client];
        UpdateArena(arena, client);
        if (g_hUseTeamTags.IntValue != 0)
            CS_SetClientClanTag(client, "");

    } else {
        // Player first joining the game, mark them as waiting to join
        Queue_Enqueue(g_waitingQueue, client);
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
    }

    return Plugin_Handled;
}

/**
 * Hook for player chat actions, gives player the guns menu.
 */
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    // To avoid cluttering up chat, these commands are hidden
    char gunsChatCommands[][] = { "gun", "guns", ".gun", ".guns", ".setup", "!gun", "!guns", "gnus" };
    bool block = (g_hHideGunsChatCommands.IntValue != 0);
    Action ret = block ? Plugin_Handled : Plugin_Continue;

    for (int i = 0; i < sizeof(gunsChatCommands); i++) {
        if (strcmp(sArgs[0], gunsChatCommands[i], false) == 0) {
            GiveWeaponMenu(client);
            return ret;
        }
    }
    return Plugin_Continue;
}

/** sm_guns command **/
public Action Command_Guns(int client, int args) {
    GiveWeaponMenu(client);
    return Plugin_Handled;
}

public Action Command_Hidestats(int client, int args) {
    g_HideStats[client] = !g_HideStats[client];
    if (g_HideStats[client]) {
        Multi1v1_Message(client, "%t", "HideStats");
    } else {
        Multi1v1_Message(client, "%t", "ShowStats");
    }
    return Plugin_Handled;
}



/*************************
 *                       *
 * Generic 1v1-Functions *
 *                       *
 *************************/

/**
 * Switches a client to a new team.
 */
public void SwitchPlayerTeam(int client, int team) {
    int previousTeam = GetClientTeam(client);
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
 * Timer for checking round end conditions, since rounds typically won't end naturally.
 */
public Action Timer_CheckRoundComplete(Handle timer) {
    // This is a check in case the round ended naturally, we won't force another end
    if (g_roundFinished)
        return Plugin_Stop;

    // check every arena, if it is still ongoing mark allDone as false
    int nPlayers = 0;
    bool allDone = true;
    for (int arena = 1; arena <= g_maxArenas; arena++) {
        if (g_BlockArenaDones[arena]) {
            allDone = false;
            break;
        }

        int p1 = g_ArenaPlayer1[arena];
        int p2 = g_ArenaPlayer2[arena];
        bool hasp1 = IsActivePlayer(p1);
        bool hasp2 = IsActivePlayer(p2);

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

    bool normalFinish = allDone && nPlayers >= 2;

    // So the round ends for the first players that join
    bool waitingPlayers = nPlayers < 2 && Queue_Length(g_waitingQueue) > 0;

    // This check is a sanity check on when the round passes what the round time cvar allowed
    Handle freezeTimeVar = FindConVar("mp_freezetime");
    int freezeTimeLength = GetConVarInt(freezeTimeVar);
    if (freezeTimeVar == INVALID_HANDLE) {
        freezeTimeLength = 0;
        LogError("Failed to get convar mp_freezetime");
    } else {
        freezeTimeLength = GetConVarInt(freezeTimeVar);
    }

    int maxRoundLength = g_hRoundTime.IntValue + freezeTimeLength;
    int elapsedTime =  GetTime() - g_roundStartTime;

    bool roundTimeExpired = elapsedTime >= maxRoundLength && nPlayers >= 2;

    if (normalFinish || waitingPlayers || roundTimeExpired) {
        g_roundFinished = true;

        // find the delay value
        float delay = 1.0;
        Handle delayCvar = FindConVar("mp_round_restart_delay");
        if (delayCvar == INVALID_HANDLE) {
            LogError("Failed to find cvar mp_round_restart_delay");
        } else {
            delay = GetConVarFloat(delayCvar);
        }

        CS_TerminateRound(delay, CSRoundEnd_TerroristWin);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

/**
 * Resets all client variables to their default.
 */
public void ResetClientVariables(int client) {
    g_BlockChatMessages[client] = false;
    g_BlockStatChanges[client] = false;
    g_BlockMVPStars[client] = false;
    g_BlockArenaDones[client] = false;
    g_FetchedPlayerInfo[client] = false;
    g_GivenGunsMenu[client] = false;
    g_RoundsLeader[client] = 0;
    g_Wins[client] = 0;
    g_Losses[client] = 0;
    g_Rating[client] = 0.0;
    g_Ranking[client] = -1;
    g_LetTimeExpire[client] = false;
    g_Preference[client] = 0;
    g_PrimaryWeapon[client] = "weapon_ak47";
    g_SecondaryWeapon[client] = "weapon_glock";
    g_HideStats[client] = false;
}

/**
 * Updates an arena in case a player disconnects or leaves.
 * Checks if we should assign a winner/loser and informs the player they no longer have an opponent.
 */
public void UpdateArena(int arena, int disconnected) {
    if (arena != -1) {
        int p1 = g_ArenaPlayer1[arena];
        int p2 = g_ArenaPlayer2[arena];
        bool hasp1 = IsActivePlayer(p1) && p1 != disconnected;
        bool hasp2 = IsActivePlayer(p2) && p2 != disconnected;

        if (hasp1 && !hasp2) {
            PlayerLeft(arena, p1, p2);
        } else if (hasp2 && !hasp1) {
            PlayerLeft(arena, p2, p1);
        }
    }
}

static void PlayerLeft(int arena, int player, int left) {
    if (!g_ArenaStatsUpdated[arena]) {
        DB_RoundUpdate(player, left, false);
    }
    g_ArenaWinners[arena] = player;
    g_ArenaLosers[arena] = -1;
    g_ArenaStatsUpdated[arena] = true;
    if (left == g_ArenaPlayer1[arena])
        g_ArenaPlayer1[arena] = -1;
    if (left == g_ArenaPlayer2[arena])
        g_ArenaPlayer2[arena] = -1;

    if (left > 0)
        g_Ranking[left] = -1;
}
