csgo-multi-1v1
=======================================

This is home of my work-in-progress CS:GO multi-1v1 arena plugin.

Files/Libraries needed to compile:

- SMLib - http://www.sourcemodplugins.org/smlib/

### Building
The build process is managed by the Makefile.

		make          # builds the .smx file
		make clean    # clears .smx files, .zip files, map configs
		make package  # packages the files to multi1v1.zip

### Maps
Because the plugin must spawn players into the appropriate arenas, it is imperative we know where the spawn points are.
In addition, we have to know which spawns belong to which arena. Therefore, there are config files for each map that give this information.

To make life simpler, the script spawn_extractor.py automatically parses all .vmf files in the maps directory and puts the spawn points into the
output config directory. This command is built into the build process of the makefile.

Guidelines for making a multi-1v1 map:
- Create 1 arena and test it well, and only when are you happy copy it
- Create at least 9 arenas, I'd recommend at least 12, however. Any more than 16 is overkill.
- The players shouldn't be able to see each other on spawn
- Each arena should have exactly 2 spawns - one for CT's and one for T's


### Installation
If you only want the plugin, either download multi1v1.zip or build it yourself.
It should contain the plugin binary (plugins/multi1v1.smx), the default game config (cfg/sourcemod/mult1v1.cfg), and the map configs (configs/multi1v1).
Extract these to the appropriate folders.


### Using the statistics database

You should add a database named multi1v1_stats to your databases.cfg file like so:

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

Now you can do whatever you want with the stats. For example, to find the 3 users with the most wins:

	    SELECT accountID, name, kills FROM multi1v1_stats ORDER BY wins DESC LIMIT 3;

