#!/usr/bin/env bash

# fail2ban Uninstaller
# Min. Requirement  : GNU/Linux Ubuntu 16.04
# Last Build        : 05/06/2021
# Author            : MasEDI.Net (me@masedi.net)
# Since Version     : 2.1.0

# Include helper functions.
if [ "$(type -t run)" != "function" ]; then
    BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
    # shellcheck disable=SC1091
    . "${BASEDIR}/helper.sh"
fi

# Make sure only root can run this installer script.
requires_root

function init_fail2ban_removal() {
    # Stop fail2ban process.
    if [[ $(pgrep -c fail2ban-server) -gt 0 ]]; then
        run systemctl stop fail2ban
    fi

    if dpkg-query -l | awk '/fail2ban/ { print $2 }' | grep -qwE "^fail2ban$"; then
        echo "Found fail2ban package installation. Removing..."

        run apt-get remove --purge -qq -y fail2ban
    else
        echo "Fail2ban package not found, possibly installed from source."

        run rm -f /usr/local/bin/fail2ban-*
    fi

    run dpkg --purge fail2ban
    [ -f /etc/systemd/system/multi-user.target.wants/fail2ban.service ] && \
        run unlink /etc/systemd/system/multi-user.target.wants/fail2ban.service
    [ -f /lib/systemd/system/fail2ban.service ] && \
        run rm /lib/systemd/system/fail2ban.service

    # Remove fail2ban config files.
    warning "!! This action is not reversible !!"

    if "${AUTO_REMOVE}"; then
        if [[ ${FORCE_REMOVE} == true ]]; then
            REMOVE_FAIL2BAN_CONFIG="y"
        else
            REMOVE_FAIL2BAN_CONFIG="n"
        fi
    else
        while [[ "${REMOVE_FAIL2BAN_CONFIG}" != "y" && "${REMOVE_FAIL2BAN_CONFIG}" != "n" ]]; do
            read -rp "Remove fail2ban configuration files? [y/n]: " -e REMOVE_FAIL2BAN_CONFIG
        done
    fi

    if [[ "${REMOVE_FAIL2BAN_CONFIG}" == Y* || "${REMOVE_FAIL2BAN_CONFIG}" == y* ]]; then
        [ -d /etc/fail2ban/ ] && run rm -fr /etc/fail2ban/

        echo "All your fail2ban configuration files deleted permanently."
    fi

    # Final test.
    if "${DRYRUN}"; then
        info "Fail2ban server removed in dryrun mode."
    else
        if [[ -z $(command -v fail2ban-server) ]]; then
            success "Fail2ban server removed succesfully."
        else
            info "Unable to remove fail2ban server."
        fi
    fi
}

echo "Uninstalling fail2ban server..."
if [[ -n $(command -v fail2ban-server) ]]; then
    if "${AUTO_REMOVE}"; then
        REMOVE_FAIL2BAN="y"
    else
        while [[ "${REMOVE_FAIL2BAN}" != "y" && "${REMOVE_FAIL2BAN}" != "n" ]]; do
            read -rp "Are you sure to remove fail2ban? [y/n]: " -e REMOVE_FAIL2BAN
        done
    fi

    if [[ "${REMOVE_FAIL2BAN}" == Y* || "${REMOVE_FAIL2BAN}" == y* ]]; then
        init_fail2ban_removal "$@"
    else
        echo "Found fail2ban server, but not removed."
    fi
else
    info "Oops, fail2ban installation not found."
fi
