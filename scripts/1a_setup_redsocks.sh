#!/usr/bin/env bash
## Ubuntu 16- Redsocks Proxy
#

# show install in log
echo .
echo "######################################"
echo "######################################"
echo "## Installation of redsocks - START ##"
echo "######################################"
echo "######################################"
echo .


BASE_PROXY=$1
PROXY_PARTS=($(echo "$BASE_PROXY" | tr ':' '\n'))
BASE_PROXY_HOST=$(echo "${PROXY_PARTS[1]}" | tr -d "//")
BASE_PROXY_PORT=$(echo "${PROXY_PARTS[2]}" | tr -d "//")

# temporarily set proxy for install routine
export http_proxy="$BASE_PROXY" \
        HTTP_PROXY="$BASE_PROXY" \
        https_proxy="$BASE_PROXY" \
        HTTPS_PROXY="$BASE_PROXY"


# Ensure no interactive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# Install prerequisite
apt-get update -y
apt-get -y install iptables-persistent libevent-dev


echo "## Configuring transparent proxy"
(
    echo "# Writing redsocks config"
    echo """base {
    log_debug = on;
    log_info = on;
    log = \"syslog:daemon\";
    daemon = off;
    redirector = iptables;
}
redsocks {
    local_ip = 0.0.0.0;
    local_port = 3080;
    ip = $BASE_PROXY_HOST;
    port = $BASE_PROXY_PORT;
    type = http-relay;
}
redsocks {
    local_ip = 0.0.0.0;
    local_port = 3443;
    ip = $BASE_PROXY_HOST;
    port = $BASE_PROXY_PORT;
    type = http-connect;
}""" > /etc/redsocks.conf

    echo "# Writing iptables rules"
    iptables -t nat -N REDSOCKSHTTP
    iptables -t nat -A REDSOCKSHTTP -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 100.64.0.0/10 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKSHTTP -p tcp -j REDIRECT --to-ports 3080

    iptables -t nat -N REDSOCKSHTTPS
    iptables -t nat -A REDSOCKSHTTPS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 100.64.0.0/10 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A REDSOCKSHTTPS -p tcp -j REDIRECT --to-ports 3443

    iptables -t nat -A PREROUTING -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A PREROUTING -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A PREROUTING -d 100.64.0.0/10 -j RETURN
    iptables -t nat -A PREROUTING -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A PREROUTING -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A PREROUTING -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A PREROUTING -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A PREROUTING -d 240.0.0.0/4 -j RETURN
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3080
    iptables -t nat -A PREROUTING -p tcp --dport 8080 -j REDIRECT --to 3080
    iptables -t nat -A PREROUTING -p tcp -j REDIRECT --to 3443

    iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDSOCKSHTTP
    iptables -t nat -A OUTPUT -p tcp --dport 8080 -j REDSOCKSHTTP
    iptables -t nat -A OUTPUT -p tcp -j REDSOCKSHTTPS

    echo "# Storing iptables rules for persistence"
#    iptables-save > /etc/sysconfig/iptables
    netfilter-persistent save

    echo "# Disabling ipv6"
    echo """net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.eth0.disable_ipv6 = 1""" >> /etc/sysctl.conf
)

# create systemd.service
echo """[Unit]
Description=Redsocks transparent SOCKS proxy redirector
After=network.target

[Service]
Type=simple
Restart=always
ExecStartPre=/usr/local/bin/redsocks -t -c /etc/redsocks.conf
ExecStart=/usr/local/bin/redsocks -c /etc/redsocks.conf

[Install]
WantedBy=multi-user.target
""" > /etc/systemd/system/redsocks.service
#
echo "## Enabling services"
(
    systemctl enable redsocks.service
    systemctl start redsocks.service
    systemctl enable netfilter-persistent
    systemctl start netfilter-persistent
)

# show process and port
systemctl status redsocks.service
ps aux | grep -i redsocks
netstat -tulpen

# create healthcheck script for redsocks
mkdir -p /opt/redsocks
cat << 'EOF' > /opt/redsocks/healthcheck.sh
#!/usr/bin/env bash

LOG=$(echo $0).log
CIAS_IP_FILE=$(echo $0).cias_ip
CIAS_IP=$(nslookup $BASE_PROXY_HOST | grep 'Address:' | grep -v '#' | sort | xargs | sed 's/Address: //g')

if [[ "$CIAS_IP" != "$(cat $CIAS_IP_FILE)" ]]; then
    echo -n "$(date) | " >> $LOG
    echo -n "new cias_ip: $CIAS_IP | " >> $LOG
    echo -n "old cias_ip: $(cat $CIAS_IP_FILE) | " >> $LOG
    echo "restarting redsocks.service" >> $LOG
    systemctl restart redsocks.service
fi

echo -n "$CIAS_IP" > $CIAS_IP_FILE
EOF

# execute healthcheck via cron
chmod +x /opt/redsocks/healthcheck.sh
echo "0 * * * * root flock -xn /opt/redsocks/healthcheck.sh.lck -c /opt/redsocks/healthcheck.sh" >> /etc/crontab

# show install in log
echo .
echo ######################################
echo ######################################
echo ## Installation of redsocks - END   ##
echo ######################################
echo ######################################
echo .
