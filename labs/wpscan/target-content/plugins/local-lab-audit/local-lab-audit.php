<?php
/**
 * Plugin Name: Local Lab Audit
 * Plugin URI: https://example.test/local-lab-audit
 * Description: Small local-only plugin that gives WPScan a predictable plugin to enumerate.
 * Version: 1.2.3
 * Author: Packet Lab
 * Author URI: https://example.test
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) {
    exit;
}

function local_lab_audit_enqueue_assets() {
    wp_enqueue_style(
        'local-lab-audit',
        plugins_url('assets/audit.css', __FILE__),
        array(),
        '1.2.3'
    );
}

add_action('wp_enqueue_scripts', 'local_lab_audit_enqueue_assets');

function local_lab_audit_banner() {
    return '<p class="local-lab-audit-banner">Local WPScan practice plugin is active.</p>';
}

add_shortcode('local_lab_audit', 'local_lab_audit_banner');
