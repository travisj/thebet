#!/usr/bin/php
<?php
date_default_timezone_set('America/New_York');
$base = $argv[1]; //dirname(__FILE__);

$teams = json_decode(file_get_contents($base . '/_json/teams.json'), true);
$picks = json_decode(file_get_contents($base . '/_json/picks.json'), true);
$players = json_decode(file_get_contents($base . '/_json/players.json'), true);
$history = json_decode(file_get_contents($base . '/_json/history.json'), true);

$url = 'http://espn.go.com/mlb/standings/_/year/2010/seasontype/2';
$handle = fopen($url, "rb");

$contents = '';
while (!feof($handle)) {
  $contents .= fread($handle, 8192);
}
fclose($handle);
preg_match_all('/<a href="\/mlb\/clubhouse\?team=(.*?)">(.*?)<\/a><\/td><td>(.*?)<\/td><td>(.*?)<\/td>/is', $contents, $matches);
foreach($matches[0] as $i=>$match) {
	$code = $matches[1][$i];
	$results[$code] = array(
		"name" => $teams[$code],
		"w" => $matches[3][$i], 
		"l" => $matches[4][$i]
	);
}

$scores = array();
$specifics = array();
foreach ($picks as $team => $pick) {
	if (!isset($scores[$pick['owner']])) {
		$scores[$pick['owner']] = 0;
	}
	$scores[$pick['owner']] += $results[$team][$pick['choice']];
	$specifics[$team] = $results[$team][$pick['choice']];
}

$file = $base . '/_posts/' . date('Y-m-d') . '-Results.markdown';

$page = "---\n";
$page .= "layout: post\n";
foreach ($scores as $owner => $score) {
	$history[date('Y-m-d')][$owner] = $score;
	$page .= $owner . ': ' . $score . "\n";
}
foreach ($specifics as $t => $s) {
	$page .= "$t: $s\n";
}
$page .= "---\n";

file_put_contents($base . '/_json/history.json', json_encode($history));
file_put_contents($file, $page);
system('cd ' . $base . ';' .
		'git add ' . $file .';' .
		'git commit -m "adding todays results";' .
		'git push origin gh-pages');
