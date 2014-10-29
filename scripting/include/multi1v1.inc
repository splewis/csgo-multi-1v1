#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

#define WEAPON_NAME_LENGTH 32

/**
 * Called right before the plugin puts players into the ranking queue.
 * This is the best place to put players into the front of the queue.
 *
 * @param rankingQueue empty adt array to be used for arena placement
 * @noreturn
 */
forward Multi1v1_OnPreArenaRankingsSet(Handle rankingQueue);

/**
 * Called after the plugin is done putting players into the ranking queue.
 *
 * @param rankingQueue adt array of the players in order of their arena placement
 * @noreturn
 */
forward Multi1v1_OnPostArenaRankingsSet(Handle rankingQueue);

/**
 * Called when all players have been placed into their arena.
 * GetArenaNumber is now valid to call for clients.
 *
 * @noreturn
 */
forward Multi1v1_OnArenasReady();

/**
 * Called after a player's spawn setup (e.g. giving weapons) is processed.
 *
 * @param client Player's index.
 * @noreturn
 */
forward Multi1v1_AfterPlayerSpawn(int client);

/**
 * Called after core player setup functions (teleporting, printing their opponent to chat)
 * are processed.
 *
 * @param client Player's index.
 * @noreturn
 */
forward Multi1v1_AfterPlayerSetup(int client);

/**
 * Called when an arena finishes it's fighting.
 *
 * @param winner Winner's client index.
 * @param loser Loser's client index.
 * @param forceLoss Whether it was a "force loss" for both payers (e.g. time ran out)
 * @noreturn
 */
forward Multi1v1_OnRoundWon(int winner, int loser, bool forceLoss);

/**
 * Called when a client's stats have been fetched successfully.
 *
 * @param client Player's index.
 * @noreturn
 */
forward Multi1v1_OnStatsCached(int client);

/**
 * Called after a player finishes going through the weapons menu.
 *
 * @param client Player's index.
 * @noreturn
 */
forward Multi1v1_OnGunsMenuDone(int client);

/**
 * Called each map start after the standard round types have been added.
 *
 * @noreturn
 */
forward Multi1v1_OnRoundTypesAdded();

// Returns if a player is actively in an arena.
native bool Multi1v1_IsInArena(int client);

// Prints a plugin-formatted message to a client.
native void Multi1v1_Message(int client, const char format[], any:...);

// Prints a plugin-formatted message to all clients.
native void Multi1v1_MessageToAll(const char format[], any:...);

// Returns the maximum number of areans the map allows.
native int Multi1v1_GetMaximumArenas();

// Returns the active number of arenas.
native int Multi1v1_GetNumActiveArenas();

// Returns if a player is inside the waiting queue.
native bool Multi1v1_IsInWaitingQueue(int client);

// Returns if a client has a rating stored.
native bool Multi1v1_HasStats(int client);

// Functions for getting/setting a players' 1v1-stats.
// You should confirm HasStats(client) is true before using any of these.
// These are only valid for connected clients.
native void Multi1v1_SetRating(int client, float rating);
native float Multi1v1_GetRating(int client, int roundType=-1);
native int Multi1v1_GetRoundsPlayed(int client);
native int Multi1v1_GetWins(int client);
native int Multi1v1_GetLosses(int client);

// Returns a client's arena number, or -1 if they aren't in an arena.
native int Multi1v1_GetArenaNumber(int client);

// Returns players in arenas, or -1 if there is no player.
native int Multi1v1_GetArenaPlayer1(int arena);
native int Multi1v1_GetArenaPlayer2(int arena);

// Returns the number of rounds a client has spent at arena 1.
native int Multi1v1_GetRoundsAtArena1(int client);

// Returns the clients current opponent, or -1 if they have none.
native int Multi1v1_GetOpponent(int client);

// Checks if the database is connected and valid.
native bool Multi1v1_HasDatabase();

// Returns a clone of the database handle.
// You should check HasDatabase before calling this.
native Handle Multi1v1_GetDatabase();

// Gives a player their weapons according to a round type.
native void Multi1v1_GivePlayerArenaWeapons(int client, int roundType);
// native void Multi1v1_GivePlayerArenaWeaponsNoNades(int client, RoundType roundType);

// These are helpers you can use to supress normal plugin behavior.
// You can block rating changes and the chat messages about
// 'you are in arena %d facing off against %N' using these.
native void Multi1v1_BlockRatingChanges(int client);
native void Multi1v1_UnblockRatingChanges(int client);
native void Multi1v1_BlockChatMessages(int client);
native void Multi1v1_UnblockChatMessages(int client);
native void Multi1v1_BlockMVPStars(int client);
native void Multi1v1_UnblockMVPStars(int client);
native void Multi1v1_BlockArenaDones(int arena);
native void Multi1v1_UnblockArenaDones(int arena);

// Sets an offset value for arena numbering when giving
// players "Arena %d" team tags and the print outs
// about what arena the player is in. Is 0 by default.
// Set to 1 to make arena 1 show as arena 2, etc.
native void Multi1v1_SetArenaOffsetValue(int value);

