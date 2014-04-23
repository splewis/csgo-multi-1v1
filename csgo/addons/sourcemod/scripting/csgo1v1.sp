#include <sourcemod>
#include <sdkhooks>
#include <smlib>
#include <cstrike>
#include <clientprefs>
#include "spawnpoints"
#include "queue.sp"
#include "weaponmenu.sp"
#include "stats.sp"
#include "spawn_angles.sp"

#pragma semicolon 1

#define MAX_ARENAS 12

new Handle:g_hRoundTimeVar = INVALID_HANDLE;
new Handle:g_hDefaultRatingVar = INVALID_HANDLE;

new g_Arenas = 1;
new g_Rankings[MAXPLAYERS+1] = -1;		// which arena each player is in
new g_ArenaPlayer1[MAXPLAYERS+1] = -1;	// who is player 1 in each arena
new g_ArenaPlayer2[MAXPLAYERS+1] = -1;	// who is player 2 in each arena
new g_ArenaWinners[MAXPLAYERS+1] = -1; 	// who won each arena
new g_ArenaLosers[MAXPLAYERS+1] = -1;	// who lost each arena

new g_LastWinner = -1;
new g_Score = 0;
new g_HighestScore = 0;
new g_RoundsLeader[MAXPLAYERS+1] = 0;

new bool:g_RoundFinished = false;
new g_numWaitingPlayers = 0;
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false; 	// Flags the teamswitches as being done by the plugin
new bool:g_SittingOut[MAXPLAYERS+1] = false;

public Plugin:myinfo = {
	name = "CS:GO 1v1",
	author = "splewis",
	description = "Multi-player 1v1 laddering",
	version = "0.1",
	url = "https://github.com/splewis/csgo1v1"
};

public OnPluginStart() {
	LoadTranslations("common.phrases");
	DB_Connect();

	/** convars **/
	g_hRoundTimeVar = CreateConVar("sm_csgo1v1_roundtime", "30", "Roundtime (in seconds)");
	g_hDefaultRatingVar = CreateConVar("sm_csgo1v1_default_rating", "1450.0", "ELO rating a player starts with");

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "csgo1v1");

	// Client commands
	RegAdminCmd("sm_csgo1v1_spawn", Command_Spawn, ADMFLAG_ROOT, "Goes to a spawn index.");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say2");
	AddCommandListener(Command_Say, "say_team");
	AddCommandListener(OnJoinTeamCommand, "jointeam");

	// Event hooks
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Pre);
	HookEvent("round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	HookEvent("player_connect_full", OnFullConnect);
	SC_Initialize("csgo1v1",
				  "spawn_menu", ADMFLAG_GENERIC,
				  "spawn_add", ADMFLAG_GENERIC,
				  "spawn_del", ADMFLAG_GENERIC,
				  "spawn_show", ADMFLAG_GENERIC,
				  "configs/csgo1v1",
				  2*MAX_ARENAS);


}

public OnMapStart() {
	ServerCommand("exec sourcemod/csgo1v1.cfg");
	SC_LoadMapConfig();
	Angles_MapInit();
	if (!db_connected || db == INVALID_HANDLE) {
		DB_Connect();
	}
	new numSpawns = GetArraySize(SC_GetSpawnsArray());
	if (numSpawns < 2*MAX_ARENAS) {
		LogMessage("Found %d spawns for this map, can support up to %d", numSpawns, 2*MAX_ARENAS);
	}
	if (numSpawns < 2) {
		LogError("You need to add more spawns for the plugin to work properly - use spawn_menu to add them.");
	}

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
}

public OnMapEnd() {
	// SC_SaveMapConfig();
}

public Action:OnJoinTeamCommand(client, const String:command[], argc) {
	if (!IsValidClient(client))
		return Plugin_Handled;

	decl String:arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	new team_to = StringToInt(arg);

	if (IsFakeClient(client) || g_PluginTeamSwitch[client]) {
		return Plugin_Continue;
	} else if (team_to == CS_TEAM_SPECTATOR) {
		g_SittingOut[client] = true;
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		g_isWaiting[client] = false;
		new arena = g_Rankings[client];
		g_Rankings[client] = -1;
		UpdateArena(arena);
	} else {
		AddWaiter(client);
	}
	return Plugin_Handled;
}

public AddWaiter(client) {
	if (!g_isWaiting[client]) {
		g_SittingOut[client] = false;
		g_isWaiting[client] = true;
		g_Rankings[client] = -1;
		g_numWaitingPlayers++;
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		PrintToChat(client, " \x01\x0B\x04You will be placed into an arena next round!");
		CreateTimer(1.0, Timer_PrintGunsMessage, client);
		CreateTimer(60.0, Timer_PrintGunsMessage, client);
		CreateTimer(180.0, Timer_PrintGunsMessage, client);
	}
}

