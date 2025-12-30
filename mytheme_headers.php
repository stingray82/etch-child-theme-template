<?php
/**
 * mytheme_headers.php
 *
 * Usage:
 *   php mytheme_headers.php path/to/theme/style.css
 *
 * Updates/creates the theme header block in style.css:
 * Theme Name, Description, Version, Tested up to (auto default), Requires at least, Requires PHP, etc.
 */

if ($argc < 2) {
    fwrite(STDERR, "Usage: php {$argv[0]} path/to/style.css\n");
    exit(1);
}

$styleFile = $argv[1];
if (!file_exists($styleFile)) {
    fwrite(STDERR, "style.css not found: {$styleFile}\n");
    exit(1);
}

function get_latest_wp_version($fallback = '6.5') {
    $url = "https://api.wordpress.org/core/version-check/1.7/";
    $json = @file_get_contents($url);
    if ($json) {
        $data = json_decode($json, true);
        return $data['offers'][0]['current'] ?? $fallback;
    }
    fwrite(STDERR, "[warning] Could not fetch latest WP; using fallback {$fallback}\n");
    return $fallback;
}

function extract_field($text, $key) {
    if (preg_match('/^\s*' . preg_quote($key, '/') . '\s*:\s*(.*?)\s*$/mi', $text, $m)) {
        return trim($m[1]);
    }
    return null;
}

function prompt($label, $current, $default, $required = false) {
    if ($current !== null && $current !== '') {
        echo "{$label} (current: {$current}, default: {$default}): ";
    } else {
        echo "{$label} (default: {$default}): ";
    }
    $in = trim(fgets(STDIN));
    if ($in === '') {
        if ($required && ($default === null || $default === '')) {
            echo "{$label} is required.\n";
            return prompt($label, $current, $default, $required);
        }
        return $default;
    }
    return $in;
}

$latest = get_latest_wp_version();

// Read style.css
$content = file_get_contents($styleFile);

// Find existing header comment block (first /* ... */)
$headerBlock = '';
$headerStart = null;
$headerEnd = null;

if (preg_match('/\/\*.*?\*\//s', $content, $m, PREG_OFFSET_CAPTURE)) {
    $headerBlock = $m[0][0];
    $headerStart = $m[0][1];
    $headerEnd = $headerStart + strlen($headerBlock);
}

$fields = [
    'Theme Name'        => null,     // required
    'Theme URI'         => '',
    'Description'       => null,     // required
    'Author'            => 'reallyusefulplugins.com',
    'Author URI'        => 'https://reallyusefulplugins.com',
    'Version'           => '1.0',
    'Requires at least' => '6.5',
    'Tested up to'      => null,     // default from API
    'Requires PHP'      => '8.0',
    'License'           => 'GPL-2.0-or-later',
    'License URI'       => 'https://www.gnu.org/licenses/gpl-2.0.html',
    'Text Domain'       => null,     // required (strongly recommended)
    'Tags'              => '',
];

if ($headerBlock) {
    foreach ($fields as $k => $def) {
        $val = extract_field($headerBlock, $k);
        if ($val !== null && $val !== '') {
            $fields[$k] = $val;
        }
    }
}

// Prompts (required)
$fields['Version']     = prompt('Version',     $fields['Version'],     $fields['Version'], true);
$fields['Theme Name']  = prompt('Theme Name',  $fields['Theme Name'],  $fields['Theme Name'], true);
$fields['Description'] = prompt('Description', $fields['Description'], $fields['Description'], true);
$fields['Text Domain'] = prompt('Text Domain', $fields['Text Domain'], $fields['Text Domain'], true);

// Tested up to defaults to latest WP if blank
$fields['Tested up to'] = prompt('Tested up to', $fields['Tested up to'], $latest, false);

// Optional prompts
foreach ([
    'Theme URI','Author','Author URI','Requires at least','Requires PHP','License','License URI','Tags'
] as $key) {
    $fields[$key] = prompt($key, $fields[$key], $fields[$key], false);
}

// Build new header block
$order = [
    'Theme Name','Theme URI','Description','Author','Author URI','Version',
    'Requires at least','Tested up to','Requires PHP','License','License URI','Text Domain','Tags'
];

$newHeader = "/*\n";
foreach ($order as $k) {
    $v = $fields[$k];
    if ($v === null) $v = '';
    $newHeader .= $k . ": " . $v . "\n";
}
$newHeader .= "*/\n";

// Replace or insert at top
if ($headerBlock && $headerStart !== null) {
    $content = substr($content, 0, $headerStart) . $newHeader . substr($content, $headerEnd);
} else {
    $content = $newHeader . "\n" . $content;
}

if (file_put_contents($styleFile, $content) !== false) {
    echo "→ Theme headers updated successfully in {$styleFile}\n";
} else {
    fwrite(STDERR, "Failed to write style.css\n");
    exit(1);
}
