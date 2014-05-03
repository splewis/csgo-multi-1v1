#define PLUGIN_VERSION "0.1.0"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <smlib>
#include "multi1v1/stats.sp"
#include "multi1v1/spawns.sp"
#include "multi1v1/weaponmenu.sp"
#include "multi1v1/queue.sp"

#pragma semicolon 1

new Handle:g_hRoundTimeVar = INVALID_HANDLE;
new Handle:g_hDefaultRatingVar = INVALID_HANDLE;
new Handle:g_hCvarVersion = INVALID_HANDLE;

new g_Arenas = 1;
new g_Rankings[MAXPLAYERS+1] = -1;		// which arena each player is in
new g_ArenaPlayer1[MAXPLAYERS+1] = -1;	// who is player 1 in each arena
new g_ArenaPlayer2[MAXPLAYERS+1] = -1;	// who is player 2 in each arena
new g_ArenaWinners[MAXPLAYERS+1] = -1; 	// who won each arena
new g_ArenaLosers[MAXPLAYERS+1] = -1;	// who lost each arena
new bool:g_LetTimeExpire[MAXPLAYERS+1] = false;

new g_TotalRounds = 0;
new g_LastWinner = -1;
new g_Score = 0;
new g_HighestScore = 0;
new g_RoundsLeader[MAXPLAYERS+1] = 0;

new bool:g_InWarmup = true;
new bool:g_RoundFinished = false;
new g_numWaitingPlayers = 0;
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false; 	// Flags the teamswitches as being done by the plugin
new bool:g_SittingOut[MAXPLAYERS+1] = false;

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
	g_hRoundTimeVar = CreateConVar("sm_multi1v1_roundtime", "30", "Roundtime (in seconds)");
	g_hUseDatabase = CreateConVar("sm_multi1v1_use_database", "1", "Should we use a database to store stats and preferences");
	g_hDefaultRatingVar = CreateConVar("sm_multi1v1_default_rating", "1450.0", "ELO rating a player starts with");
	g_hCvarVersion = CreateConVar("sm_multi1v1_version", PLUGIN_VERSION, "Current multi1v1 version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

	// Create and exec plugin's configuration file
	// AutoExecConfig(true, "multi1v1");

	/** Cookies **/
	g_hAllowPistolCookie = RegClientCookie("multi1v1_allowpistol", "Multi-1v1 allow pistol rounds", CookieAccess_Protected);
	g_hAllowAWPCookie = RegClientCookie("multi1v1_allowawp", "Multi-1v1 allow AWP rounds", CookieAccess_Protected);
	g_hPreferenceCookie = RegClientCookie("multi1v1_preference", "Multi-1v1 round-type preference", CookieAccess_Protected);
	g_hRifleCookie = RegClientCookie("multi1v1_rifle", "Multi-1v1 rifle choice", CookieAccess_Protected);
	g_hPistolCookie = RegClientCookie("multi1v1_pistol", "Multi-1v1 pistol choice", CookieAccess_Protected);
	g_hSetCookies = RegClientCookie("multi1v1_setprefs", "Multi-1v1 if prefs are saved", CookieAccess_Protected);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");
	AddCommandListener(OnJoinTeamCommand, "jointeam");

	/** Player commands */
	RegConsoleCmd("sm_stats", Command_Stats, "Displays a players multi-1v1 stats");

	/** Event hooks **/
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("round_end", Event_OnRoundEnd);
}

