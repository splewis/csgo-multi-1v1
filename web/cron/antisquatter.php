<?php
require_once '../includes/config.inc.php';

$externalIP = $_SERVER['REMOTE_ADDR'];

if (isset($_GET['p']) && !empty($_GET['p'])) {
	$passphrase = $_GET['p'];
} else{
	die("<b>You aren't supposed to be here! Only follow links!<b>");
}

ini_set('max_execution_time', 300);
$changes = 0;

if ($passphrase == $anti_squatter_pass) {
	$run_query = "SELECT accountID, name, rating, lastTime, TRUNCATE((unix_timestamp(NOW()) - lastTime) / 86400, 0) AS elapsedtime_days FROM $mysql_table WHERE rating > 1500 AND lastTime > 0 AND (unix_timestamp(NOW()) - lastTime) > 86400";
	$query = mysqli_query($connect, $run_query);

	mysqli_autocommit($connect, false);


	while ($row = mysqli_fetch_assoc($query)) {
		$accountID = $row['accountID'];
		$rating = $row['rating'];
		$lastTime = $row['lastTime'];
		$elapsedtime_days = $row['elapsedtime_days'];

		$rating_loss = $antisquatter_rate_loss * $elapsedtime_days * ($rating - 1500) / $rating;
		$rating_new = number_format((float)$rating - $rating_loss, 2, '.', '');

		mysqli_query($connect, "UPDATE multi1v1_stats SET rating='$rating_new' WHERE accountID='$accountID'");
		$changes++;
	}

	mysqli_commit($connect);

	if ($log_antisquatter == true) {
		file_put_contents("antisquatter.log", date('d/m/y h:i:s')." Script ran successfully. | Players updated: ".$changes."\n", FILE_APPEND);
	}
	echo "Complete. Updated $changes players.";
} else{
	if ($log_antisquatter == true) {
		file_put_contents("antisquatter.log", date('d/m/y h:i:s')." Invalid password from IP: ".$externalIP."\n", FILE_APPEND);
	}
	echo "<b>Incorrect Password!</b>";
}
?>
