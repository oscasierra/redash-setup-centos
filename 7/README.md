# README.md

## Usage

Execute the following command for installing Redash on centOS 7.

    # curl -OL https://raw.githubusercontent.com/oscasierra/redash-setup-centos/master/7/bootstrap.sh
    # source bootstrap.sh

## SELinux & Firewalld Settings

### SELinux

If SELinux is enabled, you might need to change your SELinux Setting.

    setsebool httpd_can_network_connect on -P

**httpd_can_network_connect** flag is for Allowing HTTPD scripts and modules to connect to the network.

### Firewalld

If firewalld is enabled, you need to permit 80 port access.

    # firewall-cmd --add-service=http --zone=public --permanent
    # firewall-cmd --reload

