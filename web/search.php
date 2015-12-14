<!DOCTYPE html>
<html lang="en">
  <head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width, initial-scale=1">


	<!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
    <meta name="description" content="1v1 Arena">
    <meta name="author" content="Your name">

	<?php
	  require_once 'includes/config.inc.php';
	  require_once 'includes/utils.inc.php';
	  echo "<title>$page_title</title>";
	  $time = microtime();
	  $time = explode(' ', $time);
	  $time = $time[1] + $time[0];
	  $start = $time;
	?>

	<!-- Bootstrap core CSS -->
	<link href="./css/bootstrap.css" rel="stylesheet">

	<!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
	<link href="./css/ie10-viewport-bug-workaround.css" rel="stylesheet">

	<!-- Custom styles for this template -->
	<link href="./css/jumbotron-narrow.css" rel="stylesheet">

	<!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
	<!--[if lt IE 9]>
	  <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
	  <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
	<![endif]-->

	<link href="css/style.css" rel="stylesheet" type="text/css" media="all">
  </head>

  <body>

	<div class="container">
	  <div class="header clearfix">
		<nav>
		  <ul class="nav nav-pills pull-right">
			<li role="presentation"><a href="index.php">Top Players</a></li>
			<li role="presentation" class="active"><a href="search.php">Search</a></li>
		  </ul>
		</nav>
        <h3 class="text-muted">1v1 Arena Server</h3>
      </div>

      <div class="alert alert-info">
        <h1>Hey!</h1>
        <p><strong>You can customize this!</strong> Add information here, or remove it entirely..</p>
      </div>

      <br/>

	  <div>
		<div class="panel panel-primary">
			<?php
			if (isset($_GET['searchquery']) && !empty($_GET['searchquery']) && strlen($_GET['searchquery'])>2){

				$searchquery = htmlentities($_GET['searchquery']);
				$run_query = "SELECT `accountID`, `name` FROM multi1v1_stats WHERE name LIKE '%".mysqli_real_escape_string($connect, $searchquery)."%'";
				$query = mysqli_query($connect, $run_query);
				echo '<div class="panel-heading"><h3>Results for '.$searchquery.'</h3>';
				include 'includes/search_header.html';
				echo '</div><ul class="list-group">';

				if (mysqli_num_rows($query) > 0){
					if ($query) {
						while ($row = mysqli_fetch_assoc($query)){
							$accountID = $row['accountID'];
							$name = htmlentities($row['name']);
							echo '<li class="list-group-item"><a href="index.php?id='.$accountID.'">'.$name.'</a></li>';
						}
					}
				} else {
					echo '<li class="list-group-item list-group-item-danger"><strong>No users found with name "'.$searchquery.'".</strong></li>';
				}

				echo '</ul>';
			} else {
				echo '<div class="panel-heading"><h3>Search</h3>';
				include 'includes/search_header.html';
				echo '</div>';
			}
			?>
		  </div>
		</div>
	  </div>

	  <footer class="footer">
		<div class="container">
		  <center>
			<?php
			if (isset($_GET['id']) && !empty($_GET['id'])){
			  $time = microtime();
			  $time = explode(' ', $time);
			  $time = $time[1] + $time[0];
			  $finish = $time;
			  $total_time = round(($finish - $start), 4);
			  echo '<p>Page generated in '.$total_time.' seconds.</p>';
			}
			?>
		  </center>
		</div>
	  </footer>

	</div> <!-- /container -->


	<!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
	<script src="./js/ie10-viewport-bug-workaround.js"></script>
	<script src="./js/jquery-2.1.4.min.js"></script>
	<script src="./js/bootstrap.min.js"></script>
  </body>

</html>