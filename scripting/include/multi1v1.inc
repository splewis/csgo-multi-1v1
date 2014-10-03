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
forward OnPreArenaRankingsSet(Handle rankingQueue);

// Called after the plugin has finished putting players in the ranking queue
// for next round. The ranking queue is an adt array.
// You could reorder the players or add a new player here.
// Warning: if you add players check the maximum number of arenas
// using GetMaximumArenas.
forward OnPostArenaRankingsSet(Handle rankingQueue);

// Called after the round-post stary is finished and all players + arenas
// are setup and ready to go.
forward OnArenasReady();

// After a player's spawn is finished and they have been given their weapons.
// This may get called for the same client multiple times per round!
forward AfterPlayerSpawn(int client);

// Called after a client they have been moved to the right team and teleported
// to the right spawn location. This will only be called once per round.
forward AfterPlayerSetup(int client);

// When a round is decided. Not guaranteed to be called for
// a client every round.
forward OnRoundWon(int winner, int loser, bool forceLoss);

// Called when a client's stats are received from the database.
forward OnStatsCached(int client);

// Called when a player finishes going through the weapons menu.
forward OnGunsMenuDone(int client);

// Returns if a player is actively in an arena.
native bool IsInArena(int client);

// Prints a plugin-formatted message to a client.
native void Multi1v1Message(int client, const char format[], any:...);

// Prints a plugin-formatted message to all clients.
native void Multi1v1MessageToAll(const char format[], any:...);

// Returns the maximum number of areans the map allows.
native int GetMaximumArenas();

// Returns the active number of arenas.
native int GetNumActiveArenas();

// Returns if a player is inside the waiting queue.
native bool IsInWaitingQueue(int client);

// Returns if a client has a rating stored.
native bool HasStats(int client);

// Functions for getting a players' 1v1-stats.
// You should confirm HasStats(client) is true before using any of these.
// These are only valid for connected clients.
native float GetRating(int client);
native float GetRifleRating(int client);
native float GetAwpRating(int client);
native float GetPistolRating(int client);
native int GetRoundsPlayed(int client);
native int GetWins(int client);
native int GetLosses(int client);

// Returns a client's arena number, or -1 if they aren't in an arena.
native int GetArenaNumber(int client);

// Returns players in arenas, or -1 if there is no player.
native int GetArenaPlayer1(int arena);
native int GetArenaPlayer2(int arena);

// Returns the number of rounds a client has spent at arena 1.
native int GetRoundsAtArena1(int client);

// Returns the clients current opponent, or -1 if they have none.
native int GetOpponent(int client);

// Checks if the database is connected and valid.
native bool HasDatabase();

// Returns a clone of the database handle.
// You should check HasDatabase before calling this.
native Handle GetDatabase();

// Gives a player their weapons according to a round type.
native void GivePlayerArenaWeapons(int client, RoundType roundType);
native void GivePlayerArenaWeaponsNoNades(int client, RoundType roundType);

// These are helpers you can use to supress normal plugin behavior.
// You can block rating changes and the chat messages about
// 'you are in arena %d facing off against %N' using these.
native void BlockRatingChanges(int client);
native void UnblockRatingChanges(int client);
native void BlockChatMessages(int client);
native void UnblockChatMessages(int client);
native void BlockMVPStars(int client);
native void UnblockMVPStars(int client);
native void BlockArenaDones(int arena);
native void UnblockArenaDones(int arena);

// Sets an offset value for arena numbering when giving
// players "Arena %d" team tags and the print outs
// about what arena the player is in. Is 0 by default.
// Set to 1 to make arena 1 show as arena 2, etc.
native void SetArenaOffsetValue(int value);

// Returns the rating delta from a winner/loser matchup. This
// will always be positive.
native float ELORatingDelta(float winner_rating, float loser_rating, float K);

// Returns the number of spawns (per team) in an arena.
// If one team has less spawns than the other team,
// the smaller of the two will be returned.
native int GetNumSpawnsInArena(int arena);

// Gets a spawn point/angle pair from an arena for a given team.
native void GetArenaSpawn(int arena, int team, float origin[3], float angle[3]);

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
    MarkNativeAsOptional("IsInArena");
    MarkNativeAsOptional("GetMaximumArenas");
    MarkNativeAsOptional("GetNumActiveArenas");
    MarkNativeAsOptional("IsInWaitingQueue");
    MarkNativeAsOptional("HasStats");
    MarkNativeAsOptional("GetRating");
    MarkNativeAsOptional("GetAwpRating");
    MarkNativeAsOptional("GetRifleRating");
    MarkNativeAsOptional("GetPistolRating");
    MarkNativeAsOptional("GetArenaNumber");
    MarkNativeAsOptional("GetArenaPlayer1");
    MarkNativeAsOptional("GetArenaPlayer2");
    MarkNativeAsOptional("GetRoundsAtArena1");
    MarkNativeAsOptional("GetOpponent");
    MarkNativeAsOptional("GetRoundsPlayed");
    MarkNativeAsOptional("GetWins");
    MarkNativeAsOptional("GetLosses");
    MarkNativeAsOptional("HasDatabase");
    MarkNativeAsOptional("GivePlayerArenaWeapons");
    MarkNativeAsOptional("GivePlayerArenaWeaponsNoNades");
    MarkNativeAsOptional("Multi1v1Message");
    MarkNativeAsOptional("Multi1v1MessageToAll");
    MarkNativeAsOptional("BlockRatingChanges");
    MarkNativeAsOptional("UnblockRatingChanges");
    MarkNativeAsOptional("BlockChatMessages");
    MarkNativeAsOptional("UnblockChatMessages");
    MarkNativeAsOptional("BlockMVPStars");
    MarkNativeAsOptional("UnblockMVPStars");
    MarkNativeAsOptional("BlockArenaDones");
    MarkNativeAsOptional("UnblockArenaDones");
    MarkNativeAsOptional("SetArenaOffsetValue");
    MarkNativeAsOptional("ELORatingDelta");
    MarkNativeAsOptional("GetNumSpawnsInArena");
    MarkNativeAsOptional("GetArenaSpawn");
}
#endif
