#!/usr/bin/env bash
set -ex

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Activating feature 'gitversion'"

GITVERSION_VERSION=${VERSION:-"latest"}
echo "The provided version is: $GITVERSION_VERSION"


if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

apt_get_update()
{
    echo "Running apt-get update..."
    apt-get update -y
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            apt_get_update
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Figure out correct version if a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

echo "Installing gitversion ..."

# Install dependencies if missing
check_packages curl git ca-certificates

. /etc/os-release  # Load the os-release file to get OS variables

case "${ID}" in
	debian)	
		case "${VERSION_ID}" in
			10*)	check_packages libicu63;;  # for Debian 10 (buster)
			11*)	check_packages libicu67;;  # for Debian 11 (bullseye)
			12*)	check_packages libicu72;;  # for Debian 12 (bookworm)
			*) check_packages libicu72       # for newer versions
		esac
		;;
	ubuntu) check_packages libicu70;;
	*) check_packages libicu70
esac

ARCHITECTURE="$(uname -m)"
case $ARCHITECTURE in
    x86_64) ARCHITECTURE="x64";;
    aarch64 | armv8* | arm64) ARCHITECTURE="arm64";;
    *) echo "(!) Architecture $ARCHITECTURE unsupported"; exit 1 ;;
esac

# Soft version matching
find_version_from_git_tags GITVERSION_VERSION "https://github.com/GitTools/GitVersion" "tags/"

curl -sSL --fail -o /tmp/gitversion.tar.gz "https://github.com/GitTools/GitVersion/releases/download/${GITVERSION_VERSION}/gitversion-linux-${ARCHITECTURE}-${GITVERSION_VERSION}.tar.gz"
tar xvf /tmp/gitversion.tar.gz "gitversion"

mv "gitversion" /usr/local/bin
chmod 0755 /usr/local/bin/gitversion
rm -rf  /tmp/gitversion.tar.gz

gitversion version

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"