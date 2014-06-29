<?php
/**
 * =============================================================================
 * @author Clayton
 * @version 1.3.2
 * @link https://github.com/supimfuzzy/csgo-multi-1v1
 * =============================================================================
 */

$mysql_host = 'localhost:3306';
$mysql_user = 'root';
$mysql_pass = '';
$mysql_db = '';
$mysql_table = 'multi1v1_stats'; //Default table set by game plugin. Do not change this if you don't know what you are doing.

$page_title = "Multi 1v1 Arena";
$SteamAPI_Key = ""; //https://steamcommunity.com/dev/apikey
$antisquatter_rate_loss = 40; //Rate loss constant. A higher value equals a higher rate loss per day of inactivity.
$log_antisquatter = true; //Keep IP logs and the number of player stats changes. For debugging and testing purposes only.
$days_until_inactivity = 7; //Number of days before a player is given an inactive status.

if (!mysql_connect($mysql_host,$mysql_user,$mysql_pass) || !mysql_select_db($mysql_db)){
	die('Cannot connect.');
}
?>
