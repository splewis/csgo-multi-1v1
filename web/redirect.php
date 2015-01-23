<html>
<head>
<?php

$url = "http://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";
$url = str_replace("redirect.php", "index.php", $url);

echo "<script type=\"text/javascript\">
window.onload = function(){
	   var popup=window.open(\"$url\",\"Player Stats\");
};
</script>";

?>
</head>
</html>
