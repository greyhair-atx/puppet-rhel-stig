#!/usr/bin/env bash
#
# Install and configure OpenVox Server, OpenVoxDB, and PostgreSQL 16
# on a single RHEL 9 host.
#
# Assumptions:
#   * The OpenVox yum repository is already configured.
#   * The server FQDN resolves to this host before the script is run.
#   * This is a new installation. Existing PostgreSQL clusters using a
#     major version other than 16 are not modified.
#
# Optional environment variables:
#   PUPPET_FQDN              Server certificate name/FQDN. Default: hostname -f
#   DNS_ALT_NAMES            Certificate DNS alt names. Default: puppet,<FQDN>
#   PUPPETDB_PASSWORD        Existing/new puppetdb role password
#   PUPPETDB_READ_PASSWORD   Existing/new puppetdb_read role password
#   CREDENTIAL_FILE          Password output file. Default: /root/openvox-install-credentials
#   OPEN_FIREWALL            true/false. Default: true
#
# Example:
#   PUPPET_FQDN=puppet.example.com bash install_openvox_stack_rhel9.sh

set -Eeuo pipefail
IFS=$'\n\t'
umask 027

readonly SCRIPT_NAME="${0##*/}"
readonly PGDATA="/var/lib/pgsql/data"
readonly PUPPET_BIN="/opt/puppetlabs/bin/puppet"
readonly PUPPETSERVER_SYSCONFIG="/etc/sysconfig/puppetserver"
readonly PUPPET_TMPDIR="/opt/puppetlabs/tmp"
readonly PUPPET_CONFDIR="/etc/puppetlabs/puppet"
readonly PUPPETDB_CONFDIR="/etc/puppetlabs/puppetdb/conf.d"
readonly CREDENTIAL_FILE="${CREDENTIAL_FILE:-/root/openvox-install-credentials}"
readonly OPEN_FIREWALL="${OPEN_FIREWALL:-true}"
readonly BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S)"

PUPPET_FQDN="${PUPPET_FQDN:-$(hostname -f 2>/dev/null || hostname)}"
DNS_ALT_NAMES="${DNS_ALT_NAMES:-puppet,${PUPPET_FQDN}}"

log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

warn() {
    printf '[%s] WARNING: %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
    printf '[%s] ERROR: %s\n' "$(date '+%F %T')" "$*" >&2
    exit 1
}

on_error() {
    local exit_code=$?
    printf '\n%s failed at line %s while running: %s\n' \
        "$SCRIPT_NAME" "${BASH_LINENO[0]:-unknown}" "${BASH_COMMAND:-unknown}" >&2
    printf 'Review: journalctl -u postgresql -u puppetdb -u puppetserver --no-pager\n' >&2
    exit "$exit_code"
}
trap on_error ERR

require_root() {
    [[ ${EUID} -eq 0 ]] || die "Run this script as root."
}

require_rhel9() {
    [[ -r /etc/os-release ]] || die "/etc/os-release is missing."
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ ${ID:-} == "rhel" ]] || die "This script supports RHEL only; detected ID=${ID:-unknown}."
    [[ ${VERSION_ID%%.*} == "9" ]] || die "This script supports RHEL 9 only; detected VERSION_ID=${VERSION_ID:-unknown}."
}

