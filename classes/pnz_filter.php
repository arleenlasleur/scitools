<?php  if("cli"!==PHP_SAPI) return;   $ok_cli=true;
       if(!isset($argv[1]))           $ok_cli=false;
       if(!$ok_cli){ echo "Call: pnz_filter <unreal.log>".PHP_EOL; return; }
$data=array();
$f_in=file($argv[1],FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
foreach ($f_in as $line){
   if(stripos($line,"PNZE:") === false) continue;
   $s = substr($line,6,strpos($line,".",5)-6);
   array_push($data,intval($s));
}
$data = array_unique($data);
asort($data,SORT_NUMERIC);
$data=array_values($data);
for($i=0;$i<count($data);$i++) echo $data[$i].PHP_EOL; 

// todo prod max ready file
         ?>
