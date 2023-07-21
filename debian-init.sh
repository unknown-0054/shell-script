#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools dnsutils vnstat fail2ban

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

# 解除系统限制
ulimit -SHn 1000000 && ulimit -c unlimited
echo "* soft nofile 1048576
* hard nofile 1048576
* soft nproc 1048576
* hard nproc 1048576
* soft core 1048576
* hard core 1048576
* hard memlock unlimited
* soft memlock unlimited" >/etc/security/limits.conf

if grep -q "ulimit" /etc/profile; then
  :
else
  sed -i '/ulimit -SHn/d' /etc/profile
  echo "ulimit -SHn 1000000" >>/etc/profile
fi

if grep -q "pam_limits.so" /etc/pam.d/common-session; then
  :
else
  sed -i '/required pam_limits.so/d' /etc/pam.d/common-session
  echo "session required pam_limits.so" >>/etc/pam.d/common-session
fi

sed -i '/DefaultTimeoutStartSec/d' /etc/systemd/system.conf
sed -i '/DefaultTimeoutStopSec/d' /etc/systemd/system.conf
sed -i '/DefaultRestartSec/d' /etc/systemd/system.conf
sed -i '/DefaultLimitCORE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf
sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf

cat >>'/etc/systemd/system.conf' <<EOF
[Manager]
DefaultTimeoutStartSec=90s
DefaultTimeoutStopSec=30s
DefaultRestartSec=100ms
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

systemctl daemon-reload

# 内核参数调整
cat >'/etc/sysctl.d/99-sysctl.conf' <<EOF
net.ipv4.ip_local_port_range = 10000 65535
EOF
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1