validate_fqdn() {
    [[ -n "$PUPPET_FQDN" ]] || die "PUPPET_FQDN is empty."
    [[ "$PUPPET_FQDN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]] \
        || die "PUPPET_FQDN contains unsupported characters: $PUPPET_FQDN"

    if [[ "$PUPPET_FQDN" != *.* ]]; then
        warn "PUPPET_FQDN '$PUPPET_FQDN' is not fully qualified. A resolvable FQDN is strongly recommended."
    fi

    getent hosts "$PUPPET_FQDN" >/dev/null \
        || die "$PUPPET_FQDN does not resolve. Fix DNS or /etc/hosts before continuing."
}

backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        cp -a -- "$file" "${file}.${BACKUP_SUFFIX}.bak"
    fi
}

wait_for_service() {
    local service=$1
    local attempts=${2:-60}
    local count

    for ((count = 1; count <= attempts; count++)); do
        if systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
    done

    systemctl status "$service" --no-pager || true
    journalctl -u "$service" -n 100 --no-pager || true
    die "Service $service did not become active."
}

validate_password() {
    local name=$1
    local value=$2

    [[ "$value" =~ ^[A-Za-z0-9._~-]{16,128}$ ]] \
        || die "$name must contain 16-128 characters from A-Z, a-z, 0-9, dot, underscore, tilde, or hyphen."
}

validate_options() {
    case "$OPEN_FIREWALL" in
        true | false) ;;
        *) die "OPEN_FIREWALL must be true or false; received '$OPEN_FIREWALL'." ;;
    esac
}

load_or_generate_credentials() {
    local credential_dir
    local stored_write=""
    local stored_read=""

    credential_dir=$(dirname -- "$CREDENTIAL_FILE")
    if [[ -e "$CREDENTIAL_FILE" && (! -f "$CREDENTIAL_FILE" || -L "$CREDENTIAL_FILE") ]]; then
        die "CREDENTIAL_FILE must be a regular file and must not be a symbolic link: $CREDENTIAL_FILE"
    fi

    if [[ -r "$CREDENTIAL_FILE" ]]; then
        stored_write=$(awk -F= '$1 == "PUPPETDB_PASSWORD" {print substr($0, index($0, "=") + 1); exit}' "$CREDENTIAL_FILE")
        stored_read=$(awk -F= '$1 == "PUPPETDB_READ_PASSWORD" {print substr($0, index($0, "=") + 1); exit}' "$CREDENTIAL_FILE")
    fi

    PUPPETDB_PASSWORD="${PUPPETDB_PASSWORD:-$stored_write}"
    PUPPETDB_READ_PASSWORD="${PUPPETDB_READ_PASSWORD:-$stored_read}"

    if [[ -z "$PUPPETDB_PASSWORD" ]]; then
        PUPPETDB_PASSWORD=$(openssl rand -hex 24)
    fi
    if [[ -z "$PUPPETDB_READ_PASSWORD" ]]; then
        PUPPETDB_READ_PASSWORD=$(openssl rand -hex 24)
    fi

    validate_password PUPPETDB_PASSWORD "$PUPPETDB_PASSWORD"
    validate_password PUPPETDB_READ_PASSWORD "$PUPPETDB_READ_PASSWORD"

    if [[ ! -d "$credential_dir" ]]; then
        install -d -m 0700 -o root -g root "$credential_dir"
    fi
    cat >"$CREDENTIAL_FILE" <<EOF
PUPPET_FQDN=$PUPPET_FQDN
PUPPETDB_DATABASE=puppetdb
PUPPETDB_USERNAME=puppetdb
PUPPETDB_PASSWORD=$PUPPETDB_PASSWORD
PUPPETDB_READ_USERNAME=puppetdb_read
PUPPETDB_READ_PASSWORD=$PUPPETDB_READ_PASSWORD
EOF
    chown root:root "$CREDENTIAL_FILE"
    chmod 0600 "$CREDENTIAL_FILE"
}

install_prerequisites() {
    log "Installing prerequisite packages"
    dnf -y install java-17-openjdk-headless openssl curl policycoreutils
}

