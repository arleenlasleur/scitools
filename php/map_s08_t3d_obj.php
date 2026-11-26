<?php
if ($argc < 3) {
    die("Call: php t3d_to_obj.php <input.t3d> <output.obj>" . PHP_EOL);
}

$inputFile = $argv[1];
$outputFile = $argv[2];

if (!file_exists($inputFile)) {
    die("Input tile not found." . PHP_EOL);
}

$t3dContent = file_get_contents($inputFile);

$vertices = [];
$faces = [];
$vertexMap = [];
$vertexCount = 0;

$offset = 0;

// Посегментный поиск блоков полигонов без регулярных выражений
while (($polyStart = strpos($t3dContent, "Begin Polygon", $offset)) !== false) {
    $polyEnd = strpos($t3dContent, "End Polygon", $polyStart);
    if ($polyEnd === false) {
        break;
    }

    // Вырезаем контент текущего полигона
    $polyBlock = substr($t3dContent, $polyStart, $polyEnd - $polyStart);
    $offset = $polyEnd + 11; // Длина "End Polygon"

    $polyVertexIndices = [];
    $lineOffset = 0;

    // Ищем все строки "Vertex" внутри блока полигона
    while (($vertexPos = strpos($polyBlock, "Vertex", $lineOffset)) !== false) {
        $lineEnd = strpos($polyBlock, PHP_EOL, $vertexPos);
        if ($lineEnd === false) {
            $lineEnd = strlen($polyBlock);
        }

        $line = substr($polyBlock, $vertexPos, $lineEnd - $vertexPos);
        $lineOffset = $lineEnd;

        // Очищаем строку от ключевого слова и пробелов
        $coordsText = trim(substr($line, 6)); 
        if ($coordsText === "") {
            continue;
        }

        // Разбиваем строку по запятым на X, Y, Z
        $coords = explode(",", $coordsText);
        if (count($coords) === 3) {
            $rawX = (float)trim($coords[0]);
            $rawY = (float)trim($coords[1]);
            $rawZ = (float)trim($coords[2]);

            $x = $rawX; // Blender axis fix
            $y = $rawZ;
            $z = $rawY;

            $vKey = $x . "_" . $y . "_" . $z;

            if (!isset($vertexMap[$vKey])) {
                $vertexCount++;
                $vertices[] = [$x, $y, $z];
                $vertexMap[$vKey] = $vertexCount;
            }

            $polyVertexIndices[] = $vertexMap[$vKey];
        }
    }

    // Автоматическая триангуляция метода "веера" (Fan Triangulation)
    $vCountInPoly = count($polyVertexIndices);
    if ($vCountInPoly >= 3) {
        for ($i = 1; $i < $vCountInPoly - 1; $i++) {
            // Внимание: порядок вершин изменен на (0, i+1, i) вместо (0, i, i+1).
            // Это необходимо, чтобы из-за смены знака оси нормали полигонов не вывернулись наизнанку.
            $faces[] = [
                $polyVertexIndices[0],
                $polyVertexIndices[$i + 1],
                $polyVertexIndices[$i]
            ];
        }
    }
}

// Сборка OBJ контента
$objOutput = "# Converted from T3D Brush (Axis Aligned for Blender)" . PHP_EOL;
$objOutput .= "# Vertices: " . count($vertices) . PHP_EOL;
$objOutput .= "# Faces: " . count($faces) . PHP_EOL . PHP_EOL;

foreach ($vertices as $v) {
    $objOutput .= "v " . $v[0] . " " . $v[1] . " " . $v[2] . PHP_EOL;
}

$objOutput .= PHP_EOL;

foreach ($faces as $f) {
    $objOutput .= "f " . $f[0] . " " . $f[1] . " " . $f[2] . PHP_EOL;
}

if (file_put_contents($outputFile, $objOutput) !== false) {
    echo "Converted. Verts: " . count($vertices) . ", faces: " . count($faces) . PHP_EOL;
} else {
    echo "File write error." . PHP_EOL;
}
?>