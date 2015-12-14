<?php
require 'includes/config.inc.php';

$generated = "<table class=\"table table-striped\" width=\"450px\">
	<tr>
		<th>#</th>
		<th width=\"200\">Name</th>
		<th>Wins</th>
		<th>Losses</th>
		<th>W/L Ratio</th>
		<th>ELO Rank</th>
	</tr>";

$alt = 0;

$server_limit = '';
if (isset($_GET['server_id']))
	$server_limit = 'AND serverID='.(int)$_GET['server_id'];

$run_query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating AND s2.wins+s2.losses > 100)+1 AS rank FROM $mysql_table AS s1 WHERE s1.wins+s1.losses > 100 $server_limit ORDER BY rating DESC LIMIT 0, 15";
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
			$generated .= "<tr><td>".$rank."</td>";

			if (isPlayerActive($lastTime) == true){
				$generated .= "<td><a href=\"index.php?id=".$accountID."\">$name (Inactive)</a></td>";
			} else {
				$generated .= "<td><a href=\"index.php?id=".$accountID."\">$name</a></td>";
			}

			$generated .= "<td>$wins</td>
							<td>$losses</td>
							<td>$WL</td>
							<td>$rating</td></tr>";
			$alt = 1;
		} else{
			$generated .= "<tr><td>$rank</td>";

			if (isPlayerActive($lastTime) == true){
				$generated .= "<td><a href=\"index.php?id=".$accountID."\">$name (Inactive)</a></td>";
			} else{
				$generated .= "<td><a href=\"index.php?id=".$accountID."\">$name</a></td>";
			}

			$generated .= "<td>$wins</td>
							<td>$losses</td>
							<td>$WL</td>
							<td>$rating</td></tr>";
			$alt = 0;
		}
		
	}
	$generated .= "</table>";
}
echo $generated;
?>
