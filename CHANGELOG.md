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
