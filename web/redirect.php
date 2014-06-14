<html>
<head>
<?php
if(isset($_GET['id']) && !empty($_GET['id'])){
$id = $_GET['id'];
$u = "http://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";
$url = str_replace("redirect.php", "index.php", $u);

echo "<script type=\"text/javascript\">
window.onload = function(){
    var popup=window.open(\"$url\",\"Test Page :D\");
};
</script>";
}
?>
</head>
</html
