# README.md

## Usage

Execute the following command for installing Redash on centOS 7.

    # git clone https://github.com/oscasierra/redash-setup-centos.git
    # cd redash-setup-centos/7
    # bootstrap.sh

## SELinux & Firewalld Settings

### SELinux

If your centOS is enable SELinux, you might need to change your SELinux Setting.

    setsebool httpd_can_network_connect on -P

**httpd_can_network_connect** flag is for Allowing HTTPD scripts and modules to connect to the network.

### Firewalld

If your centOS is enable Firewalld, you need to permit 80 port access.

    # firewall-cmd --add-service=http --zone=public --permanent
    # firewall-cmd --reload