install_postgresql16() {
    local installed_major=""

    if rpm -q postgresql-server >/dev/null 2>&1; then
        if command -v postgres >/dev/null 2>&1; then
            installed_major=$(postgres --version | awk '{print $3}' | cut -d. -f1)
        elif command -v psql >/dev/null 2>&1; then
            installed_major=$(psql --version | awk '{print $3}' | cut -d. -f1)
        fi

        [[ "$installed_major" == "16" ]] \
            || die "postgresql-server is already installed, but major version '$installed_major' was detected. Refusing to replace or upgrade it automatically."
    else
        if ! dnf -q module list postgresql:16 --available 2>/dev/null | awk '$1 == "postgresql" && $2 ~ /^16([[:space:]]|$)/ {found=1} END {exit !found}'; then
            die "The RHEL AppStream postgresql:16 module is unavailable. PostgreSQL 16 requires RHEL 9.4 or later and enabled AppStream content."
        fi

        log "Installing PostgreSQL 16 from the RHEL 9 AppStream module"
        dnf -y module reset postgresql
        dnf -y module install postgresql:16/server
    fi

    dnf -y install postgresql-contrib

    if [[ -f "$PGDATA/PG_VERSION" ]]; then
        [[ "$(<"$PGDATA/PG_VERSION")" == "16" ]] \
            || die "Existing PostgreSQL data directory is version $(<"$PGDATA/PG_VERSION"), not 16."
        log "Existing PostgreSQL 16 data cluster found; initialization skipped"
    else
        if [[ -d "$PGDATA" ]] && find "$PGDATA" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
            die "$PGDATA is not empty but has no PG_VERSION file. Refusing to initialize over existing content."
        fi
        log "Initializing PostgreSQL 16"
        postgresql-setup --initdb
    fi

    systemctl enable --now postgresql
    wait_for_service postgresql
}

configure_postgresql_authentication() {
    local pg_hba="$PGDATA/pg_hba.conf"
    local postgresql_conf="$PGDATA/postgresql.conf"
    local cleaned

    [[ -f "$pg_hba" ]] || die "$pg_hba was not found."
    [[ -f "$postgresql_conf" ]] || die "$postgresql_conf was not found."

    backup_file "$pg_hba"
    backup_file "$postgresql_conf"

    # Explicitly use SCRAM for newly assigned PostgreSQL passwords.
    if grep -Eq '^[#[:space:]]*password_encryption[[:space:]]*=' "$postgresql_conf"; then
        sed -ri "s|^[#[:space:]]*password_encryption[[:space:]]*=.*$|password_encryption = 'scram-sha-256'|" "$postgresql_conf"
    else
        printf "\npassword_encryption = 'scram-sha-256'\n" >>"$postgresql_conf"
    fi

    cleaned=$(mktemp)
    awk '
        $0 == "# BEGIN OPENVOXDB MANAGED AUTH" {skip=1; next}
        $0 == "# END OPENVOXDB MANAGED AUTH"   {skip=0; next}
        !skip {print}
    ' "$pg_hba" >"$cleaned"

    {
        cat <<'EOF'
# BEGIN OPENVOXDB MANAGED AUTH
# OpenVoxDB and PostgreSQL are installed on the same host.
host    puppetdb    puppetdb         127.0.0.1/32    scram-sha-256
host    puppetdb    puppetdb_read    127.0.0.1/32    scram-sha-256
host    puppetdb    puppetdb         ::1/128         scram-sha-256
host    puppetdb    puppetdb_read    ::1/128         scram-sha-256
# END OPENVOXDB MANAGED AUTH
EOF
        cat "$cleaned"
    } >"${pg_hba}.new"

    rm -f "$cleaned"
    chown postgres:postgres "${pg_hba}.new"
    chmod 0600 "${pg_hba}.new"
    mv -f "${pg_hba}.new" "$pg_hba"

    chown postgres:postgres "$postgresql_conf"
    systemctl restart postgresql
    wait_for_service postgresql
}

psql_as_postgres() {
    runuser -u postgres -- psql -v ON_ERROR_STOP=1 "$@"
}

