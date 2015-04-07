<?php
$generated = "<table class=\"tg\" width=\"450px\">
	<tr>
		<th class=\"tg-dilm\">#</th>
		<th class=\"tg-dilm\" width=\"200\">Name</th>
		<th class=\"tg-dilm\">Wins</th>
		<th class=\"tg-dilm\">Losses</th>
		<th class=\"tg-dilm\">W/L Ratio</th>
		<th class=\"tg-dilm\">ELO Rank</th>
	</tr>";

$alt = 0;

$server_limit = 'AND serverID=1';
$server_id = '1';
if (isset($_GET['serverid'])) {
	$server_id = (int)$_GET['serverid'];
	$server_limit = 'AND serverID='.(int)$_GET['serverid'];
}

$run_query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating AND s2.wins+s2.losses > 200 $server_limit)+1 AS rank FROM $mysql_table AS s1 WHERE s1.wins+s1.losses > 200 $server_limit ORDER BY rating DESC LIMIT 0, 15";
$query = mysqli_query($connect, $run_query);

if (@$query){
	for ($i = 0; $i < 15; $i++){
		$row = mysqli_fetch_assoc($query);
		$accountID = $row['accountID'];
		$rank = $row['rank'];
		$name = htmlentities($row['name']);
		$wins = $row['wins'];
		$losses = $row['losses'];
		$rating = $row['rating'];
		$lastTime = $row['lastTime'];

		if ($losses == 0) {
			$WL = $wins;
		} else{
			$WL = round($wins/$losses, 2);
		}

		if ($alt == 0){
			$generated .= "<tr><td class=\"tg-bsv2\">$rank</td>";

			// NEED TO FIX THE SERVERID! Combine user stats.
			if (isPlayerActive($lastTime) == true){
				$generated .= "<td class=\"tg-bsv2\"><a href=\"index.php?id=".$accountID."&serverid=".$server_id."\">$name (Inactive)</a></td>";
			} else {
				$generated .= "<td class=\"tg-bsv2\"><a href=\"index.php?id=".$accountID."&serverid=".$server_id."\">$name</a></td>";
			}

			$generated .= "<td class=\"tg-bsv2\">$wins</td>
							<td class=\"tg-bsv2\">$losses</td>
							<td class=\"tg-bsv2\">$WL</td>
							<td class=\"tg-bsv2\">$rating</td></tr>";
			$alt = 1;
		} else{
			$generated .= "<tr><td class=\"tg-dilm\">$rank</td>";

			if (isPlayerActive($lastTime) == true){
				$generated .= "<td class=\"tg-dilm\"><a href=\"index.php?id=".$accountID."&serverid=".$server_id."\">$name (Inactive)</a></td>";
			} else{
				$generated .= "<td class=\"tg-dilm\"><a href=\"index.php?id=".$accountID."&serverid=".$server_id."\">$name</a></td>";
			}

			$generated .= "<td class=\"tg-dilm\">$wins</td>
							<td class=\"tg-dilm\">$losses</td>
							<td class=\"tg-dilm\">$WL</td>
							<td class=\"tg-dilm\">$rating</td></tr>";
			$alt = 0;
		}
		
	}
	$generated .= "</table><br>Ranked by ELO Rating.";
}
echo $generated;
?>
