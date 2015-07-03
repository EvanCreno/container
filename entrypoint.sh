#!/bin/bash
set -e

OWNCLOUD_CONF_DIR=${OWNCLOUD_DATA_DIR}/conf
OWNCLOUD_OCDATA_DIR=${OWNCLOUD_DATA_DIR}/ocdata

OWNCLOUD_FQDN=${OWNCLOUD_FQDN:-localhost}

DB_TYPE=${DB_TYPE:-}
DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-}
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

# is a mysql or postgresql database linked?
# requires that the mysql or postgresql containers have exposed
# port 3306 and 5432 respectively.
if [[ -n ${MYSQL_PORT_3306_TCP_ADDR} ]]; then
  DB_TYPE=${DB_TYPE:-mysql}
  DB_HOST=${DB_HOST:-mysql}
  DB_PORT=${DB_PORT:-${MYSQL_PORT_3306_TCP_PORT}}

  # support for linked sameersbn/mysql image
  DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
  DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
  DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}

  # support for linked orchardup/mysql and enturylink/mysql image
  # also supports official mysql image
  DB_USER=${DB_USER:-${MYSQL_ENV_MYSQL_USER}}
  DB_PASS=${DB_PASS:-${MYSQL_ENV_MYSQL_PASSWORD}}
  DB_NAME=${DB_NAME:-${MYSQL_ENV_MYSQL_DATABASE}}
elif [[ -n ${POSTGRESQL_PORT_5432_TCP_ADDR} ]]; then
  DB_TYPE=${DB_TYPE:-pgsql}
  DB_HOST=${DB_HOST:-postgresql}
  DB_PORT=${DB_PORT:-${POSTGRESQL_PORT_5432_TCP_PORT}}

  # support for linked official postgres image
  DB_USER=${DB_USER:-${POSTGRESQL_ENV_POSTGRES_USER}}
  DB_PASS=${DB_PASS:-${POSTGRESQL_ENV_POSTGRES_PASSWORD}}
  DB_NAME=${DB_NAME:-${DB_USER}}

  # support for linked sameersbn/postgresql image
  DB_USER=${DB_USER:-${POSTGRESQL_ENV_DB_USER}}
  DB_PASS=${DB_PASS:-${POSTGRESQL_ENV_DB_PASS}}
  DB_NAME=${DB_NAME:-${POSTGRESQL_ENV_DB_NAME}}

  # support for linked orchardup/postgresql image
  DB_USER=${DB_USER:-${POSTGRESQL_ENV_POSTGRESQL_USER}}
  DB_PASS=${DB_PASS:-${POSTGRESQL_ENV_POSTGRESQL_PASS}}
  DB_NAME=${DB_NAME:-${POSTGRESQL_ENV_POSTGRESQL_DB}}

  # support for linked paintedfox/postgresql image
  DB_USER=${DB_USER:-${POSTGRESQL_ENV_USER}}
  DB_PASS=${DB_PASS:-${POSTGRESQL_ENV_PASS}}
  DB_NAME=${DB_NAME:-${POSTGRESQL_ENV_DB}}
fi

# set default user and database
DB_USER=${DB_USER:-owncloud}
DB_NAME=${DB_NAME:-ownclouddb}

if [[ -z ${DB_HOST} ]]; then
  echo "ERROR: "
  echo "  Please configure the database connection."
  echo "  Cannot continue without a database. Aborting..."
  exit 1
fi

# use default port number if it is still not set
case ${DB_TYPE} in
  mysql) DB_PORT=${DB_PORT:-3306} ;;
  pgsql) DB_PORT=${DB_PORT:-5432} ;;
  *)
    echo "ERROR: "
    echo "  Please specify the database type in use via the DB_TYPE configuration option."
    echo "  Accepted values are \"pgsql\" or \"mysql\". Aborting..."
    exit 1
    ;;
esac

# fix ownership of the OWNCLOUD_DATA_DIR
chown -R ${OWNCLOUD_USER}:${OWNCLOUD_USER} ${OWNCLOUD_DATA_DIR}/

# create the data and conf directories
sudo -HEu ${OWNCLOUD_USER} mkdir -p ${OWNCLOUD_OCDATA_DIR}
sudo -HEu ${OWNCLOUD_USER} mkdir -p ${OWNCLOUD_CONF_DIR}

# create symlinks to config.php
sudo -HEu ${OWNCLOUD_USER}  ln -sf ${OWNCLOUD_CONF_DIR}/config.php ${OWNCLOUD_INSTALL_DIR}/config/config.php

if [ ! -f ${OWNCLOUD_CONF_DIR}/config.php ]; then
  # copy configuration template
  sudo -HEu ${OWNCLOUD_USER} cp /var/cache/owncloud/conf/owncloud/autoconfig.php ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php

  # configure database connection
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_TYPE}}/'"${DB_TYPE}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_HOST}}/'"${DB_HOST}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_PORT}}/'"${DB_PORT}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_NAME}}/'"${DB_NAME}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_USER}}/'"${DB_USER}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
  sudo -HEu ${OWNCLOUD_USER} sed -i 's/{{DB_PASS}}/'"${DB_PASS}"'/' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php

  # configure owncloud data directory
  sudo -HEu ${OWNCLOUD_USER} sed -i 's,{{OWNCLOUD_OCDATA_DIR}},'"${OWNCLOUD_OCDATA_DIR}"',' ${OWNCLOUD_INSTALL_DIR}/config/autoconfig.php
fi

# create VERSION file, not used at the moment but might be required in the future
CURRENT_VERSION=
[ -f ${OWNCLOUD_DATA_DIR}/VERSION ] && CURRENT_VERSION=$(cat ${OWNCLOUD_DATA_DIR}/VERSION)
[ "${OWNCLOUD_VERSION}" != "${CURRENT_VERSION}" ] && echo -n "${OWNCLOUD_VERSION}" | sudo -HEu ${OWNCLOUD_USER} tee ${OWNCLOUD_DATA_DIR}/VERSION >/dev/null

# install nginx configuration, if not exists
if [ -d /etc/nginx/sites-enabled -a ! -f /etc/nginx/sites-enabled/${OWNCLOUD_FQDN}.conf ]; then
  cp /var/cache/owncloud/conf/nginx/ownCloud.conf /etc/nginx/sites-enabled/${OWNCLOUD_FQDN}.conf
  sed -i 's,{{OWNCLOUD_FQDN}},'"${OWNCLOUD_FQDN}"',' /etc/nginx/sites-enabled/${OWNCLOUD_FQDN}.conf
  sed -i 's,{{OWNCLOUD_INSTALL_DIR}},'"${OWNCLOUD_INSTALL_DIR}"',' /etc/nginx/sites-enabled/${OWNCLOUD_FQDN}.conf
fi

exec $@
