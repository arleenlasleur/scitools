<?php
// pass 3 after blender
if($argc<3) die("Call: php ".$argv[0]." <doutcloud.obj> <nearest.t3d>".PHP_EOL);
$inputPath = $argv[1];
$outputPath = $argv[2];
if(!file_exists($inputPath)) die("Input file not found.".PHP_EOL);
$lines = file($inputPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
$vertices = [];
foreach($lines as $line){
   $line = trim($line);
   if(strpos($line, 'v ') === 0) {
      $parts = preg_split('/\s+/', $line);
      if(count($parts) >= 4) {
         $vertices[] = [
             'x' => (float)$parts[1],
             'y' => (float)$parts[3],
             'z' => (float)$parts[2]  ];
}  }  }

$vCount = count($vertices);
if($vCount<3) die("Not enough verts.".PHP_EOL);
$outputFile = fopen($outputPath, "w");
if(!$outputFile) die("Output file inaccessible.".PHP_EOL);

// phase 1: t3d header
fwrite($outputFile, "Begin Map.PHP_EOL");
fwrite($outputFile, "Begin Actor Class=Brush Name=VertexMesh1".PHP_EOL);
fwrite($outputFile, "    CsgOper=CSG_Active".PHP_EOL);
fwrite($outputFile, "    Begin Brush Name=Brush".PHP_EOL);
fwrite($outputFile, "        Begin PolyList".PHP_EOL);

$usedFaces = [];
$faceCount = 0;

echo "Total verts: ".$vCount.PHP_EOL;
echo "Working... wrote polygons: ";

// phase 2: sort+merge
for($i = 0; $i<$vCount; $i++){
   $distances = [];
   for($j = 0; $j<$vCount; $j++){
      if ($i === $j) continue;
      $dx = $vertices[$j]['x'] - $vertices[$i]['x'];
      $dy = $vertices[$j]['y'] - $vertices[$i]['y'];
      $dz = $vertices[$j]['z'] - $vertices[$i]['z'];
      $distSq = ($dx * $dx) + ($dy * $dy) + ($dz * $dz);
      $distances[$j] = $distSq;
   }
   asort($distances);
   $nearestKeys = array_keys($distances);
   
   if(count($nearestKeys) >= 2){
      $idx1 = $i;
      $idx2 = $nearestKeys[0];
      $idx3 = $nearestKeys[1];
      $faceIndices = [$idx1, $idx2, $idx3];
      sort($faceIndices);
      $faceKey = implode('-', $faceIndices);
      
      if(!isset($usedFaces[$faceKey])){
          $p1 = $vertices[$idx1];
          $p2 = $vertices[$idx2];
          $p3 = $vertices[$idx3];
          fwrite($outputFile, "            Begin Polygon Texture=DefaultFlags Flags=0".PHP_EOL);
          fwrite($outputFile, "                Origin   " . sprintf("%+013.6f,%+013.6f,%+013.6f", $p1['x'], $p1['y'], $p1['z']) .PHP_EOL);
          fwrite($outputFile, "                Normal   +00000.000000,+00000.000000,+00001.000000".PHP_EOL);
          fwrite($outputFile, "                TextureU +00001.000000,+00000.000000,+00000.000000".PHP_EOL);
          fwrite($outputFile, "                TextureV +00000.000000,+00001.000000,+00000.000000".PHP_EOL);
          fwrite($outputFile, "                Vertex   " . sprintf("%+013.6f,%+013.6f,%+013.6f", $p1['x'], $p1['y'], $p1['z']) .PHP_EOL);
          fwrite($outputFile, "                Vertex   " . sprintf("%+013.6f,%+013.6f,%+013.6f", $p2['x'], $p2['y'], $p2['z']) .PHP_EOL);
          fwrite($outputFile, "                Vertex   " . sprintf("%+013.6f,%+013.6f,%+013.6f", $p3['x'], $p3['y'], $p3['z']) .PHP_EOL);
          fwrite($outputFile, "            End Polygon".PHP_EOL);
          $usedFaces[$faceKey] = true;
          $faceCount++;
          echo "\033[28G"."\033[K".$faceCount;
}  }  }

// phase 3: footer
fwrite($outputFile, "        End PolyList".PHP_EOL);
fwrite($outputFile, "    End Brush".PHP_EOL);
fwrite($outputFile, "    Brush=Model'Engine.Brush.Model0'".PHP_EOL);
fwrite($outputFile, "End Actor".PHP_EOL);
fwrite($outputFile, "End Map".PHP_EOL);
fclose($outputFile);
echo PHP_EOL."Done.".PHP_EOL;
?>