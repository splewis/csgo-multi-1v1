<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">

<?php 
	require 'includes/config.inc.php';
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
		<div class="search">
			<form action="search.php" method="GET">
			<h6>Search player stats:</h6><input type="text" name="searchquery">
			<input type="submit" value="Submit">
			</form>
		</div>

		<?php
		if(isset($_GET['searchquery']) && !empty($_GET['searchquery']) && strlen($_GET['searchquery'])>2){
			$searchquery = htmlentities($_GET['searchquery']);
			$query = "SELECT `accountID`, `name` FROM multi1v1_stats WHERE name LIKE '%".mysql_real_escape_string($searchquery)."%'";
			echo "<h3>Searching for players with name \"$searchquery\".</h3>";
			if(mysql_fetch_row(mysql_query($query))>0){
				echo "<div class=\"stats\">Players found:<br><ul>";
				if(@$query_run = mysql_query($query)){
					while ($row = mysql_fetch_assoc($query_run)){
						$accountID = $row['accountID'];
						$name = $row['name'];
						echo "<h2><li><a href=\"index.php?id=".$accountID."\">$name</a></li></h2>";
					}
				}
				echo "</ul></div>";
			}else{
				die("No users found with name \"".$searchquery."\".");
			}
		}else{
			die("<h3>Please enter a search term longer than 2 characters.</h3>");
		}
		?>

	</div>
</div>
</body>
</html>
