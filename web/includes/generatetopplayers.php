<?php
require 'includes/config.inc.php';

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

$query = "SELECT s1.*, (SELECT COUNT(*) FROM multi1v1_stats AS s2 WHERE s2.rating > s1.rating)+1 AS rank FROM multi1v1_stats AS s1 ORDER BY rating DESC";

if (@$query_run = mysql_query($query)) {
	for ($i = 0; $i < 15; $i++) {
		$row = mysql_fetch_assoc($query_run);
		$accountID = $row['accountID'];
		$rank = $row['rank'];
		$name = $row['name'];
		$wins = $row['wins'];
		$losses = $row['losses'];
		$rating = $row['rating'];
		$lastTime = $row['lastTime'];

		if ($alt == 0) {
			$generated .= "<tr><td class=\"tg-bsv2\">$rank</td>";

			if (isPlayerActive($lastTime) == true) {
				$generated .= "<td class=\"tg-bsv2\"><a href=\"index.php?id=".$accountID."\">$name (Inactive)</a></td>";
			} else {
				$generated .= "<td class=\"tg-bsv2\"><a href=\"index.php?id=".$accountID."\">$name</a></td>";
			}

			$generated .= "<td class=\"tg-bsv2\">$wins</td>
							<td class=\"tg-bsv2\">$losses</td>
							<td class=\"tg-bsv2\">".number_format((float)$wins/$losses, 2, '.', '')."</td>
							<td class=\"tg-bsv2\">$rating</td></tr>";
			$alt = 1;
		} else {
			$generated .= "<tr><td class=\"tg-dilm\">$rank</td>";

			if (isPlayerActive($lastTime) == true){
				$generated .= "<td class=\"tg-dilm\"><a href=\"index.php?id=".$accountID."\">$name (Inactive)</a></td>";
			} else {
				$generated .= "<td class=\"tg-dilm\"><a href=\"index.php?id=".$accountID."\">$name</a></td>";
			}

			$generated .= "<td class=\"tg-dilm\">$wins</td>
							<td class=\"tg-dilm\">$losses</td>
							<td class=\"tg-dilm\">".number_format((float)$wins/$losses, 2, '.', '')."</td>
							<td class=\"tg-dilm\">$rating</td></tr>";
			$alt = 0;
		}
	}
	$generated .= "</table><br>Ranked by ELO Rating.";
}
echo $generated;
?>
