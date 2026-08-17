<?php
if('cli'!==PHP_SAPI) return;
if(isset($argv[1]) && $argv[1]=="/?"){
   echo "Check before processing:".PHP_EOL;
   echo "1. <path> data coords must be absolute".PHP_EOL;
   echo "   Ctrl+Shft+P > Input/Output > SVG output > Path data: abs".PHP_EOL;
   echo "2. Scale must be 1.00000:  Ctrl+Shft+D > Page > Scale".PHP_EOL;
   echo "3. Remove all transforms:  Ctrl+Shft+K, Ctrl+K".PHP_EOL;
   echo "4. After editing, do second pass on file.".PHP_EOL;
   echo "5. Remove any CSS coords transform/translate.".PHP_EOL;
   echo "Building scale: 1 m = 100 cm = 45.25 UU".PHP_EOL;
   echo "QGIS meas key: Ctrl+Shft+M".PHP_EOL;
   exit(0);
}
if(!isset($argv[2])){
   echo "Call: svgsnap <in.svg> <out.svg>".PHP_EOL;
   exit(1);
}
if (!file_exists($inputFile)) die("File not found.".PHP_EOL);
function AddInkscapeGrid(SimpleXMLElement $xml) {
   $sodipodiURI = 'http://sourceforge.net';
   $inkscapeURI = 'http://inkscape.org';
   $xml->registerXPathNamespace('sodipodi', $sodipodiURI);
   $xml->registerXPathNamespace('inkscape', $inkscapeURI);
   $namedview = $xml->xpath('//sodipodi:namedview');
   if (empty($namedview)) $nv = $xml->addChild('sodipodi:namedview', '', $sodipodiURI);
     else $nv = $namedview[0];
   $oldGrids = $xml->xpath('//inkscape:grid');
   foreach ($oldGrids as $oldGrid) {
       $domRef = dom_import_simplexml($oldGrid);
       $domRef->parentNode->removeChild($domRef);
   }
   $grid = $nv->addChild('inkscape:grid', '');
   $grid->addAttribute('type', 'xygrid');
   $grid->addAttribute('id', 'grid1604');
   $grid->addAttribute('units', 'px');
   $grid->addAttribute('spacingx', '2');
   $grid->addAttribute('spacingy', '2');
   $grid->addAttribute('empspacing', '32');
   $grid->addAttribute('enabled', 'true');
   $grid->addAttribute('color', '#483fff');
   $grid->addAttribute('opacity', '0.22352941');
   $grid->addAttribute('empcolor', '#b71833');
   $grid->addAttribute('empopacity', '0.49803922');
   $grid->addAttribute('dotted', 'false');
   if (isset($nv['showgrid'])) $nv['showgrid'] = 'true';
     else $nv->addAttribute('showgrid', 'true');
}
$inputFile  = $argv[1];
$outputFile = $argv[2];
$grid       = 2;
$xml = simplexml_load_file($inputFile);
$xml->registerXPathNamespace('svg', 'http://w3.org');
$paths = $xml->xpath('//svg:path | //path'); // iterate all path
echo "Working... ";

foreach ($paths as $path) {
   if (!isset($path['d'])) continue;
   $dAttr = (string)$path['d'];
   // separate cmds from numbers
   $dAttr = preg_replace('/([a-df-zRef-z])/i', ' $1 ', $dAttr);
   $dAttr = str_replace(',', ' ', $dAttr);
   $tokens = preg_split('/\s+/', trim($dAttr));
   $newD = [];
   $currentX = 0.0;
   $currentY = 0.0;
   $startX = 0.0; // for return by Z command
   $startY = 0.0;
   $lastCommand = '';
   $i = 0;
   $totalTokens = count($tokens);
   while ($i < $totalTokens) {
      $token = $tokens[$i];
      if ($token === '') { $i++; continue; }
      // check whether token is letter command
      if (preg_match('/^[a-z]$/i', $token)) {
         $lastCommand = $token;
         $i++;
         if ($lastCommand === 'Z' || $lastCommand === 'z') {
            $newD[] = "Z";
            $currentX = $startX;
            $currentY = $startY;
            continue;
         }
         $token = $tokens[$i]; // use numbers for cmd
      }
      // If no letter found, and there going numbers - use prev command
      switch ($lastCommand) {
         case 'M': // abs move
            $currentX = (float)$tokens[$i++]; $startX = $currentX;
            $currentY = (float)$tokens[$i++]; $startY = $currentY;
            $lastCommand = 'L';  // In SVG stdandard, after first M further pairs are treated as L
            $newD[] = sprintf("M %g,%g", round($currentX / $grid) * $grid, round($currentY / $grid) * $grid);
            break;
         case 'm': // rel move
            $currentX += (float)$tokens[$i++]; $startX = $currentX;
            $currentY += (float)$tokens[$i++]; $startY = $currentY;
            $lastCommand = 'l';
            $newD[] = sprintf("M %g,%g", round($currentX / $grid) * $grid, round($currentY / $grid) * $grid);
            break;
         case 'L': // abs line
            $currentX = (float)$tokens[$i++];
            $currentY = (float)$tokens[$i++];
            $newD[] = sprintf("L %g,%g", round($currentX / $grid) * $grid, round($currentY / $grid) * $grid);
            break;
         case 'l': // rel line
            $currentX += (float)$tokens[$i++];
            $currentY += (float)$tokens[$i++];
            $newD[] = sprintf("L %g,%g", round($currentX / $grid) * $grid, round($currentY / $grid) * $grid);
            break;
         case 'H': // abs horz
            $currentX = (float)$tokens[$i++];  $newD[] = sprintf("H %g", round($currentX / $grid) * $grid);
            break;
         case 'h': // rel horz
            $currentX += (float)$tokens[$i++]; $newD[] = sprintf("H %g", round($currentX / $grid) * $grid);
            break;
         case 'V': // abs vert
            $currentY = (float)$tokens[$i++];  $newD[] = sprintf("V %g", round($currentY / $grid) * $grid);
            break;
         case 'v': // rel vert
            $currentY += (float)$tokens[$i++]; $newD[] = sprintf("V %g", round($currentY / $grid) * $grid);
            break;
         default:
            $i++;
            break;
      }
   }
   $path['d'] = implode(' ', $newD);
}

AddInkscapeGrid($xml);
//$xml->asXML($outputFile);
$xmlString = $xml->asXML();
$xmlString = str_replace('xmlns:inkscape="http://inkscape.org"', '', $xmlString);
$xmlString = str_replace('xmlns:inkscape="http://inkscape.org"', 'xmlns:inkscape="http://inkscape.org"', $xmlString);
$xmlString = str_replace('<sodipodi:grid', '<inkscape:grid', $xmlString);
file_put_contents($outputFile, $xmlString);
echo "done.".PHP_EOL;
?>
