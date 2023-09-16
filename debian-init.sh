#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent

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
    sh <(curl -k 'https://get.docker.com')
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
cat <<EOF >/etc/sysctl.d/99-sysctl.conf
fs.file-max=1000000
fs.inotify.max_user_instances=8192
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.ip_forward=1
net.core.somaxconn=3276800
net.core.optmem_max=81920
net.core.wmem_default=131072
net.core.rmem_default=131072
net.core.wmem_max=16777216
net.core.rmem_max=16777216
net.ipv4.tcp_mem=786432 1048576 3145728 
net.ipv4.tcp_wmem=4096 131072 16777216
net.ipv4.tcp_rmem=4096 131072 16777216
net.ipv4.ip_local_port_range = 50000 65535
EOF

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
sysctl -p
   
   echo "1000000" > /proc/sys/fs/file-max
   sed -i '/ulimit -SHn/d' /etc/profile
   echo "ulimit -SHn 1000000" >>/etc/profile
   ulimit -SHn 1000000 && ulimit -c unlimited
   echo "*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited">/etc/security/limits.conf

   sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
   sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
   sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
   sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
   sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
   sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf
   echo "#DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
#DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=20480000
DefaultLimitNPROC=20480000">>/etc/systemd/system.conf
   systemctl daemon-reload
   systemctl daemon-reexec
