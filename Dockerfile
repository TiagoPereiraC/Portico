FROM php:8.2-apache

RUN docker-php-ext-install pdo pdo_mysql

RUN a2enmod rewrite

COPY --chown=www-data:www-data api/ /var/www/html/api/
COPY --chown=www-data:www-data web-ui/ /var/www/html/web-ui/

EXPOSE 80
