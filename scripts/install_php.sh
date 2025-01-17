#!/usr/bin/env bash

# PHP Installer
# Min. Requirement  : GNU/Linux Ubuntu 16.04 & 16.04
# Last Build        : 23/12/2020
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
# Add PHP repository.
#
function add_php_repo() {
    echo "Add Ondrej's PHP repository..."

    DISTRIB_NAME=${DISTRIB_NAME:-$(get_distrib_name)}
    RELEASE_NAME=${RELEASE_NAME:-$(get_release_name)}

    case ${DISTRIB_NAME} in
        debian)
            if [ ! -f "/etc/apt/sources.list.d/ondrej-php-${RELEASE_NAME}.list" ]; then
                run touch "/etc/apt/sources.list.d/ondrej-php-${RELEASE_NAME}.list"
                run bash -c "echo 'deb https://packages.sury.org/php/ ${RELEASE_NAME} main' > /etc/apt/sources.list.d/ondrej-php-${RELEASE_NAME}.list"
                run wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
                run apt-get update -qq -y
            else
                info "PHP repository already exists."
            fi
        ;;
        ubuntu)
            run apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 14AA40EC0831756756D7F66C4F4EA0AAE5267A6C
            run add-apt-repository -y ppa:ondrej/php
            run apt-get update -qq -y
        ;;
        *)
            fail "Unable to install PHP, this GNU/Linux distribution is not supported."
        ;;
    esac
}

