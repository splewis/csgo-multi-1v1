Multi 1v1 Arena Web Stats Interface
=======================================

###Configuration
Edit config.inc.php with your appropriate database credentials, page title, Steam Web API key, and other settings. All descriptions are avaliable in the file.

**Note**: For players to be listed on the top 15 list, they will have to have played 200 or more games. This can be removed by changing **line 21** in includes/generatetopplayers.php with the following

```php
$run_query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating AND s2.wins+s2.losses > 0 $server_limit)+1 AS rank FROM $mysql_table AS s1 WHERE s1.wins+s1.losses > 0 $server_limit ORDER BY rating DESC LIMIT 0, 15";
```

###Setting up Anti-Squatter
Setting up the anti-squatter feature is fairly simple to set up.
All you have to do is add a password to $anti_squatter_pass in config.inc.php and create a cronjob set to run everyday with the command following command:
```bash
wget http://www.domain.com/stats/cron/antisquatter.php?p={YOUR_PASSWORD} && rm -rf antisquatter.php
```
**IMPORTANT***: Make sure your password is secure! The integrity of your stats depend on it.

###In-Game Stats
If you are using the included ``multi1v1_online_stats_viewer`` plugin, you should set the ``sm_multi1v1_stats_url``  to something like:
``http://www.domain.com/stats/redirect.php?id={USER}&serverid={SERVER}`` and ``sm_multi1v1_top_url`` to something like: ``http://www.domain.com/stats/redirect.php?serverid={SERVER}``.

These cvars should be set in ``cfg/multi1v1/multi1v1_online_stats_viewer.cfg``.

**Note**: Don't forget that if you have multiple servers with different IDs you have to set the URL with the serverid in the plugin config or else it will only the stats for serverID 0.

###Other Info
This web interface was a quick job that I randomly took up while I was learning PHP. I don't have a 1v1 server anymore but I will try and keep it updated when I can, but no promises. If you have any issues setting it up, feel free to email me at clayton@hiddenempire.org.
