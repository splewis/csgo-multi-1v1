#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

/**
 * Returns if a client has a rating stored.
 */
native bool:HasRating(client);

/**
 * Returns a client's rating.
 */
native Float:GetRating(client);

/**
 * Returns a client's arena number, or -1 if they aren't in an arena.
 */
native any:GetArenaNumber(client);

/**
 * Returns the number of rounds a client has spent at arena 1.
 */
native any:GetRoundsAtArena1(client);
