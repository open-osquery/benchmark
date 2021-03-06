#!/bin/bash
# script to set up a monitoring environment for osquery performance

## log helpers
function _getdate() { date "+%Y:%m:%d %H:%M:%S"; }
function _log() { printf "%s\n" "$(_getdate) $*" | tee -a /tmp/install.log; }

function info() { _log "[INFO ]" $1; }
function error() { _log "[ERROR]" $1; }
function warn() { _log "[WARN ]" $1; }
function fatal() { _log "[FATAL]" $1; exit 1; }

function set_selinux_policy() {
    info "Setting selinux policy for ports for ports 9100, 9256, 8888, 8080"
    semanage port -a -t http_port_t -p tcp 9100 # node_exporter
    semanage port -a -t http_port_t -p tcp 9256 # process_exporter
    semanage port -a -t http_port_t -p tcp 8888 # cfssl
    semanage port -a -t http_port_t -p tcp 8080 # nginx

    info "Disable setlinux enforce and firewalld"
    setenforce 0
    systemctl stop firewalld
    systemctl disable firewalld

    info "firewalld status: $(systemctl is-enable firewalld)"
}

function install_deps() {
    info "Installing dependencies"
    if yum update -y; then
        info "Yum update complete"
    fi
    if yum install epel-release -y; then
        info "Installed epel-release for nginx"
    fi

    if yum install wget yum-utils net-tools policycoreutils-python nginx -y; then
        info "Installed wget, yum-utils, net-tools, selinux utils, nginx"
    fi

    info "Completed installing dependencies"
}

function install_osquery() {
    info "Installing osquery"
    curl -L https://pkg.osquery.io/rpm/GPG | sudo tee /etc/pki/rpm-gpg/RPM-GPG-KEY-osquery
    yum-config-manager --add-repo https://pkg.osquery.io/rpm/osquery-s3-rpm.repo
    yum-config-manager --enable osquery-s3-rpm
    yum install osquery -y

    info "Setting up osquery directories"
    mkdir -p /etc/osquery
    mkdir -p /etc/osquery/osquery.conf.d

    wget --no-check-certificate -O "/etc/osquery/osquery.conf" \
    "https://gist.githubusercontent.com/prateeknischal/3b2038ec080f1dd1b9510ffb5f9cf909/raw/osquery.conf"

    if systemctl start osqueryd; then
        info "osquery started successfully"
    fi
}

function disable_auditd() {
    info "Checking auditd status"
    if systemctl is-active auditd; then
        info "Detected auditd.service running, attempting to disable"
        sed -i "s/RefuseManualStop=yes/RefuseManualStop=no/g" /usr/lib/systemd/system/auditd.service
        systemctl daemon-reload
        systemctl stop auditd
        systemctl disable auditd
        info "Auditd status: ${systemctl is-active auditd}"
    fi

    sleep 2
    if systemctl is-active auditd; then
        fatal "auditd is still running, aborting"
    fi
}

function install_node_exporter() {
    info "Installing node_exporter"
    wget --no-check-certificate -c \
        https://github.com/prometheus/node_exporter/releases/download/v0.18.1/node_exporter-0.18.1.linux-amd64.tar.gz

    tar -xvf node_exporter-0.18.1.linux-amd64.tar.gz
    mv node_exporter-0.18.1.linux-amd64/node_exporter /usr/local/bin/
    useradd -rs /bin/false node_exporter

    cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl start node_exporter
    systemctl enable node_exporter

    if ! systemctl is-active node_exporter; then
        error "Node exporter failed to start"
    fi
}

function install_process_exporter() {
    info "Installing process_exporter"
    wget --no-check-certificate -c \
            https://github.com/ncabatoff/process-exporter/releases/download/v0.7.5/process-exporter_0.7.5_linux_amd64.rpm
    sudo rpm -i process-exporter_0.7.5_linux_amd64.rpm

    cat << EOF > /etc/process-exporter/all.yaml
process_names:
  - comm:
    - osqueryd
    - /etc/osquery/wm-osquery.ext
EOF
    systemctl daemon-reload
    systemctl start process-exporter
    systemctl enable process-exporter

    if ! systemctl is-active process-exporter; then
        error "Process exporter failed to start"
    fi
}

function install_cfssl() {
    info "Installing cfssl"
    mkdir /opt/cfssl
    wget --no-check-certificate -c \
             https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64 \
            -O /opt/cfssl/cfssl

    chmod +x /opt/cfssl/cfssl

    cat << EOF > /opt/cfssl/cfssl.service
[Unit]
Description=Cloudflare SSL toolkit
Wants=network-online.target
After=network-online.target
[Service]
User=root
Group=root
Type=simple
ExecStart=/opt/cfssl/cfssl serve -loglevel 0
[Install]
WantedBy=multi-user.target
EOF

    systemctl enable /opt/cfssl/cfssl.service
    systemctl daemon-reload
    if systemctl start cfssl; then
        info "cfssl installed and running successfully"
    fi
}

function main() {
    install_deps
    disable_auditd
    set_selinux_policy
    install_osquery
    install_node_exporter
    install_process_exporter
    install_cfssl
}

main "$@"
