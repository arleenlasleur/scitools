<?php
if ($argc < 3) {
    die("Call: php map_s3_obj_t3d.php <input.obj> <output.t3d>" . PHP_EOL);
}

$inputFile = $argv[1];
$outputFile = $argv[2];

if (!file_exists($inputFile)) {
    die("Input file not found: " . $inputFile . PHP_EOL);
}

$lines = file($inputFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

$vertices = array();
$faces = array();

// Парсинг вершин и полигонов из OBJ
foreach ($lines as $line) {
    $line = trim($line);
    if ($line === "" || $line[0] === "#") {
        continue;
    }

    // Разбиваем строку по любым пробельным символам
    $parts = preg_split('/\s+/', $line);
    $type = $parts[0];

    if ($type === "v" && count($parts) >= 4) {
        $x = (float)$parts[1];
        $y = (float)$parts[2];
        $z = (float)$parts[3];

        // Обратное преобразование осей (Blender OBJ -> Unreal T3D)
        $rawX = $x;
        $rawY = $z;
        $rawZ = $y;

        $vertices[] = array($rawX, $rawY, $rawZ);
    } elseif ($type === "f" && count($parts) >= 4) {
        $faceIndices = array();
        $partCount = count($parts);
        for ($i = 1; $i < $partCount; $i++) {
            // Обработка формата "v", "v/vt" или "v/vt/vn"
            $vData = explode("/", $parts[$i]);
            $vIndex = (int)$vData[0];

            // Поддержка отрицательных (относительных) индексов OBJ
            if ($vIndex < 0) {
                $vIndex = count($vertices) + $vIndex;
            } else {
                $vIndex = $vIndex - 1;
            }

            if (isset($vertices[$vIndex])) {
                $faceIndices[] = $vIndex;
            }
        }

        if (count($faceIndices) >= 3) {
            // Инвертируем порядок вершин обратно для сохранения корректных нормалей
            $faces[] = array_reverse($faceIndices);
        }
    }
}

// Форматирование числа в стиле UnrealEd (+00000.000000)
function formatUnrealFloat($val) {
    if (abs($val) < 0.000001) {
        $val = 0.0;
    }
    $sign = ($val >= 0) ? "+" : "-";
    return $sign . sprintf("%012.6f", abs($val));
}

function formatUnrealVector($v) {
    return formatUnrealFloat($v[0]) . "," . formatUnrealFloat($v[1]) . "," . formatUnrealFloat($v[2]);
}

// Вычисление нормали полигона (метод Ньюэлла для плоских n-гонов)
function computeNormal($polyVerts) {
    $nx = 0.0;
    $ny = 0.0;
    $nz = 0.0;
    $count = count($polyVerts);

    for ($i = 0; $i < $count; $i++) {
        $curr = $polyVerts[$i];
        $next = $polyVerts[($i + 1) % $count];

        $nx += ($curr[1] - $next[1]) * ($curr[2] + $next[2]);
        $ny += ($curr[2] - $next[2]) * ($curr[0] + $next[0]);
        $nz += ($curr[0] - $next[0]) * ($curr[1] + $next[1]);
    }

    $len = sqrt($nx * $nx + $ny * $ny + $nz * $nz);
    if ($len > 0.000001) {
        return array($nx / $len, $ny / $len, $nz / $len);
    }
    return array(0.0, 0.0, 1.0);
}

// Генерация базовых осей текстуры TextureU и TextureV, перпендикулярных нормали
function computeTextureAxes($normal) {
    $up = (abs($normal[2]) < 0.999) ? array(0.0, 0.0, 1.0) : array(1.0, 0.0, 0.0);

    // Vector Cross Product: U = Up x Normal
    $ux = $up[1] * $normal[2] - $up[2] * $normal[1];
    $uy = $up[2] * $normal[0] - $up[0] * $normal[2];
    $uz = $up[0] * $normal[1] - $up[1] * $normal[0];

    $uLen = sqrt($ux * $ux + $uy * $uy + $uz * $uz);
    $u = ($uLen > 0.000001) ? array($ux / $uLen, $uy / $uLen, $uz / $uLen) : array(1.0, 0.0, 0.0);

    // Vector Cross Product: V = Normal x U
    $vx = $normal[1] * $u[2] - $normal[2] * $u[1];
    $vy = $normal[2] * $u[0] - $normal[0] * $u[2];
    $vz = $normal[0] * $u[1] - $normal[1] * $u[0];

    return array($u, array($vx, $vy, $vz));
}

// Сборка T3D файла (формат Brush -> Import для UnrealEd 2.1 / UE1)
$t3dOutput = "Begin PolyList" . PHP_EOL;

foreach ($faces as $face) {
    $polyVerts = array();
    foreach ($face as $vIdx) {
        $polyVerts[] = $vertices[$vIdx];
    }

    $origin = $polyVerts[0];
    $normal = computeNormal($polyVerts);
    $texAxes = computeTextureAxes($normal);
    $texU = $texAxes[0];
    $texV = $texAxes[1];

    $t3dOutput .= "   Begin Polygon" . PHP_EOL;
    $t3dOutput .= "      Origin   " . formatUnrealVector($origin) . PHP_EOL;
    $t3dOutput .= "      Normal   " . formatUnrealVector($normal) . PHP_EOL;
    $t3dOutput .= "      TextureU " . formatUnrealVector($texU) . PHP_EOL;
    $t3dOutput .= "      TextureV " . formatUnrealVector($texV) . PHP_EOL;

    foreach ($polyVerts as $v) {
        $t3dOutput .= "      Vertex   " . formatUnrealVector($v) . PHP_EOL;
    }

    $t3dOutput .= "   End Polygon" . PHP_EOL;
}

$t3dOutput .= "End PolyList" . PHP_EOL;

if (file_put_contents($outputFile, $t3dOutput) !== false) {
    echo "Converted. Verts: " . count($vertices) . ", polygons: " . count($faces) . PHP_EOL;
} else {
    echo "Write error." . PHP_EOL;
}
?>