Multi-1v1 Web Interface
=========
Updates
----
1.3.6
-----------
* Switched from checking IP to using a password for Anti-Squatter.
* mysqli_begin_transaction did not exist in older versions of PHP. Changed to mysqli_autocommit.

Upcoming
* Add an option to disable getting the player's avatar/online status.
* Option to backup database before running Anti-Squatter

1.3.5
-----------
* Made a switch from MySQL to MySQLi
* [Anti-Squatter] - Now completes the job much faster.

1.3.2
-----------
* [Anti-Squatter] - Changed max_execution_time to 300 because PHP would stop the script before it was complete
* [Top 15 Players] - Limited the SQL query to only return 15 players making the page load much faster.
