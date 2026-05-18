FROM wordpress:6.8.3-php8.3-apache

COPY target-content/plugins/local-lab-audit /usr/src/wordpress/wp-content/plugins/local-lab-audit
COPY target-content/themes/packetlab /usr/src/wordpress/wp-content/themes/packetlab
