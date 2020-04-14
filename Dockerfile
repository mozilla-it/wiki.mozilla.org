FROM php:7.2-cli AS composer

RUN set -ex; \
	EXPECTED_SIGNATURE=$(curl https://composer.github.io/installer.sig); \
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"\
	php -r "if (hash_file('SHA384', 'composer-setup.php') === ${EXPECTED_SIGNATURE}){ echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"; \
	php composer-setup.php --install-dir=/bin --filename=composer; \
	php -r "unlink('composer-setup.php');";

# Reference: https://github.com/wikimedia/mediawiki-docker/tree/master/1.31
FROM mediawiki:1.31.5

ENV MEDIAWIKI_MAJOR_VERSION 1.31
ENV MEDIAWIKI_BRANCH REL1_31
ENV MEDIAWIKI_VERSION 1.31.5

# Install mediawiki packages
RUN set -eux; \
    apt-get update && \
	apt-get install -y --no-install-recommends \
			unzip \
            libxml2-dev \
            zip \
            libzip-dev \
			libmemcached-dev \
			ffmpeg \
			graphviz \
			pandoc \
			imagemagick && \
    docker-php-ext-configure zip --with-libzip && \
    docker-php-ext-install -j "$(nproc)" zip \
										xml \
										mbstring \
										mysqli && \
	pecl install memcached memcache && \
	docker-php-ext-enable memcached memcache && \
	echo "extension=memcache.so" >> /usr/local/etc/php/conf.d/memcached.ini && \
    apt-get purge -y --auto-remove && \
    apt-get clean -y && \
    apt-get autoclean -y && \
    rm -rf /var/lib/apt/lists/* /var/lib/{apt,dpkg,cache,log}/ /var/tmp/* /tmp/*.deb /tmp/pear/

# Setup mediawiki config folder
RUN set -eux; \
	mkdir -p /etc/wikimo && \
	chown www-data:www-data /etc/wikimo && \
	chmod 0744 /etc/wikimo

WORKDIR /var/www/html

COPY --from=composer /bin/composer /bin/composer
COPY extensions /var/www/html/extensions/
COPY skins/ /var/www/html/skins/
COPY composer.* /var/www/html/
COPY contribute.json /var/www/html/contribute.json
