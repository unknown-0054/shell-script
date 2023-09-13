#!/bin/bash

# 安装软件包
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent

# 去除布告栏信息
echo '' >/etc/motd
echo '' >/etc/issue

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

# docker 
if command -v docker &> /dev/null; then
    echo "Docker已安装"
    docker_version=$(docker --version | awk '{print $3}')
    echo "Docker版本号：$docker_version"
else
    echo "Docker开始安装"
    sh <(curl -k 'https://get.docker.com') && source  ~/.bashrc
    rm -rf /opt/containerd
fi

# 添加别名
if ! grep -q "alias dc" ~/.bashrc; then
  echo "alias dc='docker compose'" >>~/.bashrc
fi
source ~/.bashrc

# cron
cat <<EOF >/tmp/crontab
0 6 * * * /sbin/reboot
EOF
crontab /tmp/crontab
crontab -l
systemctl restart cron
