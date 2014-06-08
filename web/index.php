<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<?php 
		require 'includes/connect.inc.php';
		echo "<title>$page_title</title>";
		$time = microtime();
		$time = explode(' ', $time);
		$time = $time[1] + $time[0];
		$start = $time;
		error_reporting(0);
?>
<link rel="shortcut icon" type="image/x-icon" href="images/favicon.ico">
<link href="css/style.css" rel="stylesheet" type="text/css" media="all">
</head>
<body>
<div class="wrapper">
	<div class="maincontent">
		<div class="container">
			<div class="everything">
				<?php
				if(!isset($_GET['id']) && empty($_GET['id'])){
					echo "<h3>$page_title</h3>";
					echo "<div class=\"searchnoinfo\">";
				}else{
					echo "<div class=\"search\">";
				}
			?>
				<form action="search.php" method="GET">
					<h2>Search player stats:</h1><input type="text" name="searchquery">
						<input type="submit" value="Submit">
		</form>
				</div>
							<?php
								if(isset($_GET['id']) && !empty($_GET['id'])){
								$searchquery = htmlentities($_GET['id']);
									@$query = "SELECT * FROM multi1v1_stats WHERE accountID='$searchquery'";
								if(mysql_fetch_row(mysql_query($query))>0){
									if(@$query_run = mysql_query($query)){
										while ($row = mysql_fetch_assoc($query_run)){
											$accountID = $row['accountID'];
											$auth = $row['auth'];
											$name = $row['name'];
											$wins = $row['wins'];
											$losses = $row['losses'];
											$rating = $row['rating'];

											echo "<h3>Stats for player: <a href=\"http://steamcommunity.com/profiles/".GetCommunityID($auth)."\">$name</a></h3>
														<div class=\"stats\">
														<h4>Wins: $wins</h4><br>
														<h4>Losses: $losses</h4><br>
														<h4>W/L Ratio: ".number_format((float)$wins/$losses, 2, '.', '')."</h4><br>
														<h4>ELO Rating: $rating</h4><br>
														<div class=\"playerAvatar ".getPlayerState(GetCommunityID($auth))."\"><a href=\"http://steamcommunity.com/profiles/".GetCommunityID($auth)."\"><img src=\"".getAvatar(GetCommunityID($auth))."\"/></a></div>";
										}
									}else{
									}
								}else{
										die("User not found.");
									}
							}

								function GetCommunityID($steamid){
									$steamidexplode = explode(':', str_replace('STEAM_', '' ,$steamid)); 
									$commid = substr(bcadd(bcadd('76561197960265728', $steamidexplode['1']), bcmul($steamidexplode['2'], '2')),0, 17);
									return $commid;
								}

								function getAvatar($commid){
									global $SteamAPI_Key;
									$url = 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.$SteamAPI_Key.'&steamids='.$commid;
									$content = file_get_contents($url);
									$json = json_decode($content, true);

									foreach($json['response']['players'] as $item) {
											return $item['avatarfull'];
									}
								}
								function getPlayerState($commid){
									global $SteamAPI_Key;
									$url = 'http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key='.$SteamAPI_Key.'&steamids='.$commid;
									$content = file_get_contents($url);
									$json = json_decode($content, true);

									foreach($json['response']['players'] as $item) {
										if($item['personastate'] == 0){
											return "offline";
										}else{
											return "online";
										}
									}
								}
							?>
						</div>
						<?php
							$time = microtime();
							$time = explode(' ', $time);
							$time = $time[1] + $time[0];
							$finish = $time;
							$total_time = round(($finish - $start), 4);
							echo '<center>Page generated in '.$total_time.' seconds.</center>';
						?>
			</div>
		</div>
	</div>
</div>
</body>
</html>