##
# Install PHP & FPM package.
#
function install_php_fpm() {
    export PHP_IS_INSTALLED="no"
    local PHP_EXTS=() && \
    read -r -a PHP_EXTS <<< "${PHP_EXTENSIONS}"

    # PHP version.
    local PHPv="${1}"
    if [ -z "${PHPv}" ]; then
        PHPv=${DEFAULT_PHP_VERSION:-"7.4"}
    fi

    # Checking if PHP already installed.
    if [[ -n $(command -v "php${PHPv}") ]]; then
        PHP_IS_INSTALLED="yes"
        info "PHP ${PHPv} and it's extensions already exists, installation skipped."
    else
        # Add Ondrej repository.
        add_php_repo

        echo "Installing PHP ${PHPv} and requred extensions..."

        if hash apt-get 2>/dev/null; then
            PHP_EXTS+=("php${PHPv}" "php${PHPv}-bcmath" "php${PHPv}-bz2" "php${PHPv}-calendar" "php${PHPv}-cli" \
"php${PHPv}-common" "php${PHPv}-curl" "php${PHPv}-dev" "php${PHPv}-exif" "php${PHPv}-fpm" "php${PHPv}-gd" \
"php${PHPv}-gettext" "php${PHPv}-gmp" "php${PHPv}-gnupg" "php${PHPv}-iconv" "php${PHPv}-imap" "php${PHPv}-intl" \
"php${PHPv}-mbstring" "php${PHPv}-mysql" "php${PHPv}-opcache" "php${PHPv}-pdo" "php${PHPv}-pgsql" "php${PHPv}-posix" \
"php${PHPv}-pspell" "php${PHPv}-readline" "php${PHPv}-ldap" "php${PHPv}-snmp" "php${PHPv}-soap" "php${PHPv}-sqlite3" \
"php${PHPv}-tidy" "php${PHPv}-tokenizer" "php${PHPv}-xml" "php${PHPv}-xmlrpc" "php${PHPv}-xsl" "php${PHPv}-zip" \
php-pear php-xml pkg-php-tools fcgiwrap spawn-fcgi)

            # Install PHP Json
            if [ "${PHPv//.}" -lt "80" ]; then
                PHP_EXTS+=("php${PHPv}-json")
            else
                PHP_EXTS+=("php-json")
            fi

            # Install PHP Swoole
            if [ "${PHPv//.}" -gt "71" ]; then
                PHP_EXTS+=("php${PHPv}-swoole")
            else
                PHP_EXTS+=("php-swoole")
            fi

            if [[ "${#PHP_EXTS[@]}" -gt 0 ]]; then
                run apt-get install -qq -y "${PHP_EXTS[@]}"
            fi

            if [[ -n $(command -v "php${PHPv}") ]]; then
                success "PHP ${PHPv} along with ${#PHP_EXTS[@]} extensions installed."
            fi

            # Install PHP GeoIP?
            if "${AUTO_INSTALL}"; then
                local INSTALL_PHPGEOIP="n"
            else
                while [[ "${INSTALL_PHPGEOIP}" != "y" && "${INSTALL_PHPGEOIP}" != "n" ]]; do
                    read -rp "Do you want to install PHP GeoIP for geolocation? [y/n]: " \
                        -i n -e INSTALL_PHPGEOIP
                done
            fi

            if [[ ${INSTALL_PHPGEOIP} == Y* || ${INSTALL_PHPGEOIP} == y* ]]; then
                echo "Installing PHP GeoIP module..."

                if [ "${PHPv//.}" -lt "70" ]; then
                    run apt-get install -qq -y php-geoip
                else
                    run pecl install geoip

                    # Enable GeoIP module.
                    echo "Updating PHP ini file with GeoIP module..."

                    [ ! -f "/etc/php/${PHPv}/mods-available/geoip.ini" ] && \
                    run touch "/etc/php/${PHPv}/mods-available/geoip.ini"
                    run bash -c "echo extension=geoip.so > /etc/php/${PHPv}/mods-available/geoip.ini"

                    if [ ! -f "/etc/php/${PHPv}/cli/conf.d/20-geoip.ini" ]; then
                        run ln -s "/etc/php/${PHPv}/mods-available/geoip.ini" \
                            "/etc/php/${PHPv}/cli/conf.d/20-geoip.ini"
                    fi

                    if [ ! -f "/etc/php/${PHPv}/fpm/conf.d/20-geoip.ini" ]; then
                        run ln -s "/etc/php/${PHPv}/mods-available/geoip.ini" \
                            "/etc/php/${PHPv}/fpm/conf.d/20-geoip.ini"
                    fi
                fi
            fi

            # Install PHP Mcrypt?
            if "${AUTO_INSTALL}"; then
                if version_older_than "7.2" "${PHPv}"; then
                    local INSTALL_PHPMCRYPT="y"
                else
                    local INSTALL_PHPMCRYPT="n"
                fi
            else
                while [[ "${INSTALL_PHPMCRYPT}" != "y" && "${INSTALL_PHPMCRYPT}" != "n" ]]; do
                    read -rp "Do you want to install PHP Mcrypt for encryption/decryption? [y/n]: " \
                        -i n -e INSTALL_PHPMCRYPT
                done
            fi

            if [[ ${INSTALL_PHPMCRYPT} == Y* || ${INSTALL_PHPMCRYPT} == y* ]]; then
                echo "Installing PHP Mcrypt module..."

                if [ "${PHPv//.}" -lt "72" ]; then
                    run apt-get install -qq -y "php${PHPv}-mcrypt" "php${PHPv}-recode"
                elif [ "${PHPv}" == "7.2" ]; then
                    run apt-get install -qq -y libmcrypt-dev libreadline-dev && \
                    run pecl install mcrypt

                    # Enable Mcrypt module.
                    echo "Updating PHP ${PHPv} ini file with Mcrypt module..."

                    [ ! -f "/etc/php/${PHPv}/mods-available/mcrypt.ini" ] && \
                    run touch "/etc/php/${PHPv}/mods-available/mcrypt.ini"
                    run bash -c "echo extension=mcrypt.so > /etc/php/${PHPv}/mods-available/mcrypt.ini"

                    if [ ! -f "/etc/php/${PHPv}/cli/conf.d/20-mcrypt.ini" ]; then
                        run ln -s "/etc/php/${PHPv}/mods-available/mcrypt.ini" \
                            "/etc/php/${PHPv}/cli/conf.d/20-mcrypt.ini"
                    fi

                    if [ ! -f "/etc/php/${PHPv}/fpm/conf.d/20-mcrypt.ini" ]; then
                        run ln -s "/etc/php/${PHPv}/mods-available/mcrypt.ini" \
                            "/etc/php/${PHPv}/fpm/conf.d/20-mcrypt.ini"
                    fi
                else
                    run apt-get install -qq -y dh-php

                    # Use libsodium instead.
                    info "Mcrypt module is deprecated for PHP ${PHPv} or greater, for encryption use Libsodium or OpenSSL instead."
                fi
            fi

            # Create PHP log dir.
            if [ ! -d /var/log/php ]; then
                mkdir -p /var/log/php
            fi

            # Optimize PHP configuration.
            optimize_php_fpm "${PHPv}"
        else
            fail "Unable to install PHP ${PHPv}, this GNU/Linux distribution is not supported."
        fi
    fi
}

