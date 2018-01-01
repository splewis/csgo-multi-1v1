1.1.8:
- change ``Multi1v1_OnRoundTypesAdded`` to be called in OnPluginStart instead of OnMapStart, this fixes a cookie issue where clientprefs cookies aren't always saved
- add support for "rifle_preference" and "pistol_preference" in customrounds.cfg file

1.1.7:
- no significant changes

1.1.6:
- cleanup include for new syntax more (thanks headline22)
- fix for 2017/08/17 update introducing a change breaking arena muting (thanks Kinsi and Technoblazed)

1.1.5:
- update russian translations
- update chinese translations
- move auto-update url off public dropbox urls
- cleanup multi1v1 include [thanks headline22]

1.1.4:
- add sm_autospec command for players to automatically spectate active arenas while dead
- give the proper knife (weapon_knife_t) to players on the T side
- update chinese translations (thanks 872517414)
- add hint text messages when an opponent leaves in an active arena or when you have no opponent
- replace sv_alltalk with new cvars in game_cvars.cfg

1.1.3:
- update spawn-arena-finding code to work post 2/17/2016 update
- add cvar ``sm_multi1v1_auto_create_tables`` (default 1) to allow disabling auto MySQL table creation/updates
- add "health" field in custom round configs (defaults to 100)

1.1.2:
- update pugsetup integration to pugsetup 2.0.0 api
- add multi1v1_spawninfo command for dumping spawn info
- add cvar sm_multi1v1_randomize_arena_order to randomize arena order

1.1.1:
- correct ``sm_multi1v1_mute_other_arenas`` behavior to not mute gunshots when the plugin is disabled
- update polish translations (thanks spyrek)
- update chinese translations (thanks 872517414)
- remove some extraneous debug statements accidentally left in 1.1.0

1.1.0:
- correct a crash-causing issue on recent sourcemod builds when stats were enabled (it was a deadlock caused by SQL_SetCharSet happening inside a lock)
- the weapons menu has been reworked to have toggle options per-round-type rather than a series of pages
- add ``sm_reloadroundtypes`` admin command for reloading all round types (normally only happens on map changes)
- block "regroup" radio command block and don't block radio commands when plugin is diabled
- add ``sm_multi1v1_mute_other_arenas`` cvar (default 1) that mutes gunshots from arenas other than a client's closest one
- adjust database stats to be enabled by default
- remove cvar ``sm_multi1v1_database_name``
- add a cookie for clients to hide stats (``multi1v1_hidestats``)
- add cvar ``sm_multi1v1_use_assists`` for displaying rounds in arena 1 via the assists on the scoreboard
- correct pistol-giving behavior on rifle rounds to match ``sm_multi1v1_pistol_behavior`` description
- add norwegian translations (thanks bawls)

1.0.2:
- correct multi1v1_flashbangs addon not giving flashbangs correctly

1.0.1:
- Add cvar ``sm_multi1v1_enabled`` (default 1)
- Add forward ``Multi1v1_OnSpawnsFound``
- Add support for serverid (default 0) within the stats webpage and within the top url in the online_stats_viewer plugin
- In addition to other plugins adding round types, simple round types can be defined in the new config file addons/sourcemod/configs/multi1v1_customrounds.cfg

1.0.0:
 - **move to sourcemod 1.7 transitional syntax and API**
 - weapon lists are now stored in configs/multi1v1_weapons.cfg rather than hardcoded into the plugin
 - new cvars: ``sm_multi1v1_exec_default_config``, ``sm_multi1v1_db_name``, ``sm_multi1v1_pistol_behavior``, ``sm_multi1v1_default_pistol``, ``sm_multi1v1_database_server_id`` (I **strongly** suggest deleting cfg/multi1v1/multi1v1.cfg and letting it be regenerated)
 - ``sm_multi1v1_guns_menu_first_connect`` has been removed and replaced with ``sm_multi1v1_menu_open_behavior``, which adds a new behavior
 - separate ratings are calculated for each round type - the overall rating is unaffected and always changed
 - translation support (current languages: Swedish, Portuguese, German, Polish, Chinese)
 - external plugin API available now, see [multi1v1.inc](scripting/include/multi1v1.inc).
 - if using the ``sm_stats`` command, clients are notified if they have ``cl_disablehtmlmotd 1`` on
 - significantly improved performance and reliability of how player statistics are fetched
 - chat messages have been colorized and formatted a bit differently now
 - players will receive their skins regardless of the team they are on (thanks to h3bus for the input on teamswitching when giving weapons)
 - failsafe added to force end rounds that have gone on for longer than the round time (corrects some warmup related issues)
 - when multiple players join the game, they will be first sorted by order (determining who gets to join), then by rating (the initial arena placement within the new players for this round)
 - updated table schema, rifle/awp/pistol ratings, the table will be automatically updated if upgrading from a previous version
 - one table change is the addition of ``serverID``, a tag on each player record in the ``multi1v1_stats`` table, set by ``sm_multi1v1_database_server_id``
 - the ``sm_stats`` command is not in the base plugin anymore, but in the ``multi1v1_online_stats_viewer`` plugin
 - the format for ``sm_multi1v1_stats_url`` has changed, use {USER} and {SERVER} directly in your cvar, and they will get replaced with the appropriate values (remember this cvar is part of ``multi1v1_online_stats_viewer`` rather than the base ``multi1v1`` plugin now)
 - new client command: ``sm_hidestats`` will hide any stats-related messages from being printed into chat to a player (it toggles on/off)
 - round types can be determined and changed at runtime, see [multi1v1.inc](scripting/include/multi1v1.inc) include

0.5.2:
 - correct bug where spawn clustering were not being paired together correctly
 - add cvar `sm_multi1v1_guns_menu_first_connect` for displaying the guns menu if a players' clientprefs cookies aren't set

0.5.1:
 - correct a error in the waiting queue (used when the arenas were all full) where players were never dropped from the queue on disconnect

0.5.0:
 - maps can have multiple spawns per arena per player now. Most old maps should continue to function normally, but you should test them
 - new cvar `sm_multi1v1_verbose_spawns` (default 0) controls logging information about spawns read on map start, use this when testing a map!

0.4.1:
 - remove placement match rating system

0.4.0:
 - add `lastTime` field to the database to track last time the player connected, and cvar `sm_multi1v1_record_times` to control if this feature is used.
  If you are upgrading from a previous version you will need to run the following command to update your tables:

 	 - ALTER TABLE multi1v1_stats ADD lastTime INT NOT NULL default 0;

 - change default cvar values to be as simplistic as possible (stats off by default, updater off by default)
 - added built-in `sm_stats` and `sm_rank` that take a player to a site defined by new cvar `sm_multi1v1_stats_url`
 - added a cvar `sm_multi1v1_block_radio` to optionally block radio commands
 - remove `sm_multi1v1_minrounds` cvar because: when using 1 server it's unnecessary, when using multiple servers a players' row can be deleted by another server while playing!
 - remove `sm_multi1v1_default_rating` as it is my intention to provide a consistent experience for this plugin's usage
 - when players first join they are considered unranked until they complete 20 rounds where their rating changes more quickly, but is invisible

0.3.2:
- fixed a typo causing serious crash issues on table creation for plugin startup
- removed an extraneous printout when letting time run out
- band-aid on the 1st round ending too early and causing some player to get a force loss for letting time run out

0.3.1:
- make updater plugin not required (thanks versatile_bfg)
- revert to comparing boolean convars as ints so they work properly

0.3.0:
- initial public release
