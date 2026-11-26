<?php
if('cli'!==PHP_SAPI) return;
if(!isset($argv[2])){
   echo "Call: brushfilter <infile.t3d> <SearchTexture> [SearchSecondary]".PHP_EOL;
   echo "Output to infile_c.t3d".PHP_EOL;
   return;
}

$fni = strtolower($argv[1]);
$fpi=file($fni,FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$filter = $argv[2];
if(isset($argv[3])) $filter_sec = $argv[3];
$fpo = fopen(str_replace(".t3d","_b.t3d",$fni),"w");
$line_pass = false;
$line_moder = false;
$n_polygon = 0;
$stat_r = "Working... processing polygon: ";
echo $stat_r;

foreach ($fpi as $line) {
   $line = str_replace(chr(0x09)," ",$line);
   if(stripos($line,"Begin Polygon") !== false){
      $n_polygon++;
      if(stripos($line,$filter) !== false) $line_pass = true;
      if(stripos($line,$filter_sec) !== false) $line_pass = true;
      $line_moder = true;
   }
   if(!$line_moder || ($line_moder && $line_pass))
      fwrite($fpo,$line.PHP_EOL);
   if(stripos($line,"End Polygon") !== false){
      $line_moder = false;
      $line_pass = false;
   }
   echo "\033[".(strlen($stat_r)+1)."G"."\033[K".$n_polygon;
}

echo PHP_EOL."Done".PHP_EOL;
fclose($fpo);
?>
