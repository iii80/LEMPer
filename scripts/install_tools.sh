#!/usr/bin/env bash

# LEMPer administration installer
# Min. Requirement  : GNU/Linux Ubuntu 16.04
# Last Build        : 04/10/2019
# Author            : MasEDI.Net (me@masedi.net)
# Since Version     : 1.0.0

# Include helper functions.
if [ "$(type -t run)" != "function" ]; then
    BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
    # shellcheck disable=SC1091
    . "${BASEDIR}/helper.sh"
fi

# Make sure only root can run this installer script.
requires_root

##
# Webadmin install.
#
function init_webadmin_install() {
    # Install Lemper CLI tool.
    echo "Installing Lemper CLI tool..."
    run cp -f bin/lemper-cli.sh /usr/local/bin/lemper-cli
    #run cp -f bin/lemper-cli /usr/local/bin/ && \
    run chmod ugo+x /usr/local/bin/lemper-cli

    if [ ! -d /usr/local/lib/lemper ]; then
        run mkdir -p /usr/local/lib/lemper
    fi

    run cp -f lib/lemper-create.sh /usr/local/lib/lemper/lemper-create && \
    run chmod ugo+x /usr/local/lib/lemper/lemper-create

    run cp -f lib/lemper-db.sh /usr/local/lib/lemper/lemper-db && \
    run chmod ugo+x /usr/local/lib/lemper/lemper-db

    run cp -f lib/lemper-manage.sh /usr/local/lib/lemper/lemper-manage && \
    run chmod ugo+x /usr/local/lib/lemper/lemper-manage

    # Install Web Admin.
    echo "Installing Lemper web panel..."
    if [ ! -d /usr/share/nginx/html/lcp ]; then
        run mkdir -p /usr/share/nginx/html/lcp
    fi

    # Copy default index file.
    run cp -f share/nginx/html/index.html /usr/share/nginx/html/

    # Install PHP Info
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php'
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php56'
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php70'
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php71'
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php72'
    run bash -c 'echo "<?php phpinfo(); ?>" > /usr/share/nginx/html/lcp/phpinfo.php73'

    # Install Adminer for Web-based MySQL Administration Tool
    if [ ! -d /usr/share/nginx/html/lcp/dbadmin ]; then
        run mkdir -p /usr/share/nginx/html/lcp/dbadmin
    fi

    # Overwrite existing.
    run wget -q https://github.com/vrana/adminer/releases/download/v4.8.1/adminer-4.8.1.php \
        -O /usr/share/nginx/html/lcp/dbadmin/index.php
    run wget -q https://github.com/vrana/adminer/releases/download/v4.8.1/editor-4.8.1.php \
        -O /usr/share/nginx/html/lcp/dbadmin/editor.php

    # Install File Manager.
    # Experimental: Tinyfilemanager https://github.com/joglomedia/tinyfilemanager
    # Clone custom TinyFileManager.
    if [ ! -d /usr/share/nginx/html/lcp/filemanager/config ]; then
        run git clone -q --depth=1 --branch=lemperfm_1.3.0 https://github.com/joglomedia/tinyfilemanager.git \
            /usr/share/nginx/html/lcp/filemanager
    else
        local CUR_DIR && \
        CUR_DIR=$(pwd)
        run cd /usr/share/nginx/html/lcp/filemanager && \
        #run git pull -q
        run wget -q https://raw.githubusercontent.com/joglomedia/tinyfilemanager/lemperfm_1.3.0/index.php \
            -O /usr/share/nginx/html/lcp/filemanager/index.php && \
        run cd "${CUR_DIR}" || return 1
    fi

    # Copy TinyFileManager custom account creator.
    if [ -f /usr/share/nginx/html/lcp/filemanager/adduser-tfm.sh ]; then
        run cp -f /usr/share/nginx/html/lcp/filemanager/adduser-tfm.sh /usr/local/lib/lemper/lemper-tfm
        run chmod ugo+x /usr/local/lib/lemper/lemper-tfm
    fi

    # Install Zend OpCache Web Admin.
    run wget -q https://raw.github.com/rlerdorf/opcache-status/master/opcache.php \
        -O /usr/share/nginx/html/lcp/opcache.php

    # Install phpMemcachedAdmin Web Admin.
    if [ ! -d /usr/share/nginx/html/lcp/memcadmin/ ]; then
        run git clone -q --depth=1 --branch=master \
            https://github.com/elijaa/phpmemcachedadmin.git /usr/share/nginx/html/lcp/memcadmin/
    else
        local CUR_DIR && \
        CUR_DIR=$(pwd)
        run cd /usr/share/nginx/html/lcp/memcadmin && \
        run git pull -q && \
        run cd "${CUR_DIR}" || return 1
    fi

    # Configure phpMemcachedAdmin.
    if ! ${DRYRUN}; then
        if [[ ${MEMCACHED_SASL} == "enable" || ${MEMCACHED_SASL} == true ]]; then
            MEMCACHED_SASL_CREDENTIAL="username=${MEMCACHED_USERNAME},
            password=${MEMCACHED_PASSWORD},"
        else
            MEMCACHED_SASL_CREDENTIAL=""
        fi

        run touch /usr/share/nginx/html/lcp/memcadmin/Config/Memcache.php
        cat > /usr/share/nginx/html/lcp/memcadmin/Config/Memcache.php <<EOL
<?php
return [
    'stats_api' => 'Server',
    'slabs_api' => 'Server',
    'items_api' => 'Server',
    'get_api' => 'Server',
    'set_api' => 'Server',
    'delete_api' => 'Server',
    'flush_all_api' => 'Server',
    'connection_timeout' => '1',
    'max_item_dump' => '100',
    'refresh_rate' => 2.0,
    'memory_alert' => '80',
    'hit_rate_alert' => '90',
    'eviction_alert' => '0',
    'file_path' => 'Temp/',
    'servers' =>
    [
        'LEMPer Stack' =>
        [
            '127.0.0.1:11211' =>
            [
                'hostname' => '127.0.0.1',
                'port' => '11211',
                ${MEMCACHED_SASL_CREDENTIAL}
            ],
            '127.0.0.1:11212' =>
            [
                'hostname' => '127.0.0.1',
                'port' => '11212',
            ],
        ],
    ],
];
EOL
    fi

    # Install phpRedisAdmin Web Admin.
    if "${INSTALL_REDIS}"; then
        #echo "Installing PHP Redis Admin web panel..."

        COMPOSER_BIN=$(command -v composer)

        local CUR_DIR && \
        CUR_DIR=$(pwd)
        run cd /usr/share/nginx/html/lcp || return 1

        if [ ! -f redisadmin/includes/config.inc.php ]; then
            run "${COMPOSER_BIN}" -q create-project erik-dubbelboer/php-redis-admin redisadmin && \
            run cd redisadmin && \
            run "${COMPOSER_BIN}" -q update && \
            run cp includes/config.sample.inc.php includes/config.inc.php

            if "${REDIS_REQUIREPASS}"; then
                run sed -i "s|//'auth'\ =>\ 'redispasswordhere'|'auth'\ =>\ '${REDIS_PASSWORD}'|g" includes/config.inc.php
            fi
        else
            run cd redisadmin && \
            run "${COMPOSER_BIN}" -q update
        fi

        run cd "${CUR_DIR}" || return 1
    fi

    # Assign ownership properly.
    run chown -hR www-data:www-data /usr/share/nginx/html

    if [[ -x /usr/local/bin/lemper-cli && -d /usr/share/nginx/html/lcp ]]; then
        success "Web administration tools successfully installed."
    fi
}

echo "[LEMPer CLI & Panel Installation]"

# Start running things from a call at the end so if this script is executed
# after a partial download it doesn't do anything.
init_webadmin_install "$@"
