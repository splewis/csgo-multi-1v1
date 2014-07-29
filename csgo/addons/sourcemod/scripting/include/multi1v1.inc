#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

/**
 * Prints a plugin-formatted message to a client.
 */
native Multi1v1Message(client, const String:fmt[], any:...);

/**
 * Prints a plugin-formatted message to all clients.
 */
native Multi1v1MessageToAll(const String:fmt[], any:...);

/**
 * Returns the maximum number of areans the map allows.
 */
native any:GetMaximumArenas();

/**
 * Returns the active number of arenas.
 */
native any:GetNumActiveArenas();

/**
 * Returns if a player is inside the waiting queue.
 */
native bool:IsInWaitingQueue(client);

/**
 * Returns a handle to the (adt array) waiting queue.
 */
native Handle:GetWaitingQueue();

/**
 * Returns if a client has a rating stored.
 */
native bool:HasStats(client);

/**
 * Functions for getting a players' 1v1-stats.
 * You should confirm HasStats(client) is true before using any of these.
 */
native Float:GetRating(client);
native Float:GetRoundsPlayed(client);
native Float:GetWins(client);
native Float:GetLosses(client);
/**
 * Returns a client's arena number, or -1 if they aren't in an arena.
 */
native any:GetArenaNumber(client);

/**
 * Returns the number of rounds a client has spent at arena 1.
 */
native any:GetRoundsAtArena1(client);

/**
 * Returns the clients current opponent, or -1 if they have none.
 */
native any:GetOpponent(client);