// Returns the rating delta from a winner/loser matchup. This
// will always be positive.
native float Multi1v1_ELORatingDelta(float winner_rating, float loser_rating, float K);

// Returns the number of spawns (per team) in an arena.
// If one team has less spawns than the other team,
// the smaller of the two will be returned.
native int Multi1v1_GetNumSpawnsInArena(int arena);

// Gets a spawn point/angle pair from an arena for a given team.
native void Multi1v1_GetArenaSpawn(int arena, int team, float origin[3], float angle[3]);

// Gets the rifle the client has selected in the weapons menu.
native void Multi1v1_GetRifleChoice(int client, char buffer[WEAPON_NAME_LENGTH]);

// Gets the pistol the client has selected in the weapons menu.
native void Multi1v1_GetPistolChoice(int client, char buffer[WEAPON_NAME_LENGTH]);

typedef RoundTypeWeaponHandler = function void (int client);
typedef RoundTypeMenuHandler = function void (int client);

// Registers a new round type by the plugin.
native int Multi1v1_AddRoundType(const char displayName[], const char internalName[],
                                 RoundTypeWeaponHandler weaponsHandler,
                                 RoundTypeMenuHandler menuHandler,
                                 bool optional=true, bool ranked=false);

// Clears all registered round types.
native void Multi1v1_ClearRoundTypes();

// Adds the standard, default round types.
native void Multi1v1_AddStandardRounds();

// Returns the unique identifier (an index) of a round type given its internal name.
native int Multi1v1_GetRoundTypeIndex(const char internalName[]);

// Returns menu control to the menu controller.
// This is intended to be called from within a RoundTypeMenuHandler in the guns menu
// once a client has picked an option.
native void Multi1v1_ReturnMenuControl(int client);

// Helper function to ass as a mneuHandler when the client doesn't have any choices to make.
public void Multi1v1_NullChoiceMenu(int client) {
    Multi1v1_ReturnMenuControl(client);
}

// Returns the current round type in an arena.
native int Multi1v1_GetCurrentRoundType(int arena);

public SharedPlugin:__pl_multi1v1 = {
    name = "multi1v1",
    file = "multi1v1.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_multi1v1_SetNTVOptional() {
    MarkNativeAsOptional("Multi1v1_IsInArena");
    MarkNativeAsOptional("Multi1v1_GetMaximumArenas");
    MarkNativeAsOptional("Multi1v1_GetNumActiveArenas");
    MarkNativeAsOptional("Multi1v1_IsInWaitingQueue");
    MarkNativeAsOptional("Multi1v1_HasStats");
    MarkNativeAsOptional("Multi1v1_GetRating");
    MarkNativeAsOptional("Multi1v1_GetArenaNumber");
    MarkNativeAsOptional("Multi1v1_GetArenaPlayer1");
    MarkNativeAsOptional("Multi1v1_GetArenaPlayer2");
    MarkNativeAsOptional("Multi1v1_GetRoundsAtArena1");
    MarkNativeAsOptional("Multi1v1_GetOpponent");
    MarkNativeAsOptional("Multi1v1_GetRoundsPlayed");
    MarkNativeAsOptional("Multi1v1_GetWins");
    MarkNativeAsOptional("Multi1v1_GetLosses");
    MarkNativeAsOptional("Multi1v1_HasDatabase");
    MarkNativeAsOptional("Multi1v1_GivePlayerArenaWeapons");
    MarkNativeAsOptional("Multi1v1_Message");
    MarkNativeAsOptional("Multi1v1_MessageToAll");
    MarkNativeAsOptional("Multi1v1_BlockRatingChanges");
    MarkNativeAsOptional("Multi1v1_UnblockRatingChanges");
    MarkNativeAsOptional("Multi1v1_BlockChatMessages");
    MarkNativeAsOptional("Multi1v1_UnblockChatMessages");
    MarkNativeAsOptional("Multi1v1_BlockMVPStars");
    MarkNativeAsOptional("Multi1v1_UnblockMVPStars");
    MarkNativeAsOptional("Multi1v1_BlockArenaDones");
    MarkNativeAsOptional("Multi1v1_UnblockArenaDones");
    MarkNativeAsOptional("Multi1v1_SetArenaOffsetValue");
    MarkNativeAsOptional("Multi1v1_ELORatingDelta");
    MarkNativeAsOptional("Multi1v1_GetNumSpawnsInArena");
    MarkNativeAsOptional("Multi1v1_GetArenaSpawn");
    MarkNativeAsOptional("Multi1v1_GetRifleChoice");
    MarkNativeAsOptional("Multi1v1_GetPistolChoice");
    MarkNativeAsOptional("Multi1v1_AddRoundType");
    MarkNativeAsOptional("Multi1v1_ClearRoundTypes");
    MarkNativeAsOptional("Multi1v1_ReturnMenuControl");
    MarkNativeAsOptional("Multi1v1_GetRoundTypeIndex");
    MarkNativeAsOptional("Multi1v1_AddStandardRounds");
    MarkNativeAsOptional("Multi1v1_GetCurrentRoundType");
}
#endif
