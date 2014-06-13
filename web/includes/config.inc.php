<?php
/**
 * =============================================================================
 * @author Clayton
 * @version 1.2.0
 * @link https://github.com/supimfuzzy/csgo-multi-1v1
 * =============================================================================
 */

$mysql_host = 'localhost:3306';
$mysql_user = 'root';
$mysql_pass = '';
$mysql_db = '';

$page_title = "Multi 1v1 Arena";
$SteamAPI_Key = ""; //https://steamcommunity.com/dev/apikey
$elo_rate_loss = 40; //Rate loss constant. A higher value equals a higher rate loss per day of inactivity.
$log_antisquatter = true; //Keep IP logs and the number of player stats changes. For debugging and testing purposes only.
$days_until_inactivity = 7; //Number of days before a player is given an inactive status.

//The @ symbol removed error reporting from that line.
if (!mysql_connect($mysql_host,$mysql_user,$mysql_pass) || !mysql_select_db($mysql_db)){
	die('Cannot connect.');
}
?>
