<?php
// pass 1
if('cli'!==PHP_SAPI) return;
if(!isset($argv[2])){
   echo "Call: t3d_level_simplifier <infile.t3d> <SearchTexture>".PHP_EOL;
   echo "Output to infile_s.t3d".PHP_EOL;
   return;
}

$swap = "brush.tmp";
$fni = strtolower($argv[1]);
$fpi=file($fni,FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$filter = $argv[2];
$fpo_result  =  fopen(str_replace(".t3d","_s.t3d",$fni),"w");

$brush_started = false;
$poly_found    = false;
fwrite($fpo_result,"Begin Map".PHP_EOL);
$n_actor = 0;
$n_done  = 0;
echo "Working... processing actor: ";

foreach ($fpi as $line){
   $line = str_replace(chr(0x09),"        ",$line); // replace tabs by spaces
   if(stripos($line,"Begin Actor") !== false){
      $brush_started  = true;
      $n_actor++;
      $fpo_exam_brush = fopen($swap,"w");
   }
   if($brush_started){
      fwrite($fpo_exam_brush,$line.PHP_EOL);
      if(stripos($line,$filter) !== false) $poly_found = true;
   }
   if(stripos($line,"End Actor") !== false){
      $brush_started = false;
      fclose($fpo_exam_brush);
      if($poly_found){
         echo "\033[30G"."\033[K".$n_actor;
         $fpo_exam_brush = file($swap,FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
         foreach ($fpo_exam_brush as $line_b){
            if(stripos($line_b,"Begin Actor") !== false) $n_done++;
            fwrite($fpo_result,$line_b.PHP_EOL);
         }
         $poly_found = false;
      }
   }
}
echo PHP_EOL."Done. Passed ".$n_done." actors.".PHP_EOL;
if (file_exists($swap)) unlink($swap);

fwrite($fpo_result,"End Map".PHP_EOL);
fclose($fpo_result);
?>
