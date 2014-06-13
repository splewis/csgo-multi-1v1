<?php
require_once '../includes/config.inc.php';

$localIP = $_SERVER['SERVER_ADDR'];
$externalIP = $_SERVER['REMOTE_ADDR'];
$changes = 0;

if($localIP == $externalIP){
	$query = "SELECT accountID, name, rating, lastTime FROM multi1v1_stats";

	if(mysql_fetch_row(mysql_query($query))>0){
		if($query_run = mysql_query($query)){
			while ($row = mysql_fetch_assoc($query_run)){
				$accountID = $row['accountID'];
				$name = $row['name'];
				$rating = $row['rating'];
				$lastTime = $row['lastTime'];

				// echo "Name: $name<br>
				// LastTime: $lasttime<br>
				// ELO Rating: $rating<br>";

				$elapsedtime_days = number_format((float)(time() - $lastTime) / 86400, 2, '.', '');
				// echo $elapsedtime_days;

				if($elapsedtime_days > 1 && $rating > 1500 && $lastTime > 0){
					$rating_loss = $antisquatter_rate_loss * $elapsedtime_days * ($rating - 1500) / $rating;
					$rating_new = number_format((float)$rating - $rating_loss, 2, '.', '');

					echo $name.": ";
					echo $elapsedtime_days." ::";
					echo $rating_new."<br>";
					mysql_query("UPDATE multi1v1_stats SET rating='$rating_new' WHERE accountID='$accountID'");
					$changes++;
				}
			}
		}
	}
	if($log_antisquatter == true){
		file_put_contents("antisquatter.log", date('d/m/y h:i:s')." Script ran successfully. | Players updated: ".$changes."\n", FILE_APPEND);
	}
}
else{
	echo 'You aren\'t supposed to be here! Only follow links!';
	if($log_antisquatter == true){
		file_put_contents("antisquatter.log", date('d/m/y h:i:s')." File unsuccessfully accessed from IP: ".$externalIP.". Local IP: ".$localIP.".\n", FILE_APPEND);
	}
}
?>
