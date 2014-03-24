#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>
#include <adminmenu>
#include "spawnpoints"

#pragma semicolon 1

#define MAX_ARENAS 6

new Handle:g_Enabled = INVALID_HANDLE;
new g_Arenas = 1;
new g_Rankings[MAX_ARENAS+1] = -1;		// which arena each player is in
new g_ArenaPlayer1[MAX_ARENAS+1] = -1;	// who is player 1 in each arena
new g_ArenaPlayer2[MAX_ARENAS+1] = -1;	// who is player 2 in each arena
new g_ArenaWinners[MAX_ARENAS+1] = -1; 	// who won each arena
new g_ArenaLosers[MAX_ARENAS+1] = -1;	// who lost each arena

new g_LastWinner = -1;
new g_Score = 0;
new g_HighestScore = 0;

new bool:g_GameStarted = false;
new bool:g_RoundFinished = false;
new g_numWaitingPlayers = 0;
new bool:g_PluginTeamSwitch[MAXPLAYERS+1] = false; 	// Flags the teamswitches as being done by the plugin

// Other data for weapon handling
#define WEAPON_LENGTH 24
new String:primaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];
new String:secondaryWeapon[MAXPLAYERS + 1][WEAPON_LENGTH];

// Queue data
new g_QueueSize = MAXPLAYERS+1;
new g_ClientQueue[MAXPLAYERS+1];
new g_QueueHead = 0;
new g_QueueTail = 0;
new g_isWaiting[MAXPLAYERS+1] = false;


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
		AddCommandListener(OnJoinTeamCommand, "jointeam");
		RegConsoleCmd("sm_guns", Command_Primary, "Opens the !guns menu");
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
	g_GameStarted = false;
	ServerCommand("exec sourcemod/csgo1v1.cfg");
	SC_LoadMapConfig();
	new numSpawns = GetArraySize(SC_GetSpawnsArray());
	if (numSpawns != 2*MAX_ARENAS) {
		LogMessage("[CS:GO 1v1] There are not enough spawns on this map, found %d, expected %d", numSpawns, 2*MAX_ARENAS);
	}
}

public OnMapEnd() {
	SC_SaveMapConfig();
}

