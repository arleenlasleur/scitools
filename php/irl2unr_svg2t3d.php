<?php
if('cli'!==PHP_SAPI) return;
if(isset($argv[1]) && $argv[1]=="/?"){
   echo "todo".PHP_EOL;
   exit(0);
}
if(!isset($argv[2])){
   echo "Call: svgwalls <in.svg> <out.t3d> [height]".PHP_EOL;
   exit(1);
}

$inputFile  = $argv[1];
$outputFile = $argv[2];
$wallHeight  = 120.0;
if(isset($argv[3])) $wallHeight = intval($argv[3]);
if (!file_exists($inputFile)) die("File not found.".PHP_EOL);

$xml = simplexml_load_file($inputFile);
$xml->registerXPathNamespace('svg', 'http://w3.org');
$paths = $xml->xpath('//svg:path | //path');
$t3dPolygons = [];

echo "Working... ";
foreach ($paths as $path) {
    if (!isset($path['d'])) continue;
    
    $layerOffsetX = 0.0; $layerOffsetY = 0.0;            // parse layer offset if any
    $parent = $path->xpath('ancestor::svg:g | ancestor::g');
    if (!empty($parent)) {
        foreach ($parent as $g) {
            if (isset($g['transform']) && preg_match('/translate\(\s*([\d\.-]+)\s*[\s,]\s*([\d\.-]+)\s*\)/i', (string)$g['transform'], $matches)) {
                $layerOffsetX += (float)$matches[1]; $layerOffsetY += (float)$matches[2];
            }
        }
    }
    $dAttr = (string)$path['d'];
    $dAttr = preg_replace('/([a-df-zRef-z])/i', ' $1 ', $dAttr);
    $dAttr = str_replace(',', ' ', $dAttr);
    $tokens = preg_split('/\s+/', trim($dAttr));
    
    $vertices = []; $currentX = 0.0; $currentY = 0.0; $startX = 0.0; $startY = 0.0; $lastCommand = '';
    $i = 0; $totalTokens = count($tokens);
    
    while ($i < $totalTokens) {
        $token = $tokens[$i];
        if ($token === '') { $i++; continue; }
        if (preg_match('/^[a-z]$/i', $token)) {
            $lastCommand = $token; $i++;
            if ($lastCommand === 'Z' || $lastCommand === 'z') {
                if (count($vertices) >= 3) { $t3dPolygons[] = $vertices; }
                $vertices = []; $currentX = $startX; $currentY = $startY; continue;
            }
            $token = $tokens[$i];
        }
        
        switch ($lastCommand) {
            case 'M': $currentX = (float)$tokens[$i++]; $currentY = (float)$tokens[$i++]; $startX = $currentX; $startY = $currentY; $lastCommand = 'L'; break;
            case 'L': $currentX = (float)$tokens[$i++]; $currentY = (float)$tokens[$i++]; break;
            case 'H': $currentX = (float)$tokens[$i++]; break;
            case 'V': $currentY = (float)$tokens[$i++]; break;
            default: $i++; continue 2;
        }
        
        $finalX = round($currentX + $layerOffsetX);
        $finalY = round($currentY + $layerOffsetY);
        if (empty($vertices) || end($vertices) !== ['x' => $finalX, 'y' => $finalY]) {
            $vertices[] = ['x' => $finalX, 'y' => $finalY];
        }
    }
}

function generateT3dPolygon($vertices, $normal, $texU, $texV, $itemType = 'OUTSIDE') {
    $origin = $vertices[0];
    $out     =         "    Begin Polygon Item={$itemType} Flags=1073741824\n";
    $out    .= sprintf("        Origin   %+012.6f,%+012.6f,%+012.6f\n", $origin['x'], $origin['y'], $origin['z']);
    $out    .= sprintf("        Normal   %+012.6f,%+012.6f,%+012.6f\n", $normal['x'], $normal['y'], $normal['z']);
    $out    .= sprintf("        TextureU %+012.6f,%+012.6f,%+012.6f\n", $texU['x'], $texU['y'], $texU['z']);
    $out    .= sprintf("        TextureV %+012.6f,%+012.6f,%+012.6f\n", $texV['x'], $texV['y'], $texV['z']);
    $out    .=         "        Pan      U=0 V=0\n";
    foreach ($vertices as $v)
       $out .= sprintf("        Vertex   %+012.6f,%+012.6f,%+012.6f\n", $v['x'], $v['y'], $v['z']);
    $out    .=         "    End Polygon\n";
    return $out;
}

$out  = "Begin PolyList".PHP_EOL;
foreach ($t3dPolygons as $poly) {
    $count = count($poly);
    
    $floorVerts = [];
    for ($i=0; $i<$count; $i++)    $floorVerts[] = ['x' => $poly[$i]['x'], 'y' => $poly[$i]['y'], 'z' => 0.0];
    $out .= generateT3dPolygon($floorVerts, ['x' => 0, 'y' => 0, 'z' => -1], ['x' => 1, 'y' => 0, 'z' => 0], ['x' => 0, 'y' => -1, 'z' => 0]);

    $ceilVerts = [];
    for ($i=$count-1; $i>=0; $i--) $ceilVerts[] = ['x' => $poly[$i]['x'], 'y' => $poly[$i]['y'], 'z' => $wallHeight];
    $out .= generateT3dPolygon($ceilVerts, ['x' => 0, 'y' => 0, 'z' => 1], ['x' => 1, 'y' => 0, 'z' => 0], ['x' => 0, 'y' => 1, 'z' => 0]);
    
    for ($i = 0; $i < $count; $i++) {  // walls
        $next = ($i + 1) % $count;
        $wallVerts = [
            ['x' => $poly[$i]['x'],    'y' => $poly[$i]['y'],    'z' => 0.0],
            ['x' => $poly[$i]['x'],    'y' => $poly[$i]['y'],    'z' => $wallHeight],
            ['x' => $poly[$next]['x'], 'y' => $poly[$next]['y'], 'z' => $wallHeight],
            ['x' => $poly[$next]['x'], 'y' => $poly[$next]['y'], 'z' => 0.0]
        ];
        
        $dx = $poly[$next]['x'] - $poly[$i]['x']; // normal calcs
        $dy = $poly[$next]['y'] - $poly[$i]['y'];
        $len = sqrt($dx*$dx + $dy*$dy);
        
        if ($len > 0) {
            $nx = $dy / $len;  // normal
            $ny = -$dx / $len;
            $tux = $dx / $len; // tex direction
            $tuy = $dy / $len;
        } else {
            $nx = 1; $ny = 0; $tux = 0; $tuy = 1;
        }
        $normal = ['x' => $nx, 'y' => $ny, 'z' => 0];
        $texU   = ['x' => $tux, 'y' => $tuy, 'z' => 0];
        $texV   = ['x' => 0, 'y' => 0, 'z' => -1];

        $out .= generateT3dPolygon($wallVerts, $normal, $texU, $texV);
    }
}
$out .= "End PolyList".PHP_EOL;

file_put_contents($outputFile, $out);
echo "done.".PHP_EOL;
?>
