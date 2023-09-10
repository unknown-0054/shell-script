#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent

#开启 zram
echo -e "ALGO=zstd\nPERCENT=100" >/etc/default/zramswap
service zramswap reload

# 去除布告栏信息
echo '' >/etc/motd
echo '' >/etc/issue

# Fail2ban
cat <<EOF >/etc/fail2ban/jail.d/defaults-debian.conf
[sshd]
enabled = true
backend=systemd
EOF
systemctl restart fail2ban

# 屏蔽 docker.io
cat <<EOF >/etc/apt/preferences.d/docker
Package: docker docker.io docker-compose 
Pin: release *
Pin-Priority: -1
EOF

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

# 添加别名
if ! grep -q "alias dc" ~/.bashrc; then
  echo "alias dc='docker compose'" >>~/.bashrc
fi
source ~/.bashrc

# docker 
sh <(curl -k 'https://get.docker.com') && source  ~/.bashrc
rm -rf /opt/*

# tcp
Mem=`grep MemTotal /proc/meminfo | awk -F ':' '{print $2}' | awk '{print $1}'`
totalMem=`echo "scale=2; $Mem/1024/1024" | bc`
rm -rf /etc/sysctl.d/*
cat >/etc/sysctl.conf <<EOF
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
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

if [[ ${totalMem//.*/} -lt 4 ]]; then #<4GB 1G_3G_8G
  sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=262144 786432 2097152#g" /etc/sysctl.conf
elif [[ ${totalMem//.*/} -ge 4 && ${totalMem//.*/} -lt 7 ]]; then #6GB 2G_4G_8G
  sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=524288 1048576 2097152#g" /etc/sysctl.conf
elif [[ ${totalMem//.*/} -ge 7 && ${totalMem//.*/} -lt 11 ]]; then #8GB 3G_4G_12G
  sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=786432 1048576 3145728#g" /etc/sysctl.conf
elif [[ ${totalMem//.*/} -ge 11 && ${totalMem//.*/} -lt 15 ]]; then #12GB 4G_6G_12G
  sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 1572864 3145728#g" /etc/sysctl.conf
elif [[ ${totalMem//.*/} -ge 15 ]]; then #>16GB 4G_8G_12G
  sed -i "s#.*net.ipv4.tcp_mem=.*#net.ipv4.tcp_mem=1048576 2097152 3145728#g" /etc/sysctl.conf
fi

sysctl -p && sysctl --system

#
sed -i '/^#*DefaultLimitCORE=/s/^#*//; s/DefaultLimitCORE=.*/DefaultLimitCORE=0/' /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNOFILE=/s/^#*//; s/DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65535/' /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNPROC=/s/^#*//; s/DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/' /etc/systemd/system.conf
systemctl daemon-reload


#
sed -i '/^#*DefaultLimitCORE=/s/^#*//; s/DefaultLimitCORE=.*/DefaultLimitCORE=0/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNOFILE=/s/^#*//; s/DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65535/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNPROC=/s/^#*//; s/DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/'  /etc/systemd/system.conf
systemctl daemon-reload
