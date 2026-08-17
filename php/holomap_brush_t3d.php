<?php
// pass 2
if('cli'!==PHP_SAPI) return;
if(!isset($argv[2])){
   echo "Call: t3d_brush_simplifier <infile.t3d> <SearchTexture>".PHP_EOL;
   echo "Output to infile_c.t3d".PHP_EOL;
   return;
}

$fni = strtolower($argv[1]);
$fpi=file($fni,FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$filter = $argv[2];
$fpo = fopen(str_replace(".t3d","_c.t3d",$fni),"w");
$line_pass = false;
$line_moder = false;
$n_actor = 0;
echo "Working... processing actor: ";

foreach ($fpi as $line) {
   $line = str_replace(chr(0x09),"        ",$line);
   if(stripos($line,"Begin Actor") !== false) $n_actor++;
   if(stripos($line,"Begin Polygon") !== false){
      if(stripos($line,$filter) !== false) $line_pass = true;
      $line_moder = true;
   }
   if(!$line_moder || ($line_moder && $line_pass))
      fwrite($fpo,$line.PHP_EOL);
   if(stripos($line,"End Polygon") !== false){
      $line_moder = false;
      $line_pass = false;
   }
   echo "\033[30G"."\033[K".$n_actor;
}

echo PHP_EOL."Done".PHP_EOL;
fclose($fpo);
?>
