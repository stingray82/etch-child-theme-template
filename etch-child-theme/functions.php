<?php
/**
 *
 * @package etch-child-theme
 * @since 1.0.0
 *
 * NOTE: Use this theme to add your own customizations.
 */

// Use the below to include all your other files
require_once get_stylesheet_directory() . '/inc/dist/uupd/update-function.php';

// Add Ours and Etch's stylesheet
add_action( 'wp_enqueue_scripts', 'enqueue_parent_and_child_styles' );
function enqueue_parent_and_child_styles() {

	// Parent theme stylesheet
	wp_enqueue_style(
		'parent-style',
		get_template_directory_uri() . '/style.css'
	);

	// Child theme stylesheet
	wp_enqueue_style(
		'child-style',
		get_stylesheet_uri(),
		array( 'parent-style' ),
		wp_get_theme()->get( 'Version' )
	);
}




// Add your own customizations here.
