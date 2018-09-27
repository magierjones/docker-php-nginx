FROM pritkin/nginx:1.15.3

COPY docker /

ENV PHP_VERSION=7.2.9 \
    PHPIZE_DEPS=" \
		autoconf \
		dpkg-dev dpkg \
		file \
		g++ \
		gcc \
		libc-dev \
		make \
		pkgconf \
		re2c \
		"

RUN PHP_INI_DIR=/usr/local/etc/php \
    && mkdir -p ${PHP_INI_DIR}/conf.d \
    && PHP_URL="https://secure.php.net/get/php-${PHP_VERSION}.tar.xz/from/this/mirror" \
    && PHP_ASC_URL="https://secure.php.net/get/php-${PHP_VERSION}.tar.xz.asc/from/this/mirror" \
    && PHP_SHA256="3585c1222e00494efee4f5a65a8e03a1e6eca3dfb834814236ee7f02c5248ae0"  \
    && PHP_MD5="" \
    && PHP_EXTRA_CONFIGURE_ARGS="--enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --disable-cgi" \
# Apply stack smash protection to functions using local buffers and alloca()
# Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# Enable optimization (-O2)
# Enable linker optimization (this sorts the hash buckets to improve cache locality, and is non-default)
# Adds GNU HASH segments to generated executables (this is used if present, and is much faster than sysv hash; in this configuration, sysv hash is also generated)
# https://github.com/docker-library/php/issues/272
    && PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2" \
    && PHP_CPPFLAGS="${PHP_CFLAGS}" \
    && PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
    && GPG_KEYS="1729F83938DA44E27BA0F4D3DBDB397470D12172 B1B44D8F021E4E2D6021E995DC9FF8D3EE5AF27F" \
# ensure www-data user exists
    && set -x \
	&& addgroup -g 82 -S www-data \
	&& adduser -u 82 -D -S -G www-data www-data \
# 82 is the standard uid/gid for "www-data" in Alpine
# http://git.alpinelinux.org/cgit/aports/tree/main/apache2/apache2.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/lighttpd/lighttpd.pre-install?h=v3.3.2
# http://git.alpinelinux.org/cgit/aports/tree/main/nginx-initscripts/nginx-initscripts.pre-install?h=v3.3.2
    && set -xe; \
	\
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
		wget \
	; \
	\
	mkdir -p /usr/src; \
	cd /usr/src; \
	\
	wget -O php.tar.xz "${PHP_URL}"; \
	\
	if [ -n "${PHP_SHA256}" ]; then \
		echo "${PHP_SHA256} *php.tar.xz" | sha256sum -c -; \
	fi; \
	if [ -n "${PHP_MD5}" ]; then \
		echo "${PHP_MD5} *php.tar.xz" | md5sum -c -; \
	fi; \
	\
	if [ -n "${PHP_ASC_URL}" ]; then \
		wget -O php.tar.xz.asc "${PHP_ASC_URL}"; \
		export GNUPGHOME="$(mktemp -d)"; \
		for key in ${GPG_KEYS}; do \
			gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
		done; \
		gpg --batch --verify php.tar.xz.asc php.tar.xz; \
		command -v gpgconf > /dev/null && gpgconf --kill all; \
		rm -rf "${GNUPGHOME}"; \
	fi; \
	\
	apk del .fetch-deps \
	&& apk add --no-cache --virtual .build-deps \
		${PHPIZE_DEPS} \
		argon2-dev \
		coreutils \
		curl-dev \
		libedit-dev \
		libressl-dev \
		libsodium-dev \
		libxml2-dev \
		sqlite-dev \
	\
	# persistent / runtime deps
    && apk add --no-cache --virtual .persistent-deps \
        ca-certificates \
        curl \
        tar \
        xz \
        # https://github.com/docker-library/php/issues/494
        libressl \
        icu-dev \
	&& export CFLAGS="${PHP_CFLAGS}" \
		CPPFLAGS="${PHP_CPPFLAGS}" \
		LDFLAGS="${PHP_LDFLAGS}" \
	&& docker-php-source extract \
	&& cd /usr/src/php \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--with-config-file-path="${PHP_INI_DIR}" \
		--with-config-file-scan-dir="${PHP_INI_DIR}/conf.d" \
		\
# make sure invalid --configure-flags are fatal errors intead of just warnings
		--enable-option-checking=fatal \
		\
# https://github.com/docker-library/php/issues/439
		--with-mhash \
		\
# --enable-ftp is included here because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
		--enable-ftp \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# https://wiki.php.net/rfc/argon2_password_hash (7.2+)
		--with-password-argon2 \
# https://wiki.php.net/rfc/libsodium
		--with-sodium=shared \
		\
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
		\
# bundled pcre does not support JIT on s390x
# https://manpages.debian.org/stretch/libpcre3-dev/pcrejit.3.en.html#AVAILABILITY_OF_JIT_SUPPORT
		$(test "$gnuArch" = 's390x-linux-gnu' && echo '--without-pcre-jit') \
		\
		${PHP_EXTRA_CONFIGURE_ARGS} \
	&& make -j "$(nproc)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	\
# https://github.com/docker-library/php/issues/692 (copy default example "php.ini" files somewhere easily discoverable)
	&& cp -v php.ini-* "${PHP_INI_DIR}/" \
	\
	&& cd / \
	&& docker-php-source delete \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .php-rundeps $runDeps \
	\
	&& apk del .build-deps \
	\
# https://github.com/docker-library/php/issues/443
	&& pecl update-channels \
	&& rm -rf /tmp/pear ~/.pearrc \
# sodium was built as a shared module (so that it can be replaced later if so desired), so let's enable it too (https://github.com/docker-library/php/issues/598)
    && docker-php-ext-enable sodium \
    && docker-php-ext-configure intl \
        --enable-intl \
     && docker-php-ext-install \
        intl \
        opcache \
        pdo_mysql

ENTRYPOINT ["docker-php-entrypoint"]

STOPSIGNAL SIGTERM

HEALTHCHECK --interval=5s --timeout=3s --retries=2 \
    CMD \
    wget -q -O - localhost/ping || exit 1

CMD ["php-fpm"]