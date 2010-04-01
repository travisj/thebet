<?php
$base = dirname(__FILE__);

$teams = json_decode(file_get_contents($base . '/teams.json'), true);
$picks = json_decode(file_get_contents($base . '/picks.json'), true);
$players = json_decode(file_get_contents($base . '/players.json'), true);

$url = 'http://espn.go.com/mlb/standings/_/year/2009/seasontype/2';
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
foreach ($picks as $team => $pick) {
	if (!isset($scores[$pick['owner']])) {
		$scores[$pick['owner']] = 0;
	}
	$scores[$pick['owner']] += $results[$team][$pick['choice']];
}

var_dump($scores);exit;
