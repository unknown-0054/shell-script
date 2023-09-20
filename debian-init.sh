#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent &> /dev/null

# 去除布告栏信息
echo '' >/etc/motd
echo '' >/etc/issue

# hook make_resolv_conf 函数(避免dhclient对/etc/resolv.conf的修改)
cat <<EOF >/etc/dhcp/dhclient-enter-hooks.d/nodnsupdate
#!/bin/sh
make_resolv_conf(){
    :
}
EOF
chmod +x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate

# vim 禁用鼠标
echo "set mouse-=a" >~/.vimrc

# docker 
cat <<EOF >/etc/apt/preferences.d/docker
Package: docker docker.io docker-compose 
Pin: release *
Pin-Priority: -1
EOF

if command -v docker &> /dev/null; then
    echo "Docker已安装"
    docker_version=$(docker --version | awk '{print $3}')
    echo "Docker版本号：$docker_version"
else
    echo "Docker开始安装"
    sh <(curl -k 'https://get.docker.com') &> /dev/null
    rm -rf /opt/containerd
fi

sed -i '/alias dc/d' ~/.bashrc
if command -v docker-compose &> /dev/null; then
    if ! grep -q "alias dc" ~/.bashrc; then
      echo "alias dc='docker-compose'" >>~/.bashrc
    fi
    
else
    if ! grep -q "alias dc" ~/.bashrc; then
      echo "alias dc='docker compose'" >>~/.bashrc
    fi
fi
source ~/.bashrc

# tcp
rm -rf /etc/sysctl.d/*
cat <<EOF >/etc/sysctl.conf
fs.file-max=1000000
fs.inotify.max_user_instances=65536
net.core.default_qdisc=fq
net.core.netdev_max_backlog=131072
net.core.rmem_max=335544320
net.core.somaxconn=32768
net.core.wmem_max=335544320
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.default.forwarding=1
net.ipv4.ip_forward=1
net.ipv4.ip_local_port_range=2000 65535
net.ipv4.ping_group_range=0 2147483647
net.ipv4.tcp_adv_win_scale=-2
net.ipv4.tcp_autocorking=0
net.ipv4.tcp_collapse_max_bytes=6291456
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_ecn=0
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_fack=1
net.ipv4.tcp_fin_timeout=10
net.ipv4.tcp_frto=0
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_max_syn_backlog=131072
net.ipv4.tcp_max_tw_buckets=10000
net.ipv4.tcp_mem=262144 1048576 4194304
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_notsent_lowat=131072
net.ipv4.tcp_orphan_retries=3
net.ipv4.tcp_retries1=3
net.ipv4.tcp_retries2=5
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_rmem=8192 262144 536870912
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_syn_retries=3
net.ipv4.tcp_synack_retries=3
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_wmem=4096 16384 536870912
net.ipv4.udp_mem=262144 1048576 4194304
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.lo.disable_ipv6=0
net.ipv6.conf.lo.forwarding=1
EOF

Mem=`grep MemTotal /proc/meminfo | awk -F ':' '{print $2}' | awk '{print $1}'`
totalMem=`echo "scale=2; $Mem/1024/1024" | bc`

#<4GB 1G_3G_8G
if [[ ${totalMem//.*/} -lt 4 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=262144 786432 2097152#g" /etc/sysctl.conf
#6GB 2G_4G_8G
elif [[ ${totalMem//.*/} -ge 4 && ${totalMem//.*/} -lt 7 ]]; then
    sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=524288 1048576 2097152#g" /etc/sysctl.conf
#8GB 3G_4G_12G
elif [[ ${totalMem//.*/} -ge 7 && ${totalMem//.*/} -lt 11 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=786432 1048576 3145728#g" /etc/sysctl.conf
#12GB 4G_6G_12G
elif [[ ${totalMem//.*/} -ge 11 && ${totalMem//.*/} -lt 15 ]]; then    
    sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 1572864 3145728#g" /etc/sysctl.conf
#>16GB 4G_8G_12G
elif [[ ${totalMem//.*/} -ge 15 ]]; then
    sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 2097152 3145728#g" /etc/sysctl.conf
fi
sysctl -p &> /dev/null
   
echo "1000000" > /proc/sys/fs/file-max
sed -i '/ulimit -SHn/d' /etc/profile
echo "ulimit -SHn 1000000" >>/etc/profile
ulimit -SHn 1000000 && ulimit -c unlimited

cat <<EOF >/etc/security/limits.conf
*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited
EOF

cat <<EOF >/etc/systemd/system.conf
[Manager]
DefaultTimeoutStopSec=30s
DefaultLimitCORE=infinity
DefaultLimitNOFILE=20480000
DefaultLimitNPROC=20480000
EOF
systemctl daemon-reload
systemctl daemon-reexec