public Action:OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)  {
	dontBroadcast = true;
	return Plugin_Changed;
}

public Action:OnFullConnect(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientInGame(client) && !IsFakeClient(client)) {
		ids[client] = GetSteamAccountID(client);
		AddWaiter(client);
		DB_AddPlayer(client, GetConVarFloat(g_hDefaultRatingVar));
	}
	return Plugin_Continue;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE)
		return;
	Client_RemoveAllWeapons(client, "", true);
	// TODO: try using Weapon_CreateForOwner or Client_GiveWeapon with same args to see if skins work better

	if (StrEqual(primaryWeapon[client], "weapon_awp")) {
		new arena = g_Rankings[client];
		new other = -1;
		if (client != -1 && arena != -1) {
			other = g_ArenaPlayer1[arena];
			if (other == client)
				other = g_ArenaPlayer2[arena];
		}
		if (other != -1 && StrEqual(primaryWeapon[other], "weapon_awp")) {
			GivePlayerItem(client, primaryWeapon[client]);
		} else {
			GivePlayerItem(client, backupWeapon[client]);
		}

	} else {
		GivePlayerItem(client, primaryWeapon[client]);
	}


	GivePlayerItem(client, secondaryWeapon[client]);
	GivePlayerItem(client, "weapon_knife");
	CreateTimer(0.0, RemoveRadar, client);
}

public OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
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

public GetNumArenas() {
	return GetArraySize(SC_GetSpawnsArray()) / 2;
}

