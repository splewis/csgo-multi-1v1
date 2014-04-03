#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>
#include <adminmenu>
#include "spawnpoints"
#include "queue.sp"
#include "weaponmenu.sp"

#pragma semicolon 1

#define MAX_ARENAS 6

new Handle:g_Enabled = INVALID_HANDLE;
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

	/** convars **/
	g_Enabled = CreateConVar("sm_csgo1v1_enabled", "1", "Sets whether csgo1v1 is enabled");

	// Create and exec plugin's configuration file
	AutoExecConfig(true, "csgo1v1");

	if (GetConVarInt(g_Enabled) == 1) {
		// Client commands
		RegConsoleCmd("sm_guns", Command_guns, "Opens the !guns menu");
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
		SC_Initialize("csgo1v1",
					  "spawn_menu", ADMFLAG_GENERIC,
					  "spawn_add", ADMFLAG_GENERIC,
					  "spawn_del", ADMFLAG_GENERIC,
					  "spawn_show", ADMFLAG_GENERIC,
					  "configs/csgo1v1",
					  2*MAX_ARENAS);

	}
}

public OnMapStart() {
	ServerCommand("exec sourcemod/csgo1v1.cfg");
	SC_LoadMapConfig();
	new numSpawns = GetArraySize(SC_GetSpawnsArray());
	if (numSpawns < 2*MAX_ARENAS) {
		LogMessage("[CS:GO 1v1] There are not enough spawns on this map, only found %d, expected at least %d", numSpawns, 2*MAX_ARENAS);
	}
}

public OnMapEnd() {
	SC_SaveMapConfig();
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
		new arena = g_Rankings[client];
		g_Rankings[client] = -1;
		UpdateArena(arena);
	} else {
		if (!g_isWaiting[client]) {
			g_isWaiting[client] = true;
			g_Rankings[client] = -1;
			g_numWaitingPlayers++;
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
			PrintToChat(client, "You will be placed into an arena next round!");
			PrintToChat(client, "Type guns into chat to select new weapons.");
		}
	}
	return Plugin_Handled;
}

public Action:OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)  {
	dontBroadcast = true;
	return Plugin_Changed;
}

public OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || GetClientTeam(client) <= CS_TEAM_NONE)
		return;
	Client_RemoveAllWeapons(client, "", true);
	// TODO: try using Weapon_CreateForOwner or Client_GiveWeapon with same args to see if skins work better
	GivePlayerItem(client, primaryWeapon[client]);
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

public OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	g_RoundFinished = false;

	for (new arena = 1; arena <= MAX_ARENAS; arena++) {
		g_ArenaWinners[arena] = -1;
		g_ArenaLosers[arena] = -1;
		if (g_ArenaPlayer2[arena] == -1) {
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
		}
	}

	new Handle:spawns = SC_GetSpawnsArray();
	new spawned = 0;
	for (new i = 1; i <= MAX_ARENAS; i++) {
		new p1 = g_ArenaPlayer1[i];
		new p2 = g_ArenaPlayer2[i];
		new Float:spawn[3];

		if (IsValidClient(p1)) {
			GetArrayArray(spawns, spawned, spawn);
			SetupPlayer(p1, spawn, i, p2);
			spawned++;
		}

		if (IsValidClient(p2)) {
			GetArrayArray(spawns, spawned, spawn);
			SetupPlayer(p2, spawn, i, p1);
			spawned++;
		}
	}

	CreateTimer(1.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public SetupPlayer(client, Float:spawn[3], arena, other) {
	RespawnPlayer(client);
	FreezePlayer(client, false);
	TeleportEntity(client, spawn, NULL_VECTOR, NULL_VECTOR);
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
		PrintToChat(client, "You are in arena %d, facing off against %N", arena, other);
	} else {
		PrintToChat(client, "You are in arena %d with no opponent", arena);
	}
}


