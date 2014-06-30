Multi 1v1 Arena Web Stats Interface
=======================================

###Configuration
Edit config.inc.php with your appropriate database credentials, page title, Steam Web API key, and other settings. All descriptions are avaliable in the file.

###Setting up Anti-Squatter
Setting up the anti-squatter feature is fairly simple if your host supports it.
All you have to do is create a cronjob set to run everyday with the command following command:
```bash
wget http://www.domain.com/stats/cron/antisquatter.php && rm -rf antisquatter.php
```
What that command does is request the antisquatter.php file and then deletes it.
The anti-squatter script has a feature that prevents the file from being run on a computer other than the local machine. It does this by checking the IP of the connecting machine and comparing it with the IP of the local machine. If the IPs are the same, the script runs. This might not always work. If you are having problems, feel free to email me.

###In-Game Stats
A feature for this was not included in the base plugin, but a way to do it has been mentioned [here](https://forums.alliedmods.net/showpost.php?p=2147002&postcount=10).
Replace the URL with something like "http://www.domain.com/stats/redirect.php?id=".

###Web Interface
This web interface was a quick job that I randomly took up while I was learning PHP. I will try and keep it updated when I can, but no promises. If you have any issues setting it up, feel free to email me at clayton@hiddenempire.org