##
# PHP & FPM Optimization.
#
function optimize_php_fpm() {
    # PHP version.
    local PHPv="${1}"
    if [ -z "${PHPv}" ]; then
        PHPv=${DEFAULT_PHP_VERSION:-"7.4"}
    fi

    echo "Optimizing PHP ${PHPv} & FPM configuration..."

    if [ ! -d "/etc/php/${PHPv}/fpm" ]; then
        run mkdir -p "/etc/php/${PHPv}/fpm"
    fi

    # Copy the optimized-version of php.ini
    if [ -f "etc/php/${PHPv}/fpm/php.ini" ]; then
        run mv "/etc/php/${PHPv}/fpm/php.ini" "/etc/php/${PHPv}/fpm/php.ini~"
        run cp -f "etc/php/${PHPv}/fpm/php.ini" "/etc/php/${PHPv}/fpm/"
    else
        if ! "${DRYRUN}"; then
            cat >> "/etc/php/${PHPv}/fpm/php.ini" <<EOL

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Custom Optimization for LEMPer ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[opcache]
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.max_wasted_percentage=5
opcache.validate_timestamps=1
opcache.revalidate_freq=1
opcache.save_comments=1
opcache.error_log="/var/log/php/php${PHPv}-opcache_error.log"
EOL
        else
            info "PHP configuration optimized in dry run mode."
        fi
    fi

    # Copy the optimized-version of php-fpm config file.
    if [ -f "etc/php/${PHPv}/fpm/php-fpm.conf" ]; then
        run mv "/etc/php/${PHPv}/fpm/php-fpm.conf" "/etc/php/${PHPv}/fpm/php-fpm.conf~"
        run cp -f "etc/php/${PHPv}/fpm/php-fpm.conf" "/etc/php/${PHPv}/fpm/"
    else
        if grep -qwE "^error_log\ =\ \/var\/log\/php${PHPv}-fpm.log" "/etc/php/${PHPv}/fpm/php-fpm.conf"; then
            run sed -i "s|^error_log\ =\ /var/log/php${PHPv}-fpm.log|error_log\ =\ /var/log/php/php${PHPv}-fpm.log/g" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        else
            run sed -i "/^;error_log/a error_log\ =\ \/var\/log\/php\/php${PHPv}-fpm.log" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        fi

        if grep -qwE "^emergency_restart_threshold\ =\ [0-9]*" "/etc/php/${PHPv}/fpm/php-fpm.conf"; then
            run sed -i "s/^emergency_restart_threshold\ =\ [0-9]*/emergency_restart_threshold\ =\ 10/g" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        else
            run sed -i "/^;emergency_restart_threshold/a emergency_restart_threshold\ =\ 10" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        fi

        if grep -qwE "^emergency_restart_interval\ =\ [0-9]*" "/etc/php/${PHPv}/fpm/php-fpm.conf"; then
            run sed -i "s/^emergency_restart_interval\ =\ [0-9]*/emergency_restart_interval\ =\ 60/g" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        else
            run sed -i "/^;emergency_restart_interval/a emergency_restart_interval\ =\ 60" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        fi

        if grep -qwE "^process_control_timeout\ =\ [0-9]*" "/etc/php/${PHPv}/fpm/php-fpm.conf"; then
            run sed -i "s/^process_control_timeout\ =\ [0-9]*/process_control_timeout\ =\ 10/g" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        else
            run sed -i "/^;process_control_timeout/a process_control_timeout\ =\ 10" \
                "/etc/php/${PHPv}/fpm/php-fpm.conf"
        fi
    fi

    if [ ! -d "/etc/php/${PHPv}/fpm/pool.d" ]; then
        run mkdir -p "/etc/php/${PHPv}/fpm/pool.d"
    fi

    # Copy the optimized-version of php fpm default pool.
    if [ -f "etc/php/${PHPv}/fpm/pool.d/www.conf" ]; then
        run mv "/etc/php/${PHPv}/fpm/pool.d/www.conf" "/etc/php/${PHPv}/fpm/pool.d/www.conf~"
        run cp -f "etc/php/${PHPv}/fpm/pool.d/www.conf" "/etc/php/${PHPv}/fpm/pool.d/"

        # Update timezone.
        run run sed -i "s|php_admin_value\[date\.timezone\]\ =\ UTC|php_admin_value\[date\.timezone\]\ =\ ${TIMEZONE}|g" \
            "/etc/php/${PHPv}/fpm/pool.d/www.conf"
    else
        # Enable FPM ping service.
        run sed -i "/^;ping.path\ =.*/a ping.path\ =\ \/ping" "/etc/php/${PHPv}/fpm/pool.d/www.conf"

        # Enable FPM status.
        run sed -i "/^;pm.status_path\ =.*/a pm.status_path\ =\ \/status" "/etc/php/${PHPv}/fpm/pool.d/www.conf"
        
        # Enable chdir.
        run sed -i "/^;chdir\ =.*/a chdir\ =\ \/usr\/share\/nginx\/html" "/etc/php/${PHPv}/fpm/pool.d/www.conf"

        # Add custom php extension (ex .php70, .php71)
        PHPExt=".php${PHPv//.}"
        run sed -i "s/;\(security\.limit_extensions\s*=\s*\).*$/\1\.php\ $PHPExt/g" \
            "/etc/php/${PHPv}/fpm/pool.d/www.conf"

        # Customize php ini settings.
        if ! "${DRYRUN}"; then
            cat >> "/etc/php/${PHPv}/fpm/pool.d/www.conf" <<EOL
php_flag[display_errors] = On
;php_admin_value[error_reporting] = E_ALL & ~E_DEPRECATED & ~E_STRICT
;php_admin_value[disable_functions] = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,exec,passthru,popen,proc_open,shell_exec,system
php_admin_flag[log_errors] = On
php_admin_value[error_log] = /var/log/php/php7.4-fpm.\$pool.log
php_admin_value[date.timezone] = UTC
php_admin_value[memory_limit] = 128M
php_admin_value[opcache.file_cache] = /usr/share/nginx/html/.lemper/php/opcache
php_admin_value[open_basedir] = /usr/share/nginx/html
php_admin_value[session.save_path] = /usr/share/nginx/html/.lemper/php/sessions
php_admin_value[sys_temp_dir] = /usr/share/nginx/html/.lemper/tmp
php_admin_value[upload_tmp_dir] = /usr/share/nginx/html/.lemper/tmp
php_admin_value[upload_max_filesize] = 20M
php_admin_value[post_max_size] = 20M
EOL
        else
            info "Default FPM pool optimized in dry run mode."
        fi
    fi

    # Copy the optimized-version of php fpm default lemper pool.
    local POOLNAME=${LEMPER_USERNAME:-"lemper"}
    if [[ -f "etc/php/${PHPv}/fpm/pool.d/lemper.conf" && ${POOLNAME} = "lemper" ]]; then
        run cp -f "etc/php/${PHPv}/fpm/pool.d/lemper.conf" "/etc/php/${PHPv}/fpm/pool.d/${POOLNAME}.conf"

        # Update timezone.
        run sed -i "s|php_admin_value\[date\.timezone\]\ =\ UTC|php_admin_value\[date\.timezone\]\ =\ ${TIMEZONE}|g" \
            "/etc/php/${PHPv}/fpm/pool.d/${POOLNAME}.conf"
    else
        if [[ -f "/etc/php/${PHPv}/fpm/pool.d/lemper.conf" && -z $(getent passwd "${POOLNAME}") ]]; then
            run mv "/etc/php/${PHPv}/fpm/pool.d/lemper.conf" "/etc/php/${PHPv}/fpm/pool.d/lemper.conf~"
        fi

        # Create custom pool configuration.
        if ! "${DRYRUN}"; then
            touch "/etc/php/${PHPv}/fpm/pool.d/${POOLNAME}.conf"
            cat > "/etc/php/${PHPv}/fpm/pool.d/${POOLNAME}.conf" <<EOL
[${POOLNAME}]
user = ${POOLNAME}
group = ${POOLNAME}

listen = /run/php/php${PHPv}-fpm.\$pool.sock
listen.owner = ${POOLNAME}
listen.group = ${POOLNAME}
listen.mode = 0666
;listen.allowed_clients = 127.1.0.1

; Custom PHP-FPM optimization
; adjust here to meet your needs.
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.process_idle_timeout = 30s
pm.max_requests = 500

pm.status_path = /status
ping.path = /ping

slowlog = /var/log/php/php${PHPv}-fpm_slow.\$pool.log
request_slowlog_timeout = 10s

;chroot = /home/${POOLNAME}
chdir = /home/${POOLNAME}

;catch_workers_output = yes
;decorate_workers_output = no

security.limit_extensions = .php .php5 .php7 .php${PHPv//./}

; Custom PHP ini settings.
php_flag[display_errors] = On
;php_admin_value[error_reporting] = E_ALL & ~E_DEPRECATED & ~E_STRICT
;php_admin_value[disable_functions] = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wifcontinued,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_get_handler,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,pcntl_async_signals,exec,passthru,popen,proc_open,shell_exec,system
php_admin_flag[log_errors] = On
php_admin_value[error_log] = /var/log/php/php${PHPv}-fpm.\$pool.log
php_admin_value[date.timezone] = ${TIMEZONE}
php_admin_value[memory_limit] = 128M
php_admin_value[opcache.file_cache] = /home/${POOLNAME}/.lemper/php/opcache
php_admin_value[open_basedir] = /home/${POOLNAME}
php_admin_value[session.save_path] = /home/${POOLNAME}/.lemper/php/sessions
php_admin_value[sys_temp_dir] = /home/${POOLNAME}/.lemper/tmp
php_admin_value[upload_tmp_dir] = /home/${POOLNAME}/.lemper/tmp
php_admin_value[upload_max_filesize] = 20M
php_admin_value[post_max_size] = 20M
EOL
        else
            info "Custom FPM pool ${POOLNAME} created & optimized in dry run mode."
        fi
    fi

    # Create default directories.
    run mkdir -p "/home/${POOLNAME}/.lemper/tmp"
    run mkdir -p "/home/${POOLNAME}/.lemper/php/opcache"
    run mkdir -p "/home/${POOLNAME}/.lemper/php/sessions"
    run mkdir -p "/home/${POOLNAME}/cgi-bin"
    run chown -hR "${POOLNAME}:${POOLNAME}" "/home/${POOLNAME}"

    # Fix cgi.fix_pathinfo (for PHP older than 5.3).
    #sed -i "s/cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/${PHPv}/fpm/php.ini

    # Restart PHP-fpm server.
    if "${DRYRUN}"; then
        info "php${PHPv}-fpm reloaded in dry run mode."
    else
        if [[ $(pgrep -c "php-fpm${PHPv}") -gt 0 ]]; then
            run systemctl reload "php${PHPv}-fpm"
            success "php${PHPv}-fpm reloaded successfully."
        elif [[ -n $(command -v "php${PHPv}") ]]; then
            run systemctl start "php${PHPv}-fpm"

            if [[ $(pgrep -c "php-fpm${PHPv}") -gt 0 ]]; then
                success "php${PHPv}-fpm started successfully."
            else
                error "Something goes wrong with PHP ${PHPv} & FPM installation."
            fi
        fi
    fi
}

##
# Install PHP Composer.
#
function install_php_composer() {
    # PHP version.
    local PHPv="${1}"
    if [ -z "${PHPv}" ]; then
        PHPv=${DEFAULT_PHP_VERSION:-"7.4"}
    fi

    # Checking if php composer already installed.
    if [[ -z $(command -v composer) ]]; then
        if "${AUTO_INSTALL}"; then
            DO_INSTALL_COMPOSER="y"
        else
            while [[ "${DO_INSTALL_COMPOSER}" != "y" && "${DO_INSTALL_COMPOSER}" != "n" ]]; do
                read -rp "Do you want to install PHP Composer? [y/n]: " -i n -e DO_INSTALL_COMPOSER
            done
        fi

        if [[ ${DO_INSTALL_COMPOSER} == y* && ${INSTALL_PHP_COMPOSER} == true ]]; then
            echo "Installing PHP Composer..."

            local CURRENT_DIR && CURRENT_DIR=$(pwd)
            run cd "${BUILD_DIR}" || error "Cannot change directory to ${BUILD_DIR}."

            PHP_BIN=$(command -v "php${PHPv}")

            if [[ -n "${PHP_BIN}" ]]; then
                EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
                run "${PHP_BIN}" -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
                ACTUAL_SIGNATURE="$(${PHP_BIN} -r "echo hash_file('sha384', 'composer-setup.php');")"

                if [[ "${EXPECTED_SIGNATURE}" == "${ACTUAL_SIGNATURE}" ]]; then
                    local LEMPER_USERNAME=${LEMPER_USERNAME:-"lemper"}

                    run "${PHP_BIN}" composer-setup.php --filename=composer --install-dir=/usr/local/bin --quiet

                    # Fix chmod permission to executable.
                    if [ -f /usr/local/bin/composer ]; then
                        run chmod ugo+x /usr/local/bin/composer
                        run bash -c "echo '[ -d \"\$HOME/.composer/vendor/bin\" ] && export PATH=\"\$PATH:\$HOME/.composer/vendor/bin\"' >> /home/${LEMPER_USERNAME}/.bashrc"
                        run bash -c "echo '[ -d \"\$HOME/.composer/vendor/bin\" ] && export PATH=\"\$PATH:\$HOME/.composer/vendor/bin\"' >> /home/${LEMPER_USERNAME}/.bash_profile"
                        run bash -c "echo '[ -d \"\$HOME/.composer/vendor/bin\" ] && export PATH=\"\$PATH:\$HOME/.composer/vendor/bin\"' >> /home/${LEMPER_USERNAME}/.profile"
                    fi
                else
                    error "Invalid PHP Composer installer signature."
                fi
            fi

            #run rm composer-setup.php
            run cd "${CURRENT_DIR}" || error "Cannot change directory to ${CURRENT_DIR}."
        fi

        if [[ -n $(command -v composer) ]]; then
            success "PHP Composer successfully installed."
        else
            error "Something went wrong with PHP Composer installation."
        fi
    fi
}

##
# Initialize PHP & FPM Installation.
#
function init_php_fpm_install() {
    local SELECTED_PHP_VERSIONS=()
    local OPT_PHP_VERSIONS=()

    OPTS=$(getopt -o p: \
        -l php-version: \
        -n "init_php_fpm_install" -- "$@")

    eval set -- "${OPTS}"

    while true
    do
        case "${1}" in
            -p|--php-version) shift
                OPT_PHP_VERSIONS+=("${1}")
                shift
            ;;
            --) shift
                break
            ;;
            *)
                fail "Invalid argument: ${1}"
                exit 1
            ;;
        esac
    done

    # Read versions from config file.
    read -r -a SELECTED_PHP_VERSIONS <<< "${PHP_VERSIONS}"

    if [[ "${#OPT_PHP_VERSIONS[@]}" -gt 0 ]]; then
        SELECTED_PHP_VERSIONS+=("${OPT_PHP_VERSIONS[@]}")
    else
        # Manually select PHP version in interactive mode.
        if ! "${AUTO_INSTALL}"; then
            echo "Which PHP version to be installed?"
            echo "Supported PHP versions:"
            echo "  1). PHP 5.6 (EOL)"
            echo "  2). PHP 7.0 (EOL)"
            echo "  3). PHP 7.1 (EOL)"
            echo "  4). PHP 7.2 (EOL)"
            echo "  5). PHP 7.3 (SFO)"
            echo "  6). PHP 7.4 (Stable)"
            echo "  7). PHP 8.0 (Latest Stable)"
            echo "  8). All available versions"
            echo "--------------------------------------------"
            [ -n "${DEFAULT_PHP_VERSION}" ] && \
            info "Default version is: ${DEFAULT_PHP_VERSION}"

            while [[ ${SELECTED_PHP} != "1" && ${SELECTED_PHP} != "2" && ${SELECTED_PHP} != "3" && \
                    ${SELECTED_PHP} != "4" && ${SELECTED_PHP} != "5" && ${SELECTED_PHP} != "6" && \
                    ${SELECTED_PHP} != "7" && ${SELECTED_PHP} != "8" && \
                    ${SELECTED_PHP} != "5.6" && ${SELECTED_PHP} != "7.0" && ${SELECTED_PHP} != "7.1" && \
                    ${SELECTED_PHP} != "7.2" && ${SELECTED_PHP} != "7.3" && ${SELECTED_PHP} != "7.4" && \
                    ${SELECTED_PHP} != "8.0" && ${SELECTED_PHP} != "all" ]]; do
                read -rp "Enter a PHP version from an option above [1-8]: " -i "${DEFAULT_PHP_VERSION}" -e SELECTED_PHP
            done

            case ${SELECTED_PHP} in
                1|"5.6")
                    #install_php_fpm "5.6"
                    SELECTED_PHP_VERSIONS+=("5.6")
                ;;
                2|"7.0")
                    #install_php_fpm "7.0"
                    SELECTED_PHP_VERSIONS+=("7.0")
                ;;
                3|"7.1")
                    #install_php_fpm "7.1"
                    SELECTED_PHP_VERSIONS+=("7.1")
                ;;
                4|"7.2")
                    #install_php_fpm "7.2"
                    SELECTED_PHP_VERSIONS+=("7.2")
                ;;
                5|"7.3")
                    #install_php_fpm "7.3"
                    SELECTED_PHP_VERSIONS+=("7.3")
                ;;
                6|"7.4")
                    #install_php_fpm "7.4"
                    SELECTED_PHP_VERSIONS+=("7.4")
                ;;
                7|"8.0")
                    #install_php_fpm "8.0"
                    SELECTED_PHP_VERSIONS+=("8.0")
                ;;
                8|"all")
                    # Select all PHP versions (except EOL & Beta).
                    SELECTED_PHP_VERSIONS=("5.6" "7.0" "7.1" "7.2" "7.3" "7.4" "8.0")
                ;;
                *)
                    error "Your selected PHP version ${SELECTED_PHP} is not supported yet."
                ;;
            esac
        fi
    fi

    # Sort PHP versions.
    #shellcheck disable=SC2207
    SELECTED_PHP_VERSIONS=($(printf "%s\n" "${SELECTED_PHP_VERSIONS[@]}" | sort -u | tr '\n' ' '))

    # Install all selected PHP versions.
    for VERSION in "${SELECTED_PHP_VERSIONS[@]}"; do
        IS_PKG_AVAIL=$(apt-cache search "php${VERSION}" | grep -c "${VERSION}")
        if [[ "${IS_PKG_AVAIL}" -gt 0 ]]; then
            install_php_fpm "${VERSION}"
        else
            error "PHP ${VERSION} package is not available in your system."
        fi
    done

    # Install default PHP version used by LEMPer.
    if [[ -z $(command -v "php${DEFAULT_PHP_VERSION}") ]]; then
        info -e "\nLEMPer requires PHP ${DEFAULT_PHP_VERSION} as default to run its administration tools."
        echo "PHP ${DEFAULT_PHP_VERSION} now being installed..."
        install_php_fpm "${DEFAULT_PHP_VERSION}"
    fi

    # Install PHP composer.
    install_php_composer "${DEFAULT_PHP_VERSION}"
}

echo "[PHP & FPM Packages Installation]"

# Start running things from a call at the end so if this script is executed
# after a partial download it doesn't do anything.
if [[ -n $(command -v php5.6) && \
    -n $(command -v php7.0) && \
    -n $(command -v php7.1) && \
    -n $(command -v php7.2) && \
    -n $(command -v php7.3) && \
    -n $(command -v php7.4) && \
    -n $(command -v php8.0) ]]; then
    info "All available PHP version already exists, installation skipped."
else
    init_php_fpm_install "$@"
fi
