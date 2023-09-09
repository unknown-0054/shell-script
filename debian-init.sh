#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools dnsutils vnstat iperf3 qemu-guest-agent

#开启 zram
echo -e "ALGO=zstd\nPERCENT=100" > /etc/default/zramswap
service zramswap reload

# 去除布告栏信息
echo '' >/etc/motd
echo '' >/etc/issue

# 屏蔽 docker.io
cat <<EOF > /etc/apt/preferences.d/docker
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
    echo "alias dc='docker compose'" >> ~/.bashrc
fi
source ~/.bashrc

## tcp优化
cat > /etc/sysctl.conf << EOF
fs.file-max = 6553560
net.core.default_qdisc = fq_pie
net.ipv4.tcp_congestion_control = bbr
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_abort_on_overflow = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mem = 164205  218941  328410
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 16384 33554432
vm.swappiness = 10
EOF
sysctl -p && sysctl --system

#
sed -i '/^#*DefaultLimitCORE=/s/^#*//; s/DefaultLimitCORE=.*/DefaultLimitCORE=0/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNOFILE=/s/^#*//; s/DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65535/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNPROC=/s/^#*//; s/DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/'  /etc/systemd/system.conf
systemctl daemon-reload
