csgo1v1
=======================================

This is home of my work-in-progress CS:GO multi-1v1 arena plugin.

Files/Libraries needed to compile:

-  Spawn point manager - https://forums.alliedmods.net/showthread.php?t=147542
-  SMLib - http://www.sourcemodplugins.org/smlib/

### Building
The build process is managed by the Makefile.

		make          # builds the .smx file
		make clean    # clears .smx files, .zip files
		make package  # packages the essential plugin things into csgo1v1-plugin and all server files to csgo1v1-all

### Installation
If you only want the plugin, either download csgo1v1-plugin.zip or build it yourself.
It should contain the plugin binary, and the default config file.
Extract both to the appropriate folders.


Note that map-specific config files are in the addons/sourcemod/configs/csgo1v1 folder.

Also make sure to look at cfg/sourcemod/csgo1v1.cfg if you want to edit any game settings.


### Using the statistics database

You should add a database named csgo1v1_stats to your databases.cfg file like so:

	"csgo1v1_stats"
	{
		"driver"			"mysql"
		"host"				"123.123.123.123"	// localhost works too
		"database"			"csgo1v1"
		"user"				"mycsgo1v1server"
		"pass"				"strongpassword"
		"timeout"			"10"
		"port"			"3306"	// whatever port MySQL is set up on, 3306 is default
	}

To create a MySQL user and database on the database server, you can run:

		CREATE DATABASE csgo1v1;
		CREATE USER 'mycsgo1v1server'@'123.123.123.123' IDENTIFIED BY 'strongpassword';
		GRANT ALL PRIVILEGES ON csgo1v1.* TO 'mycsgo1v1server'@'123.123.123.123';
		FLUSH PRIVILEGES;

Make sure to change the IP, the username, and the password. You can change the database name 'csgo1v1' if you want.

Now you can do whatever you want with the stats. For example, to find the 3 users with the most wins:

	    SELECT accountID, name, kills FROM csgo1v1_stats ORDER BY wins DESC LIMIT 3;

