#!/bin/bash
set -eu

REDASH_BASE_PATH=/opt/redash
REDASH_BRANCH="${REDASH_BRANCH:-master}"
REDASH_VERSION=${REDASH_VERSION-3.0.0.b3134} # Install latest version if not specified in REDASH_VERSION env var
LATEST_URL="https://s3.amazonaws.com/redash-releases/redash.${REDASH_VERSION}.tar.gz"
VERSION_DIR="$REDASH_BASE_PATH/redash.${REDASH_VERSION}"
REDASH_TARBALL=/tmp/redash.tar.gz
FILES_BASE_URL=https://raw.githubusercontent.com/oscasierra/redash-setup-centos/${REDASH_BRANCH}/7/files

cd /tmp/

verify_root() {
    # Verify running as root:
    if [ "$(id -u)" != "0" ]; then
        if [ $# -ne 0 ]; then
            echo "Failed running with sudo. Exiting." 1>&2
            exit 1
        fi
        echo "This script must be run as root. Trying to run with sudo."
        sudo bash "$0" --with-sudo
        exit 0
    fi
}

install_system_packages() {
    yum -y update

    # Add Nginx yum repository
    echo "[nginx]" >> /etc/yum.repos.d/nginx.repo
    echo "name=nginx repo" >> /etc/yum.repos.d/nginx.repo
    echo "baseurl=http://nginx.org/packages/centos/7/\$basearch/" >> /etc/yum.repos.d/nginx.repo
    echo "gpgcheck=0" >> /etc/yum.repos.d/nginx.repo
    echo "enabled=1" >>/etc/yum.repos.d/nginx.repo
    yum -y localinstall http://dev.mysql.com/get/mysql57-community-release-el7-7.noarch.rpm

    # Base packages
    yum -y install epel-release
    yum -y install supervisor
    yum -y install python2-pip python-devel
    yum -y install nginx expect sudo wget gcc gcc-c++ cyrus-sasl-devel
    echo $PATH
    pip install setuptools --upgrade

    # Data Sources dependencies:
    yum -y install libpqxx-devel mysql-community-devel

    # Storage servers
    yum -y install postgresql-server redis
    postgresql-setup initdb
    systemctl enable postgresql
    systemctl start postgresql
    systemctl enable redis
    systemctl start redis

    # Base packages
    #apt install -y python-pip python-dev nginx curl build-essential pwgen
    # Data sources dependencies:
    #apt install -y libffi-dev libssl-dev libmysqlclient-dev libpq-dev freetds-dev libsasl2-dev
    # SAML dependency
    #apt install -y xmlsec1
    # Storage servers
    #apt install -y postgresql redis-server
    #apt install -y supervisor
}

create_redash_user() {
    adduser --system --no-create-home -s /sbin/nologin redash
}

create_directories() {
    mkdir -p $REDASH_BASE_PATH
    chown redash $REDASH_BASE_PATH
    
    # Default config file
    if [ ! -f "$REDASH_BASE_PATH/.env" ]; then
       curl "$FILES_BASE_URL/env" -o $REDASH_BASE_PATH/.env
       #echo 'export REDASH_LOG_LEVEL="INFO"' >> $REDASH_BASE_PATH/.env
       #echo 'export REDASH_REDIS_URL=redis://localhost:6379/0' >> $REDASH_BASE_PATH/.env
       #echo 'export REDASH_DATABASE_URL="postgresql:///redash"' >> $REDASH_BASE_PATH/.env
    fi

    COOKIE_SECRET=$(mkpasswd -l 32)
    echo "export REDASH_COOKIE_SECRET=$COOKIE_SECRET" >> $REDASH_BASE_PATH/.env
}

extract_redash_sources() {
    echo $LATEST_URL
    echo $REDASH_TARBALL
    sudo -u redash curl -L $LATEST_URL -o $REDASH_TARBALL
    sudo -u redash mkdir "$VERSION_DIR"
    sudo -u redash tar -C "$VERSION_DIR" -xvf "$REDASH_TARBALL"
    ln -nfs "$VERSION_DIR" $REDASH_BASE_PATH/current
    ln -nfs $REDASH_BASE_PATH/.env $REDASH_BASE_PATH/current/.env
}

install_python_packages() {
    pip install --upgrade pip
    # TODO: venv?
    pip install setproctitle # setproctitle is used by Celery for "pretty" process titles
    pip install -r $REDASH_BASE_PATH/current/requirements.txt
    pip install -r $REDASH_BASE_PATH/current/requirements_all_ds.txt
}

create_database() {
    # Create user and database
    sudo -u postgres createuser redash --no-superuser --no-createdb --no-createrole
    sudo -u postgres createdb redash --owner=redash

    cd $REDASH_BASE_PATH/current
    sudo -u redash bin/run ./manage.py database create_tables
}

setup_supervisor() {
    curl -L $FILES_BASE_URL/supervisord.conf -o /etc/supervisord.d/redash.ini
    systemctl start supervisord
}

setup_nginx() {
    rm /etc/nginx/conf.d/default.conf
    curl $FILES_BASE_URL/nginx_redash_site -o /etc/nginx/conf.d/default.conf
    #rm /etc/nginx/sites-enabled/default
    #wget -O /etc/nginx/sites-available/redash "$FILES_BASE_URL/nginx_redash_site"
    #ln -nfs /etc/nginx/sites-available/redash /etc/nginx/sites-enabled/redash
    systemctl enable nginx
    systemctl start nginx
}

verify_root
install_system_packages
create_redash_user
create_directories
extract_redash_sources
install_python_packages
create_database
setup_supervisor
setup_nginx