configure_openvoxdb_database() {
    log "Creating PostgreSQL roles and the OpenVoxDB database"

    if ! psql_as_postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='puppetdb'" | grep -q 1; then
        runuser -u postgres -- createuser -D -R -S puppetdb
    fi
    if ! psql_as_postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='puppetdb_read'" | grep -q 1; then
        runuser -u postgres -- createuser -D -R -S puppetdb_read
    fi

    psql_as_postgres -d postgres -v role_password="$PUPPETDB_PASSWORD" \
        -c "ALTER ROLE puppetdb LOGIN PASSWORD :'role_password';"
    psql_as_postgres -d postgres -v role_password="$PUPPETDB_READ_PASSWORD" \
        -c "ALTER ROLE puppetdb_read LOGIN PASSWORD :'role_password';"

    if ! psql_as_postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='puppetdb'" | grep -q 1; then
        runuser -u postgres -- createdb -E UTF8 -O postgres puppetdb
    fi

    psql_as_postgres -d puppetdb <<'SQL'
GRANT puppetdb_read TO puppetdb;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO puppetdb;

ALTER DEFAULT PRIVILEGES FOR USER puppetdb IN SCHEMA public
  GRANT SELECT ON TABLES TO puppetdb_read;
ALTER DEFAULT PRIVILEGES FOR USER puppetdb IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO puppetdb_read;
ALTER DEFAULT PRIVILEGES FOR USER puppetdb IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO puppetdb_read;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO puppetdb_read;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO puppetdb_read;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO puppetdb_read;

CREATE EXTENSION IF NOT EXISTS pg_trgm;
SQL

    PGPASSWORD="$PUPPETDB_PASSWORD" \
        psql -h 127.0.0.1 -U puppetdb -d puppetdb -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null
    PGPASSWORD="$PUPPETDB_READ_PASSWORD" \
        psql -h 127.0.0.1 -U puppetdb_read -d puppetdb -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null
}

install_openvox_packages() {
    log "Installing OpenVox Server, OpenVoxDB, and OpenVoxDB termini"
    dnf -y install openvox-server openvoxdb openvoxdb-termini

    systemctl stop puppetdb 2>/dev/null || true
    systemctl stop puppetserver 2>/dev/null || true

    [[ -x "$PUPPET_BIN" ]] || die "$PUPPET_BIN was not installed."
    getent passwd puppet >/dev/null || die "The puppet service account was not created."
    getent passwd puppetdb >/dev/null || die "The puppetdb service account was not created."
}

