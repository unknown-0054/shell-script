#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools dnsutils vnstat fail2ban iperf3

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

#
sed -i '/^#*DefaultLimitCORE=/s/^#*//; s/DefaultLimitCORE=.*/DefaultLimitCORE=0/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNOFILE=/s/^#*//; s/DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65535/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNPROC=/s/^#*//; s/DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/'  /etc/systemd/system.conf
systemctl daemon-reload

# 内核参数调整
cat >'/etc/sysctl.d/99-sysctl.conf' <<EOF
# 开启 bbr，内核版本 >= 4.9
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 增大可用的客户端端口范围
net.ipv4.ip_local_port_range = 1024 65535

# 尽量多复用连接
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1

# 增大 tcp 缓冲队列，若仍然不够可适当再增加前两项
net.ipv4.tcp_max_syn_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_abort_on_overflow = 1

# 服务器网络非常稳定设置 0，提升吞吐量，服务器网络不够稳定则设置 1
net.ipv4.tcp_slow_start_after_idle = 1

# 尽量少用 swap，多用物理内存；设置 0 表示不使用 swap，设置 100 表示优先使用 swap
vm.swappiness = 100

fs.file-max = 6553560
EOF
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
