FROM mplx/alpine311-php73:latest

ENV PIXELFED="v0.11.0" \
    TZ="Europe/Berlin" \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    BROADCAST_DRIVER=log \
    QUEUE_DRIVER=redis \
    HORIZON_PREFIX=horizon-pixelfed \
    SESSION_SECURE_COOKIE=true \
    API_BASE="/api/1/" \
    API_SEARCH="/api/search" \
    ENFORCE_EMAIL_VERIFICATION=true \
    REMOTE_FOLLOW=true \
    ACTIVITY_PUB=true

LABEL maintainer="mplx <mplx+docker@donotreply.at>"

EXPOSE 8000/tcp

RUN set -xe && \
    mkdir -p /home/project/pixelfed/ && \
    echo $TZ > /etc/TZ &&\
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    apk add --no-cache --update git mysql-client jpegoptim optipng pngquant && \
    rm -rf /var/cache/apk/* && \
    php-ext.sh enable 'bcmath curl exif gd imagick intl fileinfo pcntl' && \
    php-ext.sh enable 'pdo mysqlnd pdo_mysql' && \
    php-ext.sh enable 'pgsql pdo_pgsql' && \
    php-ext.sh enable 'opcache apcu ldap session' && \
    setup-nginx.sh symfony4 /home/project/pixelfed/public && \
    sed -i 's|listen 80;|listen 8000;|' /etc/nginx/conf.d/default.conf && \
    sed -i -e '/blockdot.conf/s/^#*/#/' -i /etc/nginx/conf.d/default.conf && \
    sed -i -e 's/^memory_limit =.*/memory_limit = 3072M/' /etc/php7/php.ini && \
    sed -i '/docker_realip/s/#//' /etc/nginx/conf.d/default.conf && \
    sed -i 's|;opcache.memory_consumption=128|opcache.memory_consumption=64|' /etc/php7/php.ini && \
    sed -i 's|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=1000|' /etc/php7/php.ini && \
    sed -i 's|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|' /etc/php7/php.ini && \
    sed -i 's|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=16|' /etc/php7/php.ini && \
    sed -i 's|post_max_size = 8M|post_max_size = 64M|' /etc/php7/php.ini && \
    sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 128M|' /etc/php7/php.ini && \
    sed -i 's|;clear_env = no|clear_env = no|' /etc/php7/php-fpm.d/www.conf && \
    composer self-update

WORKDIR /home/project/pixelfed

RUN git clone --branch ${PIXELFED} --depth 1 https://github.com/pixelfed/pixelfed /home/project/pixelfed && \
    composer config platform.php "7.3" && \
    composer config platform.ext-iconv "7.3" && \
    composer require --update-no-dev symfony/polyfill-iconv && \
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --no-progress --optimize-autoloader --no-interaction && \
    mv storage storage.tpl && \
    rm .env.example && \
    rm .env.docker && \
    rm .env.testing && \
    chown -R project:project /home/project

COPY horizon.conf /etc/supervisor/conf.d/
COPY entrypoint.sh /usr/sbin/
COPY crontab /var/spool/cron/crontabs/project

ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
CMD ["web"]

VOLUME ["/home/project/pixelfed/storage"]