public Action:OnJoinTeamCommand(client, const String:command[], argc) {
	if (!IsValidClient(client) || argc < 1)
		return Plugin_Handled;

	decl String:arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	new team_to = StringToInt(arg);

	if (IsFakeClient(client) || g_PluginTeamSwitch[client]) {
		return Plugin_Continue;
	} else if (team_to == CS_TEAM_SPECTATOR) {
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
			PrimaryMenu(client);
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

	for (new arena = 1; arena <= g_Arenas; arena++) {
		g_ArenaWinners[arena] = -1;
		g_ArenaLosers[arena] = -1;
		if (g_ArenaPlayer2[arena] == -1) {
			g_ArenaWinners[arena] = g_ArenaPlayer1[arena];
		}
	}

	new Handle:spawns = SC_GetSpawnsArray();
	new spawned = 0;
	for (new i = 1; i <= g_Arenas; i++) {
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

	CS_SetTeamScore(CS_TEAM_CT, g_Score);
	CS_SetTeamScore(CS_TEAM_T, 0);

	CreateTimer(1.0, Timer_CheckRoundComplete, _, TIMER_REPEAT);
}

public SetupPlayer(client, Float:spawn[3], arena, other) {
	RespawnPlayer(client);
	TeleportEntity(client, spawn, NULL_VECTOR, NULL_VECTOR);
	CS_SetClientContributionScore(client, 3*g_Arenas - 3*arena + 1);

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

		if (g_ArenaWinners[arena] == -1 && hasp1 && hasp2) {
			AllDone = false;
			break;
		}
	}

	new bool:earlyEnd = !g_GameStarted && (g_numWaitingPlayers >= 1);

	if ((AllDone || earlyEnd) && (nPlayers >= 2 || g_numWaitingPlayers >= 1)) {
		CS_TerminateRound(2.0, CSRoundEnd_TerroristWin);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	g_GameStarted = true;
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

	//  top arena
	AddPlayer(g_ArenaWinners[1]);
	AddPlayer(g_ArenaWinners[2]);

	// middle arenas
	for (new i = 2; i <= MAX_ARENAS - 1; i++) {
		AddPlayer(g_ArenaLosers[i - 1]);
		AddPlayer(g_ArenaWinners[i + 1]);
	}

	// bottom arena
	AddPlayer(g_ArenaLosers[5]);
	AddPlayer(g_ArenaLosers[6]);

	for (new i = 1; i <= MaxClients; i++) {
		if (g_isWaiting[i])
			AddPlayer(i);
	}

	new queueLength = GetQueueLength();
	for (new i = 1; i <= MaxClients; i++) {
		new pos = FindInQueue(i);
		if (i != -1)
			PrintToChat(i, "You are in position %d out of %d", pos, queueLength);
	}


	new leader = g_ClientQueue[g_QueueHead];
	if (IsValidClient(leader)) {
		if (g_LastWinner == leader && GetQueueLength() >= 2) {
			g_Score++;
			CS_SetTeamScore(CS_TEAM_T, g_Score);
			if (g_Score > g_HighestScore) {
				g_HighestScore = g_Score;
				PrintToChatAll("%N has set a record of leading %d rounds in a row!", leader, g_Score);
			} else {
				PrintToChatAll("%N has stayed at the top for %d rounds in a row!", leader, g_Score);
			}
		} else {
			g_Score = 1;
			CS_SetTeamScore(CS_TEAM_T, 0);
			PrintToChatAll("The new leader is %N", leader);
		}
	}
	g_LastWinner = leader;

	g_Arenas = 0;

	// Player placement logic for next round
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
			ChangeClientTeam(p1, CS_TEAM_CT);
		}

		if (realp2) {
			g_isWaiting[p2] = false;
			g_Rankings[p2] = arena;
			ChangeClientTeam(p2, CS_TEAM_T);
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
		g_isWaiting[client] = true;
		g_numWaitingPlayers++;
	}

}

public AddPlayer(client) {
	if (IsValidClient(client) && !IsFakeClient(client)) {
		EnQueue(client);
	}
}

public ResetClientVariables(client) {
	if (g_isWaiting[client])
		g_numWaitingPlayers--;
	g_isWaiting[client] = false;
	primaryWeapon[client] = "weapon_ak47";
	secondaryWeapon[client] = "weapon_glock";
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
		if (IsValidClient(p1) && IsClientInGame(p1))
			g_ArenaWinners[arena] = p1;
		else if (IsValidClient(p2) && IsClientInGame(p2))
			g_ArenaWinners[arena] = p2;
	}
}

RespawnPlayer(client) {
	g_PluginTeamSwitch[client] = true;
	CS_RespawnPlayer(client);
	g_PluginTeamSwitch[client] = false;
}

public PrimaryMenu(client) {
	new Handle:menu = CreateMenu(Weapon_MenuHandler_Primary);
	SetMenuTitle(menu, "Chose your primary weapon:");
	AddMenuItem(menu, "weapon_ak47", "AK47");
	AddMenuItem(menu, "weapon_m4a1", "M4A4");
	AddMenuItem(menu, "weapon_m4a1_silencer", "M4A1-S");
	AddMenuItem(menu, "weapon_famas", "Famas");
	AddMenuItem(menu, "weapon_galilar", "Galil");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SecondaryMenu(client) {
	new Handle:menu = CreateMenu(Weapon_MenuHandler_Secondary);
	SetMenuExitButton(menu, true);
	SetMenuTitle(menu, "Chose your secondary weapon:");
	AddMenuItem(menu, "weapon_hkp2000", "P2000");
	AddMenuItem(menu, "weapon_usp_silencer", "USP");
	AddMenuItem(menu, "weapon_glock", "Glock");
	AddMenuItem(menu, "weapon_p250", "P250");
	AddMenuItem(menu, "weapon_cz75a", "CZ75");
	AddMenuItem(menu, "weapon_deagle", "Deagle");
	AddMenuItem(menu, "weapon_fiveseven", "Five Seven");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Action:Command_Primary(client, args) {
	PrimaryMenu(client);
}

public Action:Command_Secondary(client, args) {
	SecondaryMenu(client);
}

public Weapon_MenuHandler_Primary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		primaryWeapon[param1] = info;
		SecondaryMenu(param1);
	}
}

