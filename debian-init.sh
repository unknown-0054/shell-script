#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

CheckRoot(){
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1
}

CheckSystem(){
if [ -f /etc/os-release ]; then
    . /etc/os-release
    # 检查 $ID 变量是否为 "debian"
    if [ "$ID" != "debian" ]; then
        echo -e "${red} 此脚本只能在Debian系统中运行"
        exit 1
    fi
else
    echo -e "${red}无法确定操作系统类型"
    exit 1
fi
}

InstallPackages(){
apt install -y sudo bash-completion vim curl wget ntp net-tools zram-tools fail2ban dnsutils vnstat iperf3 qemu-guest-agent &> /dev/null
echo  -e  "${green}常用软件包安装完成"
}

ClearLoginInfo(){
echo '' >/etc/motd
echo '' >/etc/issue
}

DhclientHook(){
cat <<EOF >/etc/dhcp/dhclient-enter-hooks.d/nodnsupdate
#!/bin/sh
make_resolv_conf(){
    :
}
EOF
chmod +x /etc/dhcp/dhclient-enter-hooks.d/nodnsupdate
}

VimConfig(){
  echo "set mouse-=a" >~/.vimrc
}

InstallDocker(){

cat <<EOF >/etc/apt/preferences.d/docker
Package: docker docker.io docker-compose 
Pin: release *
Pin-Priority: -1
EOF

if command -v docker &> /dev/null; then
    docker_version=$(docker --version | awk '{print $3}')
    echo -e "${green}Docker已安装,版本号：$docker_version"
else
    echo -e "${green} 开始安装 Docker"
    if [[ $(curl -m 10 -s https://ipapi.co/json | grep 'China') != "" ]]; then
      export DOWNLOAD_URL="https://mirrors.tuna.tsinghua.edu.cn/docker-ce"
    fi
    sh <(curl -k 'https://get.docker.com') &> /dev/null
    rm -rf /opt/containerd
    echo -e "${green} Docker 安装完成"
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

}

SysOptimize(){
rm -rf /etc/sysctl.d/*
cat <<EOF >/etc/sysctl.conf
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

cat <<EOF >/etc/systemd/journald.conf
[Journal]
SystemMaxUse=512M
EOF
echo -e "${green}系统优化完成"
}


main(){
CheckRoot
CheckSystem
InstallPackages
ClearLoginInfo
DhclientHook
VimConfig
InstallDocker
SysOptimize
echo -e "${green}init 完成"
echo -e "\033[0m"
}

main
