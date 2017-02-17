<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8"/>
		<meta http-equiv="X-UA-Compatible" content="IE=edge"/>
		<meta name="viewport" content="width=device-width, initial-scale=1"/>


		<!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
		<meta name="description" content="1v1 Arena Description"/>
		<meta name="author" content="Your Name"/>
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
		<link href="./css/bootstrap.css" rel="stylesheet"/>

		<!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
		<link href="./css/ie10-viewport-bug-workaround.css" rel="stylesheet"/>

		<!-- Custom styles for this template -->
		<link href="./css/jumbotron-narrow.css" rel="stylesheet"/>

		<!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
		<!--[if lt IE 9]>
			<script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
			<script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
		<![endif]-->

		<link href="css/style.css" rel="stylesheet" type="text/css" media="all"/>
	</head>

	<body>

		<div class="container">
			<div class="header clearfix">
				<nav>
					<ul class="nav nav-pills pull-right">
						<li role="presentation" class="active"><a href="index.php">Top Players</a></li>
						<li role="presentation"><a href="search.php">Search</a></li>
					</ul>
				</nav>
				<h3 class="text-muted">1v1 Arena</h3>
			</div>

			<div class="alert alert-info">
				<h1>Hey!</h1>
				<p><strong>You can customize this!</strong> To say whatever you'd like, or remove it entirely.</p>
			</div>

			<br/>

			<div>
				<div class="panel panel-primary">
					<?php
					if (!isset($_GET['id']) && empty($_GET['id']) || $_GET['id']==''){
						echo "<div class='panel-heading'><h3>Top 15 Players</h3>";
						include 'includes/search_header.html';
						echo "</div><container><center>";
						include 'includes/generatetopplayers.php';
						echo "</container></center>";

					}

					if (isset($_GET['id']) && !empty($_GET['id'])){

						// TODO: this might be something worth being configurable
						$serverID = 0;
						$totalplayers = mysqli_num_rows(mysqli_query($connect, "SELECT * FROM $mysql_table"));
						$run_query = "SELECT s1.*, (SELECT COUNT(*) FROM $mysql_table AS s2 WHERE s2.rating > s1.rating)+1 AS rank FROM $mysql_table AS s1 WHERE accountID=".(int)$_GET['id']." AND serverID=".(int)$serverID;
						$query = mysqli_query($connect, $run_query);

						if (mysqli_num_rows($query) > 0){
							if ($query){
								while ($row = mysqli_fetch_assoc($query)){
									$accountID = $row['accountID'];
									$auth = $row['auth'];
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
									echo '
									<div class="panel-heading"><h3>
										<a href="http://steamcommunity.com/profiles/'.GetCommunityID($auth).'">'
											.$name.'&nbsp;'.
											'</a>';
						  if (isPlayerActive($lastTime) == false) { //This is opposite for some reason rofl
						  	echo '<small style="color:#00FF00">Active';
						  } else {
						  	echo '<small style="color:red">Inactive';
						  }
						  echo '</small></h3>';
						  include 'includes/search_header.html';

						  echo '</div>
						  <div class="panel-body toppad">
						  	<div class="row">
						  		<div class="col-md-3 col-lg-3 " align="center"> 
						  			<a href="http://steamcommunity.com/profiles/'.GetCommunityID($auth).'">
						  				<img alt="User Pic" src="'.getAvatar(GetCommunityID($auth)).'" class="img-circle img-responsive"> </img>
						  			</a>
						  		</div>
						  		<div class=" col-md-9 col-lg-9 "> 
						  			<table class="table table-user-information">
						  				<tbody>
						  					<tr>
						  						<tr>
						  							<td>Rank</td>
						  							<td>'.$rank.' of '.$totalplayers.'</td>
						  						</tr>
						  						<td>Wins</td>
						  						<td>'.$wins.'</td>
						  					</tr>
						  					<tr>
						  						<td>Loses</td>
						  						<td>'.$losses.'</td>
						  					</tr>
						  					<tr>
						  						<td>ELO</td>
						  						<td>'.$rating.'</td>
						  					</tr>
						  				</tbody>
						  			</table>
						  		</div>
						  	</div>
						  </div>';
						}
					}
				} else{
					echo '<div style="margin-bottom:0px" class="alert alert-danger" role="alert"><strong>User not found.</strong></div>';
				}
			}
			?>
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


		<!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
		<script src="./js/ie10-viewport-bug-workaround.js"></script>
		<script src="./js/jquery-2.1.4.min.js"></script>
		<script src="./js/bootstrap.min.js"></script>
	</body>
</html>