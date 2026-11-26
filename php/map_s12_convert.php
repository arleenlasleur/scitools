<?php
if('cli'!==PHP_SAPI) return;
if(!isset($argv[1])){ echo "Call: convert.php <input.obj>"; exit(1); }
$input_file = strtolower($argv[1]);
$fpo = fopen(str_replace(".obj",".uc",$input_file),"w");
$max_vectors_per_line = 128;
$max_lines_per_actor = 256;
$max_total_vectors = 32768;

if(!file_exists($input_file)){
   die("Input file not found.".PHP_EOL);
}

$file_lines = file($input_file);
$all_vectors = array();
$vector_count = 0;

foreach ($file_lines as $line) {
   $line = trim($line);
   if(empty($line) || $line[0] === '#') continue;
   $parts = preg_split('/\s+/', $line);
   if($parts[0] === 'v') {
      if ($vector_count >= $max_total_vectors) break;
      $x = (int)$parts[1];  // trunc to int
      $y = (int)$parts[2];
      $z = (int)$parts[3];
      $real_x = $x;    // swap Y-Z (blender -> unreal)
      $real_y = $z;
      $real_z = $y;
      $all_vectors[] = array($real_x, $real_y, $real_z);
      $vector_count++;
   }
}

$b64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+;';
$encoded_lines = array();
$current_line_str = '';
$current_count = 0;

foreach ($all_vectors as $vector) {
   $x_u16 = $vector[0] & 0xFFFF; // convert to unsigned for correct shifting
   $y_u16 = $vector[1] & 0xFFFF;
   $z_u16 = $vector[2] & 0xFFFF;
   $b0 = ($x_u16 >> 8) & 0xFF;   $b2 = ($y_u16 >> 8) & 0xFF;   $b4 = ($z_u16 >> 8) & 0xFF;  // prepare 6 big-endian
   $b1 =  $x_u16       & 0xFF;   $b3 =  $y_u16       & 0xFF;   $b5 =  $z_u16       & 0xFF;      
   $c0 =  ($b0 >> 2) & 0x3F;                         $c4 =  ($b3 >> 2) & 0x3F;              // split 48 bits to 8x6
   $c1 = (($b0 & 0x03) << 4) | (($b1 >> 4) & 0x0F);  $c5 = (($b3 & 0x03) << 4) | (($b4 >> 4) & 0x0F);
   $c2 = (($b1 & 0x0F) << 2) | (($b2 >> 6) & 0x03);  $c6 = (($b4 & 0x0F) << 2) | (($b5 >> 6) & 0x03);
   $c3 =   $b2 & 0x3F;                               $c7 =   $b5 & 0x3F;
   // assemble base64 for current vect
   $current_line_str .= $b64_chars[$c0] . $b64_chars[$c1] . $b64_chars[$c2] . $b64_chars[$c3] .
                        $b64_chars[$c4] . $b64_chars[$c5] . $b64_chars[$c6] . $b64_chars[$c7];
   $current_count++;
   if($current_count >= $max_vectors_per_line) {
      $encoded_lines[] = $current_line_str;
      $current_line_str = '';
      $current_count = 0;
   }
}

if ($current_count > 0) {
    $encoded_lines[] = $current_line_str;
}

// output
   fwrite($fpo,"defaultproperties{".PHP_EOL);
   fwrite($fpo,"   MapData_qty=".$vector_count.PHP_EOL);

foreach ($encoded_lines as $index => $encoded_line){
   if ($index >= $max_lines_per_actor) break;
   fwrite($fpo,"   MapData(".$index.")=".$encoded_line.PHP_EOL);
}
   fwrite($fpo,"}".PHP_EOL);
   fclose($fpo);
?>
