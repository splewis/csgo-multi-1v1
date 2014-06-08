<?php
$mysql_host = 'localhost';
$mysql_user = 'username';
$mysql_pass = 'strongpassword';
$mysql_db = 'game_servers_database';

$page_title = "Multi 1v1 Arena";
$SteamAPI_Key = ""; //https://steamcommunity.com/dev/apikey

//The @ symbol removed error reporting from that line.
if (@!mysql_connect($mysql_host,$mysql_user,$mysql_pass) || @!mysql_select_db($mysql_db)){
	die('Cannot connect.');
}
?>
