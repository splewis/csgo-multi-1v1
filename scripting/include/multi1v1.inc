#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

// The different round types
enum RoundType {
    RoundType_NoPreference = -1, // not an actual round type, but a preference-only identifier
    RoundType_Rifle = 0,
    RoundType_Awp = 1,
    RoundType_Pistol = 2
};

// Called before the plugin has put any players in the ranking queue.
// It is always empty at this call.
// The ranking queue is an adt array.
forward Multi1v1_OnPreArenaRankingsSet(Handle rankingQueue);

// Called after the plugin has finished putting players in the ranking queue
// for next round. The ranking queue is an adt array.
// You could reorder the players or add a new player here.
// Warning: if you add players check the maximum number of arenas
// using GetMaximumArenas.
forward Multi1v1_OnPostArenaRankingsSet(Handle rankingQueue);

// Called after the round-post stary is finished and all players + arenas
// are setup and ready to go.
forward Multi1v1_OnArenasReady();

// After a player's spawn is finished and they have been given their weapons.
// This may get called for the same client multiple times per round!
forward Multi1v1_AfterPlayerSpawn(int client);

// Called after a client they have been moved to the right team and teleported
// to the right spawn location. This will only be called once per round.
forward Multi1v1_AfterPlayerSetup(int client);

// When a round is decided. Not guaranteed to be called for
// a client every round.
forward Multi1v1_OnRoundWon(int winner, int loser, bool forceLoss);

// Called when a client's stats are received from the database.
forward Multi1v1_OnStatsCached(int client);

// Called when a player finishes going through the weapons menu.
forward Multi1v1_OnGunsMenuDone(int client);

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

// Functions for getting a players' 1v1-stats.
// You should confirm HasStats(client) is true before using any of these.
// These are only valid for connected clients.
native float Multi1v1_GetRating(int client);
native float Multi1v1_GetRifleRating(int client);
native float Multi1v1_GetAwpRating(int client);
native float Multi1v1_GetPistolRating(int client);
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
native void Multi1v1_GivePlayerArenaWeapons(int client, RoundType roundType);
native void Multi1v1_GivePlayerArenaWeaponsNoNades(int client, RoundType roundType);

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
    MarkNativeAsOptional("Multi1v1_GetAwpRating");
    MarkNativeAsOptional("Multi1v1_GetRifleRating");
    MarkNativeAsOptional("Multi1v1_GetPistolRating");
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
    MarkNativeAsOptional("Multi1v1_GivePlayerArenaWeaponsNoNades");
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
}
#endif
