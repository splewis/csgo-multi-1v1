<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">

<?php
	require_once 'includes/config.inc.php';
	require_once 'includes/utils.inc.php';
	echo "<title>$page_title</title>";
	$time = microtime();
	$time = explode(' ', $time);
	$time = $time[1] + $time[0];
	$start = $time;
?>

<link rel="shortcut icon" type="image/x-icon" href="images/favicon.ico">
<link href="css/style.css" rel="stylesheet" type="text/css" media="all">
</head>
<body>
<div class="container">
	<div class="everything">

		<?php
		if (!isset($_GET['id']) && empty($_GET['id']) || $_GET['id']=='') {
			echo "<h3>$page_title</h3>";
			echo "<div class=\"searchnoinfo\">";
		} else{
			echo "<div class=\"search\">";
		}
		?>

			<form action="search.php" method="GET">
			<h6>Search player stats:</h6><input type="text" name="searchquery">
			<input type="submit" value="Submit">
			</form>
		</div>

		<?php
		if (!isset($_GET['id']) && empty($_GET['id']) || $_GET['id']=='') {
			echo "<div class=\"topPlayers\"><h1>Top 15 Players</h1>";
			include 'includes/generatetopplayers.php';
			echo "</div>";
		}

		if (isset($_GET['id']) && !empty($_GET['id'])) {
			$totalplayers = mysql_num_rows(mysql_query("SELECT * FROM $mysql_table"));
			$searchquery = htmlentities($_GET['id']);
			$query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating)+1 AS rank FROM $mysql_table AS s1 WHERE accountID=".mysql_real_escape_string($searchquery);
			if(mysql_fetch_row(mysql_query($query))>0){
				if($query_run = mysql_query($query)){
					while ($row = mysql_fetch_assoc($query_run)) {
						$accountID = $row['accountID'];
						$auth = $row['auth'];
						$rank = $row['rank'];
						$name = $row['name'];
						$wins = $row['wins'];
						$losses = $row['losses'];
						$rating = $row['rating'];
						$lastTime = $row['lastTime'];

						echo "<h3>Stats for player: <a href=\"http://steamcommunity.com/profiles/".GetCommunityID($auth)."\">$name</a></h3>
						<div class=\"stats\">
						<h4>Rank: $rank of $totalplayers</h4><br>
						<h4>Wins: $wins</h4><br>
						<h4>Losses: $losses</h4><br>
						<h4>W/L Ratio: ".number_format((float)$wins/$losses, 2, '.', '')."</h4><br>
						<h4>ELO Rating: $rating</h4><br>
						<div class=\"playerAvatar ".getPlayerState(GetCommunityID($auth))."\"><a href=\"http://steamcommunity.com/profiles/".GetCommunityID($auth)."\"><img src=\"".getAvatar(GetCommunityID($auth))."\"/></a>";
						if (isPlayerActive($lastTime) == true) {
							echo "<div class=\"activity inactive\">INACTIVE</div></div>";
						} else{
							echo "<div class=\"activity\">ACTIVE</div></div>";
						}
					}
				}
			}else{
				die("<h1>User not found.</h1>");
			}
		}
		?>

		</div>

		<?php
		if (isset($_GET['id']) && !empty($_GET['id'])) {
			$time = microtime();
			$time = explode(' ', $time);
			$time = $time[1] + $time[0];
			$finish = $time;
			$total_time = round(($finish - $start), 4);
			echo '<center>Page generated in '.$total_time.' seconds.</center>';
		}
		?>
	</div>
</div>
</body>
</html>