public Weapon_MenuHandler_Secondary(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:info[WEAPON_LENGTH];
		GetMenuItem(menu, param2, info, sizeof(info));
		secondaryWeapon[param1] = info;
		PrintToChat(param1, "You will get your new weapons next spawn.");
	}
}


/*********************************
 * Circular Queue Implementation *
**********************************/

/**
 * Push a Client into the Queue (don't add a client if already in queue)
 * @param client		The client to push into the queue
 * @return				returns 0 if added or -1 if already in queue
 */
public EnQueue(client) {
	//if (g_QueueTail + 1) mod g_QueueSize equals head, then the queue is full. - not sure if possible, so ignoring
	if(FindInQueue(client) != -1)
		return -1;

	g_ClientQueue[g_QueueTail] = client;
	g_QueueTail = (g_QueueTail + 1) % g_QueueSize;
	return 0;
}

/**
 * Finds a client in the Queue
 * @param client		The client to find in the queue
 * @return				index of client in internal array, -1 if not in queue
 */
public FindInQueue(client) {
	new i = g_QueueHead, bool:found = false;
	while(i != g_QueueTail && !found) {
		if (client == g_ClientQueue[i]) {
			found = true;
		} else {
			i = (i + 1) % g_QueueSize;
		}
	}
	return found ? i : -1;
}

/**
 * Drops a client from the Queue
 * @param client		The client to drop from the queue
 * @return				0 if success or -1 if not in queue
 */
public DropFromQueue(client) {
	// find client cur position in queue
	new cur = FindInQueue(client);

	if (cur == -1) {
		// client was not found in the queue
		return -1;
	}
	else if (cur == g_QueueHead) {
		// dropping client from queue is same as deQueue, head moves forward on deletion
		g_QueueHead = (cur + 1) % g_QueueSize;
	} else {
		// shift all clients forward in queue
		new next, prev = cur == 0 ? g_QueueSize : cur - 1;
		while(cur != g_QueueTail) {
			next = (cur + 1) % g_QueueSize;
			if(next != g_QueueTail) {
				// move next client forward to cur
				g_ClientQueue[cur] = g_ClientQueue[next];
			}
			prev = cur;
			cur = next;
		}
		// tail needs to update as well
		g_QueueTail = prev;
	}
	return 0;
}

/**
 * Get queue length, does not validate clients in queue
 * @return			Queue length
*/
public GetQueueLength() {
	new i = g_QueueHead, count = 0;
	while (i != g_QueueTail) {
		count++;
		i = (i + 1) % g_QueueSize;
	}
	return count;
}

/**
 * Test if queue is empty
 * @return			true if queue is empty, false if queue is not empty
*/
public IsQueueEmpty() {
	return g_QueueTail == g_QueueHead;
}

/**
 * Fetch next client from queue
 * @return				Returns the next client from the queue or -1 if queue is empty.
 */
public DeQueue() {
	// check if queue is empty
	if (g_QueueTail == g_QueueHead)
		return -1;

	// head advances on dequeue
	new client = g_ClientQueue[g_QueueHead];
	g_QueueHead = (g_QueueHead + 1) % g_QueueSize;
	return client;
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