public OnMapStart() {
	g_InWarmup = true;
	ServerCommand("exec sourcemod/multi1v1.cfg");
	Spawns_MapInit();
	if (!g_dbConnected && GetConVarInt(g_hUseDatabase) != 0) {
		DB_Connect();
	}
	if (g_numSpawns < 18) {
		LogMessage("Found %d spawns for this map, at least %d are recommended", g_numSpawns, 18);
	}
	if (g_numSpawns < 2) {
		PrintToChatAll(" \x01\x0B\x02[FATAL] \x01You need to add more spawns for the multi1v1 plugin to work properly");
		LogError("You need to add more spawns for the plugin to work properly - use spawn_menu to add them.");
	}

	g_TotalRounds = 0;
	g_LastWinner = -1;
	g_Score = 0;
	g_HighestScore = 0;
	g_RoundFinished = false;
	g_numWaitingPlayers = 0;
	for (new i = 0; i <= MAXPLAYERS; i++) {
		g_RoundsLeader[i] = 0;
		g_Rankings[i] = -1;
		g_Arenas = 1;
		g_Rankings[i] = -1;
		g_ArenaPlayer1[i] = -1;
		g_ArenaPlayer2[i] = -1;
		g_ArenaWinners[i] = -1;
		g_ArenaLosers[i] = -1;
		g_PluginTeamSwitch[i] = false;
		g_SittingOut[i] = false;
	}
	CreateTimer(1.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public OnMapEnd() {

}

public Action:OnJoinTeamCommand(client, const String:command[], argc) {
	if (g_maxArenas < 1) {
		PrintToChatAll(" \x01\x0B\x02[FATAL] \x01You need to add more spawns for the multi1v1 plugin to work properly");
		LogError("You need to add more spawns for the plugin to work properly - use spawn_menu to add them.");
	}

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

/**
 * Hook for player chat actions.
 */
public Action:Command_Say(client, const String:command[], argc) {
	decl String:text[192];
	if (GetCmdArgString(text, sizeof(text)) < 1)
		return Plugin_Continue;

	StripQuotes(text);
	if (strcmp(text[0], "guns", false) == 0 || strcmp(text[0], "!guns", false) == 0) {
		AWPMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public AddWaiter(client) {
	if (!g_isWaiting[client]) {
		PrintToChat(client, " \x01\x0B\x04Welcome to CS:GO 1v1! You will be placed into an arena next round!");
		g_SittingOut[client] = false;
		g_isWaiting[client] = true;
		g_Rankings[client] = -1;
		g_numWaitingPlayers++;
		SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
		CreateTimer(1.0, Timer_PrintGunsMessage, client);
		CreateTimer(30.0, Timer_PrintWelcomeMessage, client);
		CreateTimer(50.0, Timer_PrintGunsHint, client);
		CreateTimer(60.0, Timer_PrintGunsMessage, client);
		CreateTimer(180.0, Timer_PrintGunsMessage, client);
	}
}

public Action:Timer_PrintWelcomeMessage(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client)) {
		PrintToChat(client, " \x01\x0B\x05You can check out your stats at \x04csgo1v1.splewis.net \x05and by using \x04!stats \05or \x04/stats \x05in chat");
	}
	return Plugin_Handled;
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)  {
	dontBroadcast = true;
	return Plugin_Changed;
}

/**
 * Called once a client is authorized and fully in-game, and
 * after all post-connection authorizations have been performed.
 */
public OnClientPostAdminCheck(client) {
	if (IsClientInGame(client) && !IsFakeClient(client) && GetConVarInt(g_hUseDatabase) != 0) {
		DB_AddPlayer(client, GetConVarFloat(g_hDefaultRatingVar));
		DB_FetchRatings(client);
	}
}

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

public Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE)
		return;

	Client_RemoveAllWeapons(client, "", true);

	new arena = g_Rankings[client];
	new RoundType:roundType = (arena == -1) ? RoundType_Rifle : g_roundTypes[arena];

	if (roundType == RoundType_Rifle) {
		if (GivePlayerItem(client, g_primaryWeapon[client]) == -1)
			GivePlayerItem(client, "weapon_ak47");
	} else if (roundType == RoundType_Awp) {
		GivePlayerItem(client, "weapon_awp");
	} else if (roundType == RoundType_Pistol) {
		RemoveHelmet(client);
	}

	if (GivePlayerItem(client, g_secondaryWeapon[client]) == -1)
		GivePlayerItem(client, "weapon_glock");

	GivePlayerItem(client, "weapon_knife");

	if (g_LetTimeExpire[client] && g_TotalRounds >= 3) {
		PrintToChat(client, " \x01\x0B\x04You let time run out last round. You will be punished and get \x031HP \x04next round.");
		PrintHintText(client, "You let time run out last round. You will be punished and get 1HP next round.");
		SetEntityHealth(client, 1);
	}

	CreateTimer(0.0, RemoveRadar, client);
}

public RemoveHelmet(client) {
 	new g_iPlayers_HelmetOffset = FindSendPropOffs("CCSPlayer", "m_bHasHelmet");
 	SetEntData(client, g_iPlayers_HelmetOffset, 0);
}

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

public Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	g_RoundFinished = false;
	new numArenas = g_maxArenas;

	for (new arena = 1; arena <= numArenas; arena++) {
		g_ArenaWinners[arena] = -1;
		g_ArenaLosers[arena] = -1;
		if (g_ArenaPlayer2[arena] == -1) {
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
		}
	}

	for (new i = 1; i <= numArenas; i++) {
		new p1 = g_ArenaPlayer1[i];
		new p2 = g_ArenaPlayer2[i];

		g_roundTypes[i] = GetRoundType(p1, p2);

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
	CreateTimer(2.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public SetupPlayer(client, arena, other, bool:onCT) {
	RespawnPlayer(client);
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
 * Timer for checking round end conditions, since rounds typically won't end naturally.
 */
public Action:Timer_CheckRoundComplete(Handle:timer) {

	// GameRules_SetProp("m_bWarmupPeriod", true, _, _, true);
	// LogMessage("GameRules_GetProp warmup: %d", GameRules_GetProp("m_bWarmupPeriod"));

	// This is a check in case the round ended naturally, we won't force another end
	if (g_RoundFinished)
		return Plugin_Stop;

	// check every arena, if it is still ongoing mark AllDone as false
	new nPlayers = 0;
	new bool:AllDone = true;
	for (new arena = 1; arena <= g_Arenas; arena++) {
		new bool:hasp1 = IsValidClient(g_ArenaPlayer1[arena]) && IsOnTeam(g_ArenaPlayer1[arena]);
		new bool:hasp2 = IsValidClient(g_ArenaPlayer2[arena]) && IsOnTeam(g_ArenaPlayer2[arena]);
		if (hasp1)
			nPlayers++;
		if (hasp2)
			nPlayers++;

		// If we don't have 2 players, mark the lone one as winner
		if (!hasp1)
			g_ArenaWinners[arena] = g_ArenaPlayer2[arena];
		if (!hasp2)
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];

		// this arena has 2 players and hasn't been decided yet
		if (g_ArenaWinners[arena] == -1 && hasp1 && hasp2) {
			AllDone = false;
			break;
		}
	}

	new bool:NormalFinish = AllDone && nPlayers >= 2;
	new bool:WaitingPlayers = nPlayers < 2 && g_numWaitingPlayers > 0;  // so the round ends for the first players that join

	// check if there are enough arenas, otherwise round will constantly end
	if ((NormalFinish || WaitingPlayers) && g_maxArenas >= 1) {
		CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	g_TotalRounds++;
	g_RoundFinished = true;

	// If time ran out and we have no winners/losers, set them
	for (new arena = 1; arena <= g_Arenas; arena++) {
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
	InitQueue();

	//  top arena
	AddPlayer(g_ArenaWinners[1]);
	AddPlayer(g_ArenaWinners[2]);

	// middle arenas
	for (new i = 2; i <= g_maxArenas - 1; i++) {
		AddPlayer(g_ArenaLosers[i - 1]);
		AddPlayer(g_ArenaWinners[i + 1]);
	}

	// bottom arena
	if (g_maxArenas >= 1) {
		AddPlayer(g_ArenaLosers[g_maxArenas - 1]);
		AddPlayer(g_ArenaLosers[g_maxArenas]);
	}

	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && FindInQueue(i) == -1)
			AddPlayer(i);
	}

	// Set leader and scoring information
	new leader = g_ClientQueue[g_QueueHead];
	if (IsValidClient(leader) && GetQueueLength() >= 2) {
		g_RoundsLeader[leader]++;
		CS_SetMVPCount(leader, g_RoundsLeader[leader]);
		if (g_LastWinner == leader && GetQueueLength() >= 2) {
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


	// Player placement logic for next round
	g_Arenas = 0;
	for (new arena = 1; arena <= g_maxArenas; arena++) {
		new p1 = DeQueue();
		new p2 = DeQueue();
		g_ArenaPlayer1[arena] = p1;
		g_ArenaPlayer2[arena] = p2;

		new bool:realp1 = IsValidClient(p1);
		new bool:realp2 = IsValidClient(p2);

		if (realp1) {
			g_isWaiting[p1] = false;
			g_Rankings[p1] = arena;
			// SwitchPlayerTeam(p1, CS_TEAM_CT);
		}

		if (realp2) {
			g_isWaiting[p2] = false;
			g_Rankings[p2] = arena;
			// SwitchPlayerTeam(p2, CS_TEAM_T);
		}

		if (realp1 || realp2) {
			g_Arenas++;
		} else {
			break;
		}
	}

	// clear the queue
	g_numWaitingPlayers = 0;
	while (!IsQueueEmpty()) {
		new client = DeQueue();
		g_Rankings[client] = -1;
		g_isWaiting[client] = true;
		g_numWaitingPlayers++;
	}

}

public AddPlayer(client) {
	if (IsValidClient(client) && !g_SittingOut[client]) {

		// if (GetClientTeam(client) == CS_TEAM_SPECTATOR && !g_isWaiting[client]) {
			// PrintToChatAll("NOT add player %N", client);
			// moved to spectator without the player selecting it, e.g. moved by an afk manager
			// return;
		// }

		EnQueue(client);
	}
}

public ResetClientVariables(client) {
	if (g_isWaiting[client])
		g_numWaitingPlayers--;
	DB_ResetClientVariables(client);
	g_LetTimeExpire[client] = false;
	g_SittingOut[client] = false;
	g_isWaiting[client] = false;
	g_AllowAWP[client] = false;
	g_AllowPistol[client] = false;
	g_Preference[client] = RoundType_Rifle;
	g_primaryWeapon[client] = "weapon_ak47";
	g_secondaryWeapon[client] = "weapon_glock";
	g_RoundsLeader[client] = 0;
}

public OnClientConnected(client) {
	ResetClientVariables(client);
}

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
}

public OnClientDisconnect(client) {
	if (GetConVarInt(g_hUseDatabase) != 0)
		DB_WriteRatings(client);

	if (IsValidClient(client)) {
		new arena = g_Rankings[client];
		UpdateArena(arena);
	}
	ResetClientVariables(client);
	DropFromQueue(client);
}

public UpdateArena(arena) {
	if (arena != -1) {
		new p1 = g_ArenaPlayer1[arena];
		new p2 = g_ArenaPlayer2[arena];
		if (IsValidClient(p1) && !IsValidClient(p2)) {
			g_ArenaWinners[arena] = p1;
			g_ArenaLosers[arena] = p2;
		} else {
			g_ArenaWinners[arena] = p1;
			g_ArenaLosers[arena] = p2;
		}
	}
}

public Action:RemoveRadar(Handle:timer, any:client) {
	if (IsValidClient(client) && !IsFakeClient(client))
		SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}

/**
 * Respawn a Player while ensuring join team command is ignored if triggered
 */
RespawnPlayer(client) {
	g_PluginTeamSwitch[client] = true;
	if (IsOnTeam(client))
		CS_RespawnPlayer(client);
	g_PluginTeamSwitch[client] = false;
}


SwitchPlayerTeam(client, team) {
	new previousTeam = GetClientTeam(client);
	if (previousTeam == team)
		return;

	g_PluginTeamSwitch[client] = true;
	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
		if (!IsPlayerAlive(client))
			CS_RespawnPlayer(client);
	} else {
		ChangeClientTeam(client, team);
	}
	g_PluginTeamSwitch[client] = false;
}

/***************************
 * Stocks                  *
 *  &                      *
 * SMLib Functions (berni) *
****************************/

/**
 * Function to identify if a client is valid and in game
 *
 * @param	client		Vector to be evaluated
 * @return 				true if valid client, false if not
 */
stock bool:IsValidClient(client) {
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}

bool:IsOnTeam(client) {
	new client_team = GetClientTeam(client);
	return (client_team == CS_TEAM_CT) || (client_team == CS_TEAM_T);
}
