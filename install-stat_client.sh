#!/bin/sh

working_dir=/opt/serverstatus
client_dir="$working_dir/client"
tmp_client_file=/tmp/stat_client
client_file="$client_dir/stat_client"
service_name="stat_client.service"

function check_release() {
    if [[ -f /etc/redhat-release ]]; then
        release="rpm"
    elif grep -q -E -i "centos|red hat|redhat" /proc/version; then
        release="rpm"
    elif grep -q -E -i "centos|red hat|redhat" /etc/issue; then
        release="rpm"
    elif grep -q -E -i "debian|ubuntu" /etc/issue; then
        release="deb"
    elif grep -q -E -i "debian|ubuntu" /proc/version; then
        release="deb"
    else
        echo -e "${Error} 暂不支持该 Linux 发行版"
        exit 1
    fi
}

function check_arch() {
    case $(uname -m) in
        x86_64)
            arch=x86_64
        ;;
        aarch64 | aarch64_be | arm64 | armv8b | armv8l)
            arch=aarch64
        ;;
        *)
            echo -e "${Error} 暂不支持该系统架构"
            exit 1
        ;;
    esac
}



function install_tool() {
  if ! command -v unzip &> /dev/null; then
    echo "unzip not found. Installing unzip..."
    if [[ ${release} == "rpm" ]]; then
      yum -y install unzip
    elif [[ ${release} == "deb" ]]; then
      apt -y update
      apt -y install unzip
    fi
  fi

  if ! command -v wget &> /dev/null; then
    echo "wget not found. Installing wget..."
    if [[ ${release} == "rpm" ]]; then
      yum -y install wget
    elif [[ ${release} == "deb" ]]; then
      apt -y update
      apt -y install wget
    fi
  fi
}

function install_client() {
    echo -e "${Info} 下载 ${arch} 二进制文件"
    [ -f "/tmp/stat_client" ] || get_status -c
    mkdir -p ${client_dir}
    mv $tmp_client_file $client_file
    chmod +x $client_file
    cat >"/etc/systemd/system/${service_name}" <<-EOF
[Unit]
Description=Serverstat-Rust Client
After=network.target

[Service]
User=root
Group=root
Environment="RUST_BACKTRACE=1"
WorkingDirectory=${working_dir}
ExecStart=$client_file $params
ExecReload=/bin/kill -HUP 
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ${service_name}
systemctl restart ${service_name}
}



function get_client() {
    install_tool
    rm -f ServerStatus-${arch}-unknown-linux-musl.zip stat_*
    cd /tmp || exit

    wget --no-check-certificate -q "${MIRROR}https://github.com/zdz/Serverstatus-Rust/releases/latest/download/client-${arch}-unknown-linux-musl.zip"
    unzip -o client-${arch}-unknown-linux-musl.zip

    # 验证文件是否成功解压
    if [ $? -eq 0 ]; then
        echo "文件下载和解压成功！"
    else
        echo "文件下载或解压失败！"
        exit 1
    fi
}

value_a=""
value_g=""
value_p=""
value_t="KVM"
value_u=""
value_l=""
value_w=""
value_n=1
add_n=0
add_w=0

while getopts "a:g:p:t:u:l:w:n:" opt; do
  case $opt in
    a)
      value_a="$OPTARG/report"
      # echo "a:${value_a}" >&2
      ;;
    g)
      value_g=$OPTARG
      # echo "g:${value_g}" >&2
      ;;
    p)
      value_p=$OPTARG
      # echo "p:${value_p}" >&2
      ;;
    t)
      value_t=$OPTARG
      # echo "t:${value_t}" >&2
      ;;
    u)
      value_u="$OPTARG"
      # echo "u:${value_u}" >&2
      ;;
    l)
      value_l=$OPTARG
      # echo "l:${value_l}" >&2
      ;;
    w)
      value_w=$OPTARG
      add_w=1
      # echo "w:${value_w}" >&2
      ;;
    n)
      value_n=$OPTARG
      # echo "n:${value_n}" >&2
      add_n=1
      ;;
    \?)
      echo "无效的选项: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [[ -z $value_a || -z $value_g || -z $value_p || -z $value_t || -z $value_u || -z $value_l ]]; then
  echo "缺少必填参数，请提供 -a、-g、-p -t -u -l 参数的值。" >&2
  exit 1
fi


params=" -a $value_a -g $value_g -p $value_p -t $value_t --user $value_u --location $value_l"

if [[ $add_n -eq 1 ]]; then
  params+=" -n --vnstat-mr ${value_n}"
fi
if [[ $add_w -eq 1 ]]; then
  params+=" -w ${value_w}"
fi


check_arch
check_release
install_tool
get_client
install_client
