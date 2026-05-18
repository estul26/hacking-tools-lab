<?php

if (!defined('ABSPATH')) {
    exit;
}

function packetlab_enqueue_styles() {
    wp_enqueue_style('packetlab-style', get_stylesheet_uri(), array(), '0.4.2');
}

add_action('wp_enqueue_scripts', 'packetlab_enqueue_styles');