public Action:Timer_CheckRoundComplete(Handle:timer) {
	if (g_RoundFinished)
		return Plugin_Stop;

	new nPlayers = 0;
	new bool:AllDone = true;
	for (new arena = 1; arena <= g_Arenas; arena++) {
		new bool:hasp1 = IsValidClient(g_ArenaPlayer1[arena]);
		new bool:hasp2 = IsValidClient(g_ArenaPlayer2[arena]);
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

	if (NormalFinish || WaitingPlayers) {
		CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	g_RoundFinished = true;

	// If time ran out and we have no winners/losers, set them
	for (new arena = 1; arena <= g_Arenas; arena++) {
		new p1 = g_ArenaPlayer1[arena];
		new p2 = g_ArenaPlayer2[arena];
		if (g_ArenaWinners[arena] == -1) {
			g_ArenaWinners[arena] = p1;
			g_ArenaLosers[arena] = p2;
		}
	}

	InitQueue();
	//  top arena
	AddPlayer(g_ArenaWinners[1]);
	AddPlayer(g_ArenaWinners[2]);

	// middle arenas
	for (new i = 2; i <= MAX_ARENAS - 1; i++) {
		AddPlayer(g_ArenaLosers[i - 1]);
		AddPlayer(g_ArenaWinners[i + 1]);
	}

	// bottom arena
	AddPlayer(g_ArenaLosers[MAX_ARENAS - 1]);
	AddPlayer(g_ArenaLosers[MAX_ARENAS]);

	for (new i = 1; i <= MaxClients; i++) {
		g_isWaiting[i] = false;
		if (FindInQueue(i) == -1)
			AddPlayer(i);
	}

	new leader = g_ClientQueue[g_QueueHead];
	if (IsValidClient(leader) && GetQueueLength() >= 2) {
		g_RoundsLeader[leader]++;
		CS_SetMVPCount(leader, g_RoundsLeader[leader]);
		if (g_LastWinner == leader && GetQueueLength() >= 2) {
			g_Score++;
			if (g_Score > g_HighestScore) {
				g_HighestScore = g_Score;
				PrintToChatAll("%N has set a record of leading %d rounds in a row!", leader, g_Score);
			} else {
				PrintToChatAll("%N has stayed at the top for %d rounds in a row!", leader, g_Score);
			}
		} else {
			g_Score = 1;
			PrintToChatAll("The new leader is %N", leader);
		}
	}
	g_LastWinner = leader;


	// Player placement logic for next round
	g_Arenas = 0;
	for (new arena = 1; arena <= MAX_ARENAS; arena++) {
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
			FreezePlayer(p1, true);
		}

		if (realp2) {
			g_isWaiting[p2] = false;
			g_Rankings[p2] = arena;
			SwitchPlayerTeam(p2, CS_TEAM_T);
			FreezePlayer(p2, true);
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
	if (IsValidClient(client) && !IsFakeClient(client) && !g_SittingOut[client]) {
		EnQueue(client);
	}
}

public ResetClientVariables(client) {
	if (g_isWaiting[client])
		g_numWaitingPlayers--;
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
	SetEntProp(client, Prop_Send, "m_iHideHUD", 1 << 12);
}

/**
 * Respawn a Player while ensuring join team command is ignored if triggered
 */
RespawnPlayer(client) {
	g_PluginTeamSwitch[client] = true;
	CS_RespawnPlayer(client);
	g_PluginTeamSwitch[client] = false;
}


SwitchPlayerTeam(client, team) {
	g_PluginTeamSwitch[client] = true;
	if (team > CS_TEAM_SPECTATOR) {
		CS_SwitchTeam(client, team);
		CS_UpdateClientModel(client);
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

/**
 * Function to handle un/freezing of a player
 */
FreezePlayer(client, bool:freeze) {
	if (IsValidEntity(client)) {
		if (freeze)
			SetEntityMoveType(client, MOVETYPE_NONE);
		else
			SetEntityMoveType(client, MOVETYPE_WALK);
	}
}
