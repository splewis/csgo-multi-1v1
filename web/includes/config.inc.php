<?php
$mysql_host = 'localhost';
$mysql_user = 'root';
$mysql_pass = '';
$mysql_db = 'multi1v1';

$page_title = "Multi 1v1 Arena";
$SteamAPI_Key = ""; //https://steamcommunity.com/dev/apikey

if (@!mysql_connect($mysql_host,$mysql_user,$mysql_pass) || @!mysql_select_db($mysql_db)){
	die('Cannot connect.');
}
?>