read_assignment_value() {
    local file=$1
    local variable=$2
    local value

    value=$(grep -E "^[[:space:]]*${variable}=" "$file" | tail -n 1 | cut -d= -f2- || true)
    value=${value#\"}
    value=${value%\"}
    value=${value#\'}
    value=${value%\'}
    printf '%s' "$value"
}

replace_assignment() {
    local file=$1
    local variable=$2
    local value=$3
    local temporary

    temporary=$(mktemp)
    awk -v key="$variable" -v replacement="${variable}=\"${value}\"" '
        BEGIN {done=0}
        $0 ~ "^[[:space:]]*" key "=" {
            if (!done) {
                print replacement
                done=1
            }
            next
        }
        {print}
        END {
            if (!done) print replacement
        }
    ' "$file" >"$temporary"
    cat "$temporary" >"$file"
    rm -f "$temporary"
}

normalize_jvm_args() {
    local args=$1

    # Remove earlier values managed by this script, then normalize whitespace.
    args=$(printf '%s\n' "$args" | sed -E \
        -e 's/(^|[[:space:]])-XX:ReservedCodeCacheSize=[^[:space:]]+//g' \
        -e 's|(^|[[:space:]])-Djava\.io\.tmpdir=[^[:space:]]+||g' \
        -e 's/[[:space:]]+/ /g' \
        -e 's/^ //; s/ $//')

    printf '%s' "$args"
}

configure_puppetserver_jvm() {
    local java_args
    local java_args_cli

    [[ -f "$PUPPETSERVER_SYSCONFIG" ]] \
        || die "$PUPPETSERVER_SYSCONFIG was not installed."

    backup_file "$PUPPETSERVER_SYSCONFIG"

    install -d -o root -g root -m 1777 "$PUPPET_TMPDIR"
    if command -v restorecon >/dev/null 2>&1; then
        restorecon -RF "$PUPPET_TMPDIR" || true
    fi
    chmod 1777 "$PUPPET_TMPDIR"

    java_args=$(normalize_jvm_args "$(read_assignment_value "$PUPPETSERVER_SYSCONFIG" JAVA_ARGS)")
    java_args="${java_args:+$java_args }-XX:ReservedCodeCacheSize=2G -Djava.io.tmpdir=$PUPPET_TMPDIR"
    replace_assignment "$PUPPETSERVER_SYSCONFIG" JAVA_ARGS "$java_args"

    # Puppet Server CLI commands also need an executable temporary directory.
    java_args_cli=$(normalize_jvm_args "$(read_assignment_value "$PUPPETSERVER_SYSCONFIG" JAVA_ARGS_CLI)")
    java_args_cli="${java_args_cli:+$java_args_cli }-Djava.io.tmpdir=$PUPPET_TMPDIR"
    replace_assignment "$PUPPETSERVER_SYSCONFIG" JAVA_ARGS_CLI "$java_args_cli"

    chown root:root "$PUPPETSERVER_SYSCONFIG"
    chmod 0644 "$PUPPETSERVER_SYSCONFIG"
}

configure_openvox_identity() {
    local ssl_dir
    local configured_certname

    ssl_dir="$($PUPPET_BIN config print ssldir)"
    configured_certname="$($PUPPET_BIN config print certname 2>/dev/null || true)"

    if [[ -d "$ssl_dir" ]] && find "$ssl_dir" -type f -print -quit 2>/dev/null | grep -q .; then
        [[ "$configured_certname" == "$PUPPET_FQDN" ]] \
            || die "Existing OpenVox SSL data uses certname '$configured_certname', but PUPPET_FQDN is '$PUPPET_FQDN'. Refusing to replace certificates."
        "$PUPPET_BIN" config set server "$PUPPET_FQDN" --section main
        log "Existing OpenVox SSL data found; certificate identity changes skipped"
        return 0
    fi

    log "Configuring OpenVox Server certificate identity"
    "$PUPPET_BIN" config set certname "$PUPPET_FQDN" --section main
    "$PUPPET_BIN" config set server "$PUPPET_FQDN" --section main
    "$PUPPET_BIN" config set dns_alt_names "$DNS_ALT_NAMES" --section server
}

start_puppetserver_for_ca() {
    systemctl enable --now puppetserver
    wait_for_service puppetserver 120

    # Confirm that the CA and server certificate were generated.
    [[ -s "$($PUPPET_BIN config print localcacert)" ]] \
        || die "OpenVox CA certificate was not generated."
    [[ -s "$($PUPPET_BIN config print hostcert)" ]] \
        || die "OpenVox Server host certificate was not generated."
}

configure_openvoxdb_files() {
    local database_ini="$PUPPETDB_CONFDIR/database.ini"

    install -d -o root -g puppetdb -m 0750 "$PUPPETDB_CONFDIR"
    backup_file "$database_ini"

    cat >"$database_ini" <<EOF
[database]
subname = //127.0.0.1:5432/puppetdb
username = puppetdb
password = $PUPPETDB_PASSWORD

[read-database]
subname = //127.0.0.1:5432/puppetdb
username = puppetdb_read
password = $PUPPETDB_READ_PASSWORD
EOF

    chown root:puppetdb "$database_ini"
    chmod 0640 "$database_ini"
    if command -v restorecon >/dev/null 2>&1; then
        restorecon -v "$database_ini" || true
    fi
}

find_puppetdb_command() {
    if [[ -x /opt/puppetlabs/bin/puppetdb ]]; then
        printf '%s' /opt/puppetlabs/bin/puppetdb
    elif command -v puppetdb >/dev/null 2>&1; then
        command -v puppetdb
    else
        return 1
    fi
}

configure_openvoxdb_ssl() {
    local puppetdb_command

    puppetdb_command=$(find_puppetdb_command) \
        || die "The puppetdb command was not found after package installation."

    log "Configuring OpenVoxDB SSL from the OpenVox CA"
    "$puppetdb_command" ssl-setup
}

configure_puppetserver_openvoxdb_connection() {
    local puppetdb_conf="$PUPPET_CONFDIR/puppetdb.conf"
    local routes_file="$PUPPET_CONFDIR/routes.yaml"

    install -d -o root -g puppet -m 0750 "$PUPPET_CONFDIR"
    backup_file "$puppetdb_conf"
    backup_file "$routes_file"

    cat >"$puppetdb_conf" <<EOF
[main]
server_urls = https://${PUPPET_FQDN}:8081
EOF

    cat >"$routes_file" <<'EOF'
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

    chown puppet:puppet "$puppetdb_conf" "$routes_file"
    chmod 0640 "$puppetdb_conf" "$routes_file"

    "$PUPPET_BIN" config set storeconfigs true --section master
    "$PUPPET_BIN" config set storeconfigs_backend puppetdb --section master
    "$PUPPET_BIN" config set reports store,puppetdb --section master

    if command -v restorecon >/dev/null 2>&1; then
        restorecon -v "$puppetdb_conf" "$routes_file" "$PUPPET_CONFDIR/puppet.conf" || true
    fi
}

start_openvox_services() {
    systemctl enable --now puppetdb
    wait_for_service puppetdb 120

    systemctl restart puppetserver
    wait_for_service puppetserver 120
}

configure_firewall() {
    [[ "$OPEN_FIREWALL" == "true" ]] || return 0

    if systemctl is-active --quiet firewalld 2>/dev/null && command -v firewall-cmd >/dev/null 2>&1; then
        log "Opening TCP/8140 in firewalld for OpenVox agents"
        firewall-cmd --permanent --add-port=8140/tcp >/dev/null
        firewall-cmd --reload >/dev/null
    else
        warn "firewalld is not active; TCP/8140 was not opened automatically."
    fi
}

verify_installation() {
    local service

    log "Verifying installed services"
    for service in postgresql puppetdb puppetserver; do
        systemctl is-active --quiet "$service" || die "$service is not active."
        systemctl is-enabled --quiet "$service" || die "$service is not enabled."
    done

    [[ "$(psql --version | awk '{print $3}' | cut -d. -f1)" == "16" ]] \
        || die "PostgreSQL client is not version 16."

    grep -q -- '-XX:ReservedCodeCacheSize=2G' "$PUPPETSERVER_SYSCONFIG" \
        || die "ReservedCodeCacheSize was not configured."
    grep -q -- "-Djava.io.tmpdir=$PUPPET_TMPDIR" "$PUPPETSERVER_SYSCONFIG" \
        || die "Puppet Server java.io.tmpdir was not configured."
    [[ "$(stat -c '%a' "$PUPPET_TMPDIR")" == "1777" ]] \
        || die "$PUPPET_TMPDIR does not have mode 1777."

    curl -fsS http://127.0.0.1:8080/status/v1/services >/dev/null \
        || die "OpenVoxDB local status endpoint is not responding."

    "$PUPPET_BIN" agent --test --server "$PUPPET_FQDN" --certname "$PUPPET_FQDN"

    log "Installation completed successfully"
    printf '\nOpenVox Server:  https://%s:8140\n' "$PUPPET_FQDN"
    printf 'OpenVoxDB HTTPS: https://%s:8081\n' "$PUPPET_FQDN"
    printf 'Credentials:     %s (mode 0600)\n' "$CREDENTIAL_FILE"
    printf 'JVM configuration: %s\n' "$PUPPETSERVER_SYSCONFIG"
}

main() {
    require_root
    require_rhel9
    validate_options
    validate_fqdn

    log "Beginning single-host OpenVox installation for $PUPPET_FQDN"

    install_prerequisites
    load_or_generate_credentials
    install_postgresql16
    configure_postgresql_authentication
    configure_openvoxdb_database

    install_openvox_packages
    configure_puppetserver_jvm
    configure_openvox_identity
    start_puppetserver_for_ca

    configure_openvoxdb_files
    configure_openvoxdb_ssl
    configure_puppetserver_openvoxdb_connection
    start_openvox_services
    configure_firewall
    verify_installation
}

main "$@"
