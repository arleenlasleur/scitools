<?php

if('cli'!==PHP_SAPI) return;
if(!isset($argv[1])){
   echo "STAGE 1 - force semisolids to solid - optional ".PHP_EOL;
   echo "Call: nosemi.php <infile.t3d>".PHP_EOL;
   echo "Output to infile_s.t3d".PHP_EOL;
   return;
}

$fni = strtolower($argv[1]);
$fpi=file($fni,FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$fpo = fopen(str_replace(".t3d","_ns.t3d",$fni),"w");
//$stat_r = "Working... processing polygon: ";
//echo $stat_r;

foreach ($fpi as $line) {
   $line = str_replace(chr(0x09)," ",$line);
   if(stripos($line,"PolyFlags") !== false) continue;
   fwrite($fpo,$line.PHP_EOL);
//   echo "\033[".(strlen($stat_r)+1)."G"."\033[K".$n_polygon;
}

echo PHP_EOL."Done".PHP_EOL;
fclose($fpo);
?>