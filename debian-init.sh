#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent

#开启 zram
echo -e "ALGO=zstd\nPERCENT=100" > /etc/default/zramswap
service zramswap reload

# 去除布告栏信息
echo '' >/etc/motd
echo '' >/etc/issue

# Fail2ban
cat <<EOF > /etc/fail2ban/jail.d/defaults-debian.conf
[sshd]
enabled = true
backend=systemd
EOF
systemctl restart fail2ban

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

rm -rf /etc/sysctl.d/*
cat > /etc/sysctl.conf << EOF
fs.file-max = 6553560
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 100
EOF
sysctl -p && sysctl --system

#
sed -i '/^#*DefaultLimitCORE=/s/^#*//; s/DefaultLimitCORE=.*/DefaultLimitCORE=0/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNOFILE=/s/^#*//; s/DefaultLimitNOFILE=.*/DefaultLimitNOFILE=65535/'  /etc/systemd/system.conf
sed -i '/^#*DefaultLimitNPROC=/s/^#*//; s/DefaultLimitNPROC=.*/DefaultLimitNPROC=65535/'  /etc/systemd/system.conf
systemctl daemon-reload
