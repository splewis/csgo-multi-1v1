Multi 1v1 Arena Web Stats Interface
=======================================

###Configuration
Edit config.inc.php with your appropriate database credentials, page title, Steam Web API key, and other settings. All descriptions are avaliable in the file.

**Note**: For players to be listed on the top 15 list, they will have to have played 200 or more games. This can be removed by changing **line 16** in includes/generatetopplayers.php with the following

```php
$run_query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating AND s2.wins+s2.losses)+1 AS rank FROM $mysql_table AS s1 WHERE s1.wins+s1.losses ORDER BY rating DESC LIMIT 0, 15";
```

###Setting up Anti-Squatter
Setting up the anti-squatter feature is fairly simple to set up.
All you have to do is add a password to $anti_squatter_pass in config.inc.php and create a cronjob set to run everyday with the command following command:
```bash
wget http://www.domain.com/stats/cron/antisquatter.php?p={YOUR_PASSWORD} && rm -rf antisquatter.php
```

###In-Game Stats
"sm_multi1v1_stats_url" should be set to something like "http://www.domain.com/stats/redirect.php?id=". Do this in the multi1v1.cfg config file.

###Web Interface
This web interface was a quick job that I randomly took up while I was learning PHP. I will try and keep it updated when I can, but no promises. If you have any issues setting it up, feel free to email me at clayton@hiddenempire.org
