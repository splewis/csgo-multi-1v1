#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

/**
 * Returns if a client has a rating stored.
 */
native bool:HasStats(client);

/**
 * Functions for getting a players' 1v1-stats.
 * You should confirm HasStats(client) is true before using any of these.
 */
native Float:GetRating(client);
native Float:GetAwpRating(client);
native Float:GetPistolRating(client);
native Float:GetRifleRating(client);
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
