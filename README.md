csgo-multi-1v1
=======================================

This is home of my work-in-progress CS:GO multi-1v1 arena plugin. It sets up any number of players in 1v1-situations on specially made maps and they fight in a ladder-type system. The winners move up, the losers go down.

### Extra Features
- Round types: there are 3 round types: rifle, pistol, and awp
- Player selection: players can select to allow pistol and awp rounds or ban them, rifle rounds are always allowed
- Player preference: players can also select a preference of round type, if player preferences match they will play that type
- Weapon selection: players can select their primary (i.e. their rifle) and their pistol
- Armor on pistol rounds: helmets are taken away, and kevlar is also taken away if the player selected an upgraded pistol
- Optional flashbangs: players can select to "allow flashbangs" - if both players allow them, they each get 1
- ELO ranking system: optionally, player statistics (overall ranking, rifle rating, pistol rating, awp rating, wins losses) can be stored in a database, see below for details

### Download
Download link: https://github.com/splewis/csgo-multi-1v1/releases

### Installation

If you only want the plugin, either download **multi1v1.zip** or build it yourself.
It should contain the plugin binary (**plugins/multi1v1.smx**) and the default game config (**cfg/sourcemod/mult1v1.cfg**).
Extract these to the appropriate folders, tweak mul1v1.cfg if you want.

### Building
The build process is managed by the Makefile.

		make          # builds the .smx file
		make clean    # clears .smx files, .zip files, map configs
		make package  # packages the files to multi1v1.zip

You will need SMLib to compile, get it at http://www.sourcemodplugins.org/smlib/,
I generally just add it to my sourcemod/scripting/include folder where sourcemod is installed.

### Maps
Guidelines for making a multi-1v1 map:
- Create 1 arena and test it well, and when are you happy copy it
- Create at least 9 arenas, I'd recommend at least 12, however. Any more than 16 is probably overkill.
- The players shouldn't be able to see each other on spawn
- Each arena should have exactly 2 spawns - one for CT's and one for T's (this is a condition that may be relaxed in the future)
- If you want to edit your map, it's easiest to delete all but 1 arena and re-copy them. Be warned this can cause issues with the game's lighting and clients may crash the first time they load the new map if they had downloaded the old one previously


### Using the statistics database

You should add a database named mult1v1 to your databases.cfg file like so:

	"multi1v1"
	{
		"driver"			"mysql"
		"host"				"123.123.123.123"	// localhost works too
		"database"			"multi1v1"
		"user"				"mymulti1v1server"
		"pass"				"strongpassword"
		"timeout"			"10"
		"port"			"3306"	// whatever port MySQL is set up on, 3306 is default
	}

To create a MySQL user and database on the database server, you can run:

		CREATE DATABASE multi1v1;
		CREATE USER 'mymulti1v1server'@'123.123.123.123' IDENTIFIED BY 'strongpassword';
		GRANT ALL PRIVILEGES ON multi1v1.* TO 'mymulti1v1server'@'123.123.123.123';
		FLUSH PRIVILEGES;

Make sure to change the IP, the username, and the password. You can change the database name 'multi1v1' if you want.

Schema:

		CREATE TABLE IF NOT EXISTS multi1v1_stats (
			accountID INT NOT NULL PRIMARY KEY default 0,
			auth varchar(64) NOT NULL default '',
			name varchar(64) NOT NULL default '',
			wins INT NOT NULL default 0,
			losses INT NOT NULL default 0,
			rating FLOAT NOT NULL default 1500.0,
			pistolRating FLOAT NOT NULL default 1500.0,
			rifleRating FLOAT NOT NULL default 1500.0,
			awpRating FLOAT NOT NULL default 1500.0);


Now you can do whatever you want with the stats. For example, to find the 3 users with the most wins:

	    SELECT accountID, name, kills FROM multi1v1_stats ORDER BY wins DESC LIMIT 3;

### Clientprefs Usage/Cookies

Player choices (round type preference, weapons) can be saved so they persist across maps for players. Installing sqlite should be sufficient for this.


