<?php
/**
 * Скрипт для инвертирования (умножения на -1) координат по выбранной оси в файле .t3d
 * Совместимость: PHP 5.2+
 */

// Настройки
$inputFile  = 'nv3_c.t3d';        // Исходный файл
$outputFile = 'map_mirror.t3d'; // Результирующий файл
$axis       = 'Z';              // Ось для инверсии: 'X', 'Y' или 'Z'

// Глобальная переменная для передачи оси в callback-функцию (требование PHP 5.2)
$GLOBALS['target_axis'] = strtoupper($axis);

if (!in_array($GLOBALS['target_axis'], array('X', 'Y', 'Z'))) {
    die("Ошибка: неверная ось. Используйте X, Y или Z.\n");
}

if (!file_exists($inputFile)) {
    die("Ошибка: файл '{$inputFile}' не найден.\n");
}

$content = file_get_contents($inputFile);
if ($content === false) {
    die("Ошибка: не удалось прочитать файл '{$inputFile}'.\n");
}

/**
 * Callback-функция для инверсии координат в формате Location=(X=...,Y=...,Z=...)
 */
function invert_named_axis_callback($matches) {
    $prefix = $matches[1]; // Например: "Location=(" или "Origin=("
    $body   = $matches[2]; // Внутренности скобок: "X=10.0,Y=-20.5,Z=30.0"
    $axis   = $GLOBALS['target_axis'];

    // Ищем нужную ось внутри скобок (например, Y=123.45 или Y=+123.45)
    $pattern = '/(\b' . $axis . '\s*=\s*)([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/i';
    $newBody = preg_replace_callback($pattern, 'invert_number_callback', $body);

    return $prefix . $newBody . ')';
}

/**
 * Callback-функция для инверсии координат в формате Vertex +00123.45,-00678.90,+00010.00
 */
function invert_vertex_callback($matches) {
    $prefix = $matches[1]; // "Vertex " или "Origin " (если без скобок)
    $coords = array(
        'X' => $matches[2],
        'Y' => $matches[3],
        'Z' => $matches[4]
    );
    $axis = $GLOBALS['target_axis'];

    $coords[$axis] = invert_value_string($coords[$axis]);

    return $prefix . $coords['X'] . ',' . $coords['Y'] . ',' . $coords['Z'];
}

/**
 * Вспомогательный callback для замены числа
 */
function invert_number_callback($matches) {
    return $matches[1] . invert_value_string($matches[2]);
}

/**
 * Функция инвертирования строкового представления числа с сохранением формата
 */
function invert_value_string($valStr) {
    $num = (float)$valStr;
    // Если значение равно 0, оставляем как есть, чтобы избежать "-0"
    if ($num == 0) {
        return $valStr;
    }

    // Проверяем, используется ли в исходной строке формат со знаком '+' и ведущими нулями (характерно для Vertex)
    if (preg_match('/^([+-])(0+\d+\.\d+)$/', $valStr, $m)) {
        $newSign = ($m[1] === '-') ? '+' : '-';
        return $newSign . $m[2];
    }

    // Обычное число с плавающей точкой
    $inverted = $num * -1;
    
    // Если в исходном числе была точка, сохраняем дробную часть (если при умножении она отбросилась)
    if (strpos($valStr, '.') !== false && strpos((string)$inverted, '.') === false) {
        return number_format($inverted, 6, '.', '');
    }

    return (string)$inverted;
}

// 1. Обрабатываем конструкции вида Location=(X=...,Y=...,Z=...), Origin=(...), PrePivot=(...) и т.д.
// Не трогаем Rotation=(Pitch=...,Yaw=...,Roll=...), так как там нет X, Y, Z
$content = preg_replace_callback(
    '/(\b[a-zA-Z0-9_]+\s*=\s*\()([^)]+\))/i',
    'invert_named_axis_callback',
    $content
);

// 2. Обрабатываем вершины полигонов CSG (формат: Vertex +00128.000000,-00128.000000,+00000.000000)
$numPattern = '[+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?';
$vertexPattern = '/(\b(?:Vertex|Origin|Normal|TextureU|TextureV)\s+)(' . $numPattern . '),(' . $numPattern . '),(' . $numPattern . ')/i';
$content = preg_replace_callback(
    $vertexPattern,
    'invert_vertex_callback',
    $content
);

// Сохраняем результат
if (file_put_contents($outputFile, $content) !== false) {
    echo "Готово! Ось {$GLOBALS['target_axis']} инвертирована. Результат сохранен в '{$outputFile}'.\n";
} else {
    die("Ошибка: не удалось сохранить файл '{$outputFile}'.\n");
}
?>