public Action:Command_Spawn(client, args) {
	new String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	new Handle:spawns = SC_GetSpawnsArray();
	new index = StringToInt(arg1);
	PrintToChat(client, "Moving to spawn \x04%d", index);

	new Float:spawn[3];
	GetArrayArray(spawns, index, spawn);
	SetupPlayer(client, spawn, 1, -1, index);
	return Plugin_Handled;
}

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	g_RoundFinished = false;
	new Handle:spawns = SC_GetSpawnsArray();
	new numArenas = GetArraySize(spawns) / 2;

	for (new arena = 1; arena <= numArenas; arena++) {
		g_ArenaWinners[arena] = -1;
		g_ArenaLosers[arena] = -1;
		if (g_ArenaPlayer2[arena] == -1) {
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
		}
	}

	new spawned = 0;
	for (new i = 1; i <= numArenas; i++) {
		new p1 = g_ArenaPlayer1[i];
		new p2 = g_ArenaPlayer2[i];
		new Float:spawn[3];

		if (IsValidClient(p1)) {
			GetArrayArray(spawns, spawned, spawn);
			SetupPlayer(p1, spawn, i, p2, spawned);
			spawned++;
		}

		if (IsValidClient(p2)) {
			GetArrayArray(spawns, spawned, spawn);
			SetupPlayer(p2, spawn, i, p1, spawned);
			spawned++;
		}
	}

	GameRules_SetProp("m_iRoundTime", GetConVarInt(g_hRoundTimeVar), 4, 0, true);
	CreateTimer(2.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public SetupPlayer(client, Float:spawn[3], arena, other, spawnIndex) {
	RespawnPlayer(client);

	new Float:angles[3];
	angles[0] = 0.0;
	angles[1] = 0.0;
	angles[2] = 0.0;
	if (GetArraySize(g_hAngles) == 2) {
		if (spawnIndex % 2 == 0) {
			GetArrayArray(g_hAngles, 0, angles);
		} else {
			GetArrayArray(g_hAngles, 1, angles);
		}
	} else if (GetArraySize(g_hAngles) > 2) {
		GetArrayArray(g_hAngles, spawnIndex, angles);
	}

	TeleportEntity(client, spawn, angles, NULL_VECTOR);
	new score = 0;
	if (g_ArenaPlayer1[arena] == client)
		score = 3*g_Arenas - 3*arena + 1;
	else
		score = 3*g_Arenas - 3*arena;
	CS_SetClientContributionScore(client, score);
	CS_SetMVPCount(client, g_RoundsLeader[client]);

	decl String:buffer[20];
	Format(buffer, sizeof(buffer), "Arena %d", arena);
	CS_SetClientClanTag(client, buffer);

	if (IsValidClient(other)) {
		PrintToChat(client, "You are in arena \x04%d\x01, facing off against \x03%N", arena, other);
	} else {
		PrintToChat(client, "You are in arena \x04%d\x01 with \x07no opponent", arena);
	}
}


public Action:Timer_CheckRoundComplete(Handle:timer) {
	if (g_RoundFinished)
		return Plugin_Stop;

	new nPlayers = 0;
	new bool:AllDone = true;
	for (new arena = 1; arena <= g_Arenas; arena++) {
		new bool:hasp1 = IsValidClient(g_ArenaPlayer1[arena]) && IsOnTeam(g_ArenaPlayer1[arena]);
		new bool:hasp2 = IsValidClient(g_ArenaPlayer2[arena]) && IsOnTeam(g_ArenaPlayer2[arena]);
		if (hasp1)
			nPlayers++;
		if (hasp2)
			nPlayers++;

		if (!hasp1)
			g_ArenaWinners[arena] = g_ArenaPlayer2[arena];
		if (!hasp2)
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];

		if (g_ArenaWinners[arena] == -1 && hasp1 && hasp2) {
			AllDone = false;
			break;
		}
	}

	new bool:NormalFinish = AllDone && nPlayers >= 2;
	new bool:WaitingPlayers = nPlayers < 2 && g_numWaitingPlayers > 0;

	if ((NormalFinish || WaitingPlayers) && GetNumArenas() >= 1) {
		CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	g_RoundFinished = true;
	new numArenas = GetNumArenas();

	// If time ran out and we have no winners/losers, set them
	for (new arena = 1; arena <= g_Arenas; arena++) {
		new p1 = g_ArenaPlayer1[arena];
		new p2 = g_ArenaPlayer2[arena];
		if (g_ArenaWinners[arena] == -1) {
			g_ArenaWinners[arena] = p1;
			g_ArenaLosers[arena] = p2;
		}
		new winner = g_ArenaWinners[arena];
		new loser = g_ArenaLosers[arena];
		if (IsValidClient(winner) && IsValidClient(loser) && !IsFakeClient(winner) && !IsFakeClient(loser)) {
			DB_Increment(winner, "wins");
			DB_Increment(loser, "losses");
			DB_UpdateRating(winner, loser);
		}

	}

	InitQueue();

	//  top arena
	AddPlayer(g_ArenaWinners[1]);
	AddPlayer(g_ArenaWinners[2]);

	// middle arenas
	for (new i = 2; i <= numArenas - 1; i++) {
		AddPlayer(g_ArenaLosers[i - 1]);
		AddPlayer(g_ArenaWinners[i + 1]);
	}

	// bottom arena
	if (numArenas >= 1) {
		AddPlayer(g_ArenaLosers[numArenas - 1]);
		AddPlayer(g_ArenaLosers[numArenas]);
	}



	for (new i = 1; i <= MaxClients; i++) {
		g_isWaiting[i] = false;
		if (IsClientInGame(i) && !IsFakeClient(i) && FindInQueue(i) == -1)
			AddPlayer(i);
	}

	// new qSize = GetQueueLength();
	// if (qSize > 0 && qSize % 2 == 1) {
	// 	ServerCommand("bot_quota %d", qSize + 1);
	// 	for (new i = 1; i <= MaxClients; i++) {
	// 		if (IsClientInGame(i) && IsFakeClient(i) && FindInQueue(i) == -1)
	// 			AddPlayer(i);
	// 	}
	// } else {
	// 	ServerCommand("bot_quota 0");
	// 	ServerCommand("bot_kick");
	// }

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
			PrintToChatAll("The new leader is \x03%N\x01", leader);
		}
	}
	g_LastWinner = leader;


	// Player placement logic for next round
	g_Arenas = 0;
	for (new arena = 1; arena <= numArenas; arena++) {
		new p1 = DeQueue();
		new p2 = DeQueue();
		g_ArenaPlayer1[arena] = p1;
		g_ArenaPlayer2[arena] = p2;

		new bool:realp1 = IsValidClient(p1);
		new bool:realp2 = IsValidClient(p2);

		if (realp1) {
			g_isWaiting[p1] = false;
			g_Rankings[p1] = arena;
			SwitchPlayerTeam(p1, CS_TEAM_CT);
		}

		if (realp2) {
			g_isWaiting[p2] = false;
			g_Rankings[p2] = arena;
			SwitchPlayerTeam(p2, CS_TEAM_T);
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
		EnQueue(client);
	}
}

public ResetClientVariables(client) {
	if (g_isWaiting[client])
		g_numWaitingPlayers--;
	ratings[client] = 0.0;
	g_SittingOut[client] = false;
	g_isWaiting[client] = false;
	primaryWeapon[client] = "weapon_ak47";
	secondaryWeapon[client] = "weapon_glock";
	g_RoundsLeader[client] = 0;
}

public OnClientConnected(client) {
	ResetClientVariables(client);
}

public OnClientDisconnect(client) {
	DB_WriteRating(client);
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
	if (!IsFakeClient(client))
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
	if (GetClientTeam(client) == team)
		return;

	g_PluginTeamSwitch[client] = true;
	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
		// if (!IsPlayerAlive(client))
		// 	CS_RespawnPlayer(client);
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
