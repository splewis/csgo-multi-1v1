<html>
<head>
<?php
$u = "http://$_SERVER[HTTP_HOST]$_SERVER[REQUEST_URI]";
$url = str_replace("redirect.php", "index.php", $u);

if(isset($_GET['id']) && !empty($_GET['id'])){
$id = $_GET['id'];
echo "<script type=\"text/javascript\">
window.onload = function(){
    var popup=window.open(\"$url\",\"Test Page :D\");
};
</script>";
}
?>
</head>
</html
