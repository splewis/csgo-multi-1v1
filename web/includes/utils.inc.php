<?php
require_once 'config.inc.php';

function GetCommunityID($steamid) {
	$steamidexplode = explode(':', str_replace('STEAM_', '' ,$steamid));
	$commid = substr(bcadd(bcadd('76561197960265728', $steamidexplode['1']), bcmul($steamidexplode['2'], '2')),0, 17);
	return $commid;
}

function getAvatar($commid) {
	global $SteamAPI_Key;
	$url = 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.$SteamAPI_Key.'&steamids='.$commid;

	$cURL = curl_init();
	curl_setopt($cURL, CURLOPT_URL, $url);
	curl_setopt($cURL, CURLOPT_HTTPGET, true);
	curl_setopt($cURL, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($cURL, CURLOPT_HTTPHEADER, array(
		'Content-Type: application/json',
		'Accept: application/json'
	));
	$result = curl_exec($cURL);
	$json = json_decode($result, true);

	foreach ($json['response']['players'] as $item) {
		return $item['avatarfull'];
	}
}

function getPlayerState($commid) {
	global $SteamAPI_Key;
	$url = 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.$SteamAPI_Key.'&steamids='.$commid;

	$cURL = curl_init();
	curl_setopt($cURL, CURLOPT_URL, $url);
	curl_setopt($cURL, CURLOPT_HTTPGET, true);
	curl_setopt($cURL, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($cURL, CURLOPT_HTTPHEADER, array(
		'Content-Type: application/json',
		'Accept: application/json'
	));
	$result = curl_exec($cURL);
	$json = json_decode($result, true);

	foreach($json['response']['players'] as $item) {
		if($item['personastate'] == 0){
			return "offline";
		}else{
			return "online";
		}
	}
}

function isPlayerActive($lastTime) {
	$elapsedtime_days = number_format((float)(time() - $lastTime) / 86400, 2, '.', '');
	global $days_until_inactivity;
	if ($elapsedtime_days > $days_until_inactivity && $lastTime != 0) {
		return 'true';
	}
}
?>
