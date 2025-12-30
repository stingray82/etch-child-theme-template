<?php

//UPDATE Function
add_action('after_setup_theme', function () {
    require_once get_stylesheet_directory() . '/inc/dist/uupd/updater.php';

    $theme = wp_get_theme(); // child theme (stylesheet)
    $current_version = $theme->get('Version');

    $config = [
        'slug'   => $theme->get_stylesheet(),             // or 'etch-child-theme'
        'name'   => $theme->get('Name'),                  // or your custom name
        'version'=> $current_version,
        // Public JSON
        'server' => 'https://raw.githubusercontent.com/stingray82/etch-child-theme-template/refs/heads/main/uupd/index.json',
        // Private GitHub
        //'mode'   => 'github_release',
        //'server' => 'https://github.com/stingray82/test-child-theme', // Private Repo
        //'github_token'  => 'Token Goes here', // Needed with a private Repo
    ];

    \UUPD\V1\UUPD_Updater_V1::register($config);
});

