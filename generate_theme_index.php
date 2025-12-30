<?php
/**
 * generate_theme_index.php
 *
 * Usage:
 * php generate_theme_index.php style.css changelog.txt output_path github_user static_domain [slug_override] [repo_name_override] static.txt zip_name
 */

function get_arg_or_env($index, $env_var, $default = '') {
    global $argv;
    return $argv[$index] ?? getenv($env_var) ?? $default;
}

$style_file     = get_arg_or_env(1, 'STYLE_FILE');
$changelog_file = get_arg_or_env(2, 'CHANGELOG_FILE');
$output_dir     = rtrim(get_arg_or_env(3, 'STATIC_SUBFOLDER'), "/\\");
$github_user    = get_arg_or_env(4, 'GITHUB_USER');
$static_domain  = rtrim(get_arg_or_env(5, 'CDN_PATH'), "/");
$slug           = get_arg_or_env(6, 'REPO_NAME');
$repo_name      = get_arg_or_env(7, 'REPO_NAME');
$static_file    = get_arg_or_env(8, 'STATIC_FILE');
$zip_filename   = get_arg_or_env(9, 'ZIP_NAME');

if (!file_exists($style_file)) exit("\n❌ style.css missing: $style_file\n");
if (!file_exists($changelog_file)) exit("\n❌ Changelog missing: $changelog_file\n");
if (!file_exists($static_file)) exit("\n❌ Static file missing: $static_file\n");
if (!is_dir($output_dir)) {
    if (!mkdir($output_dir, 0775, true)) exit("\n❌ Failed to create output directory: $output_dir\n");
}

function read_theme_headers($file) {
    $headers = [
        'Theme Name'        => '',
        'Theme URI'         => '',
        'Description'       => '',
        'Author'            => '',
        'Author URI'        => '',
        'Version'           => '',
        'Requires at least' => '',
        'Tested up to'      => '',
        'Requires PHP'      => '',
        'Text Domain'       => '',
        'Tags'              => '',
    ];
    $data = file_exists($file) ? file_get_contents($file) : '';
    foreach ($headers as $key => $val) {
        if (preg_match('/' . preg_quote($key, '/') . ':\s*(.+)/i', $data, $m)) {
            $headers[$key] = trim($m[1]);
        }
    }
    return $headers;
}

function parse_changelog($file) {
    if (!file_exists($file)) return '';
    $txt = file_get_contents($file);
    $txt = str_replace("\r", "", $txt);
    // keep it plain-ish; updater UIs usually render line breaks
    return nl2br(trim($txt));
}

function parse_readme_sections($file) {
    if (!file_exists($file)) return [];
    $text = file_get_contents($file);
    $sections = [];
    preg_match_all('/==\s*(.*?)\s*==\s*(.*?)(?=(?:==|$))/s', $text, $matches, PREG_SET_ORDER);
    foreach ($matches as $match) {
        $key = strtolower(str_replace(' ', '_', trim($match[1])));
        $sections[$key] = nl2br(trim($match[2]));
    }
    return $sections;
}

$headers = read_theme_headers($style_file);
if (empty($headers['Version']) || empty($headers['Theme Name'])) {
    exit("\n❌ Missing Version or Theme Name in style.css headers.\n");
}

$sections = parse_readme_sections($static_file);
$sections['changelog'] = parse_changelog($changelog_file);

$json = [
    'type'            => 'theme',
    'slug'            => $slug,
    'name'            => $headers['Theme Name'],
    'version'         => $headers['Version'],
    'author'          => $headers['Author'] ?? 'Unknown',
    'author_homepage' => $headers['Author URI'] ?? '',
    'homepage'        => $headers['Theme URI'] ?? '',
    'requires_php'    => $headers['Requires PHP'] ?? '',
    'requires'        => $headers['Requires at least'] ?? '',
    'tested'          => $headers['Tested up to'] ?? '',
    'sections'        => $sections,
    'last_updated'    => date('Y-m-d H:i:s'),
    'download_url'    => "https://github.com/{$github_user}/{$repo_name}/releases/latest/download/{$zip_filename}",
    'banners' => [
        'low'  => "$static_domain/banner-772x250.png",
        'high' => "$static_domain/banner-1544x500.png"
    ],
    'icons' => [
        '1x' => "$static_domain/icon-128.png",
        '2x' => "$static_domain/icon-256.png",
    ]
];

$output_file = "$output_dir/index.json";
file_put_contents($output_file, json_encode($json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

echo "✅ Theme update metadata written to:\n\n{$static_domain}/index.json\n\n";
