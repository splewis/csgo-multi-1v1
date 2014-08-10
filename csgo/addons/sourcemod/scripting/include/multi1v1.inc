#if defined __MULTI1V1_INCLUDE__
  #endinput
#endif
#define __MULTI1V1_INCLUDE__

//************* WARNING*****************
//
// This file and its implementations
// are not finished, any code that relies
// on it WILL break in the future!
//
//************* WARNING******************

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
forward OnPreArenaRankingsSet(Handle:rankingQueue);

// Called after the plugin has finished putting players in the ranking queue
// for next round. The ranking queue is an adt array.
// You could reorder the players or add a new player here.
// Warning: if you add players check the maximum number of arenas
// using GetMaximumArenas.
forward OnPostArenaRankingsSet(Handle:rankingQueue);

// After a player's spawn is finished and they have been given their weapons.
// This may get called for the same client multiple times per round!
forward AfterPlayerSpawn(client);

// Called after a client they have been moved to the right team and teleported
// to the right spawn location. This will only be called once per round.
forward AfterPlayerSetup(client);

// When a round is decided. Not guaranteed to be called for
// a client every round.
forward OnRoundWon(winner, loser, bool:forceLoss);

// Called when a client's stats are received from the database.
forward OnStatsCached(client);

// Returns if a player is actively in an arena.
native bool:IsInArena(client);

// Prints a plugin-formatted message to a client.
native Multi1v1Message(client, const String:fmt[], any:...);

// Prints a plugin-formatted message to all clients.
native Multi1v1MessageToAll(const String:fmt[], any:...);

// Returns the maximum number of areans the map allows.
native any:GetMaximumArenas();

// Returns the active number of arenas.
native any:GetNumActiveArenas();

// Returns if a player is inside the waiting queue.
native bool:IsInWaitingQueue(client);

// Returns if a client has a rating stored.
native bool:HasStats(client);

// Functions for getting a players' 1v1-stats.
// You should confirm HasStats(client) is true before using any of these.
native Float:GetRating(client);
native GetRoundsPlayed(client);
native GetWins(client);
native GetLosses(client);

// Returns a client's arena number, or -1 if they aren't in an arena.
native any:GetArenaNumber(client);

// Returns the number of rounds a client has spent at arena 1.
native any:GetRoundsAtArena1(client);

// Returns the clients current opponent, or -1 if they have none.
native any:GetOpponent(client);

// Checks if the database is connected and valid.
native bool:HasDatabase();

// Returns a handle to the database connection. Please check HasDatabase before using this.
native Handle:GetDatabase();

// Gives a player their weapons according to a round type.
native GivePlayerArenaWeapons(client, RoundType:roundType);

// These are helpers you can use to supress normal plugin behavior.
// You can block rating changes and the chat messages about
// 'you are in arena %d facing off against %N' using these.
native BlockRatingChanges(client);
native UnblockRatingChanges(client);
native BlockChatMessages(client);
native UnblockChatMessages(client);

// Sets an offset value for arena numbering when giving
// players "Arena %d" team tags and the print outs
// about what arena the player is in. Is 0 by default.
// Set to 1 to make arena 1 show as arena 2, etc.
native SetArenaOffsetValue(value);

native Float:ELORatingDelta(Float:winner_rating, Float:loser_rating, Float:K);

native GetNumSpawnsInArena(arena);

native GetArenaSpawn(arena, team, Float:origin[3], Float:angle[3]);
