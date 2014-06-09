<?php
require 'includes/config.inc.php';
//tg-bsv2 Light
//tg-dilm Dark
$generated = "<table class=\"tg\" width=\"450px\">
	<tr>
		<th class=\"tg-dilm\" width=\"150\">Name</th>
		<th class=\"tg-dilm\">Wins</th>
		<th class=\"tg-dilm\">Losses</th>
		<th class=\"tg-dilm\">W/L Ratio</th>
		<th class=\"tg-dilm\">ELO Rank</th>
	</tr>";

$alt = 0;

$query = "SELECT * FROM multi1v1_stats ORDER BY rating DESC";

if(@$query_run = mysql_query($query)){
	for ($i=0; $i < 15; $i++) {
		$row = mysql_fetch_assoc($query_run);
		$accountID = $row['accountID'];
		$auth = $row['auth'];
		$name = $row['name'];
		$wins = $row['wins'];
		$losses = $row['losses'];
		$rating = $row['rating'];
		
		if($alt == 0){
			$generated .= "<tr>
							<td class=\"tg-bsv2\"><a href=\"index.php?id=".$accountID."\">$name</a></td>
							<td class=\"tg-bsv2\">$wins</td>
							<td class=\"tg-bsv2\">$losses</td>
							<td class=\"tg-bsv2\">$wins/$losses</td>
							<td class=\"tg-bsv2\">$rating</td>
							</tr>";
			$alt = 1;
		}else{
			$generated .= "<tr>
							<td class=\"tg-dilm\"><a href=\"index.php?id=".$accountID."\">$name</a></td>
							<td class=\"tg-dilm\">$wins</td>
							<td class=\"tg-dilm\">$losses</td>
							<td class=\"tg-dilm\">$wins/$losses</td>
							<td class=\"tg-dilm\">$rating</td>
							</tr>";
			$alt = 0;
		}
	}
	$generated .= "</table>";
}
echo $generated;
?>
