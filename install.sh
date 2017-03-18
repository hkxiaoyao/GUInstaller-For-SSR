#!/bin/bash

function check_os()
{
#检查系统运行环境
if [ -n "$(grep 'Aliyun Linux release' /etc/issue)" -o -e /etc/redhat-release ]; then
  OS=CentOS
  [ -n "$(grep ' 7\.' /etc/redhat-release)" ] && CentOS_RHEL_version=7
  [ -n "$(grep ' 6\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release6 15' /etc/issue)" ] && CentOS_RHEL_version=6
  [ -n "$(grep ' 5\.' /etc/redhat-release)" -o -n "$(grep 'Aliyun Linux release5' /etc/issue)" ] && CentOS_RHEL_version=5
elif [ -n "$(grep 'Amazon Linux AMI release' /etc/issue)" -o -e /etc/system-release ]; then
  OS=CentOS
  CentOS_RHEL_version=6
elif [ -n "$(grep 'bian' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Debian" ]; then
  OS=Debian
  [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
  Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
elif [ -n "$(grep 'Deepin' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Deepin" ]; then
  OS=Debian
  [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
  Debian_version=$(lsb_release -sr | awk -F. '{print $1}')
# kali rolling
elif [ -n "$(grep 'Kali GNU/Linux Rolling' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Kali" ]; then
  OS=Debian
  [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
  if [ -n "$(grep 'VERSION="2016.*"' /etc/os-release)" ]; then
    Debian_version=8
  else
    echo "${CFAILURE}Does not support this OS, Please contact the author! ${CEND}"
    kill -9 $$
  fi
elif [ -n "$(grep 'Ubuntu' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == "Ubuntu" -o -n "$(grep 'Linux Mint' /etc/issue)" ]; then
  OS=Ubuntu
  [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
  Ubuntu_version=$(lsb_release -sr | awk -F. '{print $1}')
  [ -n "$(grep 'Linux Mint 18' /etc/issue)" ] && Ubuntu_version=16
elif [ -n "$(grep 'elementary' /etc/issue)" -o "$(lsb_release -is 2>/dev/null)" == 'elementary' ]; then
  OS=Ubuntu
  [ ! -e "$(which lsb_release)" ] && { apt-get -y update; apt-get -y install lsb-release; clear; }
  Ubuntu_version=16
else
  echo "${CFAILURE}Does not support this OS, Please contact the author! ${CEND}"
  kill -9 $$
fi

if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
  OS_BIT=64
else
  OS_BIT=32
fi
}

function install_required_packages()
{
    #安装依赖包
    if [[ ${OS} == Ubuntu ]];then
	    apt-get update >/dev/null 2>&1
        echo 5
	    apt-get install python -y >/dev/null 2>&1
        echo 8
	    apt-get install python-pip -y >/dev/null 2>&1
        echo 13
	    apt-get install git -y
        echo 20
        apt-get install build-essential curl -y >/dev/null 2>&1
        echo 30
    fi
    if [[ ${OS} == CentOS ]];then
	    yum install python curl -y >/dev/null 2>&1
        echo 5
	    yum install python-setuptools -y && easy_install pip -y >/dev/null 2>&1
        echo 10
	    yum install git -y >/dev/null 2>&1
        echo 15
        yum groupinstall "Development Tools" -y >/dev/null 2>&1
        echo 30
    fi
    if [[ ${OS} == Debian ]];then
	    apt-get update >/dev/null 2>&1
        echo 5
	    apt-get install python curl -y >/dev/null 2>&1
        echo 8
	    apt-get install python-pip -y >/dev/null 2>&1
        echo 13
	    apt-get install git -y >/dev/null 2>&1
        echo 18
        apt-get install build-essential -y >/dev/null 2>&1
        echo 30
    fi
}

function install_libsodium()
{   
    #安装lisodium库
    cd $workdir
    export LIBSODIUM_VER=1.0.11
    wget -N --no-check-certificate https://github.com/jedisct1/libsodium/releases/download/1.0.11/libsodium-$LIBSODIUM_VER.tar.gz >/dev/null 2>&1
    tar xf libsodium-$LIBSODIUM_VER.tar.gz >/dev/null 2>&1
    echo 40
    pushd libsodium-$LIBSODIUM_VER
    ./configure --prefix=/usr && make >/dev/null 2>&1
    echo 45
    make install >/dev/null 2>&1
    popd
    ldconfig
    cd $workdir && rm -rf libsodium-$LIBSODIUM_VER.tar.gz libsodium-$LIBSODIUM_VER >/dev/null 2>&1
    echo 60
}

function configure_shadowsocksr()
{
    #写入ShadowsocksR配置文件
cat << EOF > /usr/local/shadowsocksr/user-config.json
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "local_address":"127.0.0.1",
    "local_port":1080,
    "port_password":{
        "${SSRPORT}":"$SSRPASSWORD"
    },
    "timeout":300,
    "method":"${SSRMETHOD}",
    "protocol": "${SSRPROTOCOL}",
    "protocol_param": "",
    "obfs": "${SSROBFS}",
    "obfs_param": "",
    "dns_ipv6": false,
    "fast_open": false,
    "workers": 1
}
EOF
#赋予ShadowsocksR的脚本执行权限
cd /usr/local/shadowsocksr/shadowsocks/
chmod +x *.sh
cd workdir
}

function setup_firewall()
{
    if [[ ${OS} =~ ^Ubuntu$|^Debian$ ]];then
        # Debian/Ubuntu开放防火墙规则
	    iptables-restore < /etc/iptables.up.rules
	    clear
	    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $SSRPORT -j ACCEPT
	    iptables -I INPUT -m state --state NEW -m udp -p udp --dport $SSRPORT -j ACCEPT
	    iptables-save > /etc/iptables.up.rules
    fi

    if [[ ${OS} == CentOS ]];then
	    if [[ $CentOS_RHEL_version == 7 ]];then
            #CentOS7先停用Firewall，启用iptables接管防火墙服务
            systemctl stop firewalld.service
            systemctl disable firewalld.service
            yum install iptables-services -y
            #写入默认iptables防火墙规则
cat << EOF > /etc/sysconfig/iptables
# sample configuration for iptables service
# you can edit this manually or use system-config-firewall
# please do not ask us to add additional ports/services to this default configuration
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
            #启动iptables防火墙服务
            systemctl restart iptables.service
            systemctl enable iptables.service
            #添加防火墙放行规则
		    iptables-restore < /etc/iptables.up.rules
		    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $SSRPORT -j ACCEPT
    	    iptables -I INPUT -m state --state NEW -m udp -p udp --dport $SSRPORT -j ACCEPT
		    iptables-save > /etc/iptables.up.rules
        else
        #此处为CentOS 6添加防火墙放行规则
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport $SSRPORT -j ACCEPT
    	iptables -I INPUT -m state --state NEW -m udp -p udp --dport $SSRPORT -j ACCEPT
		/etc/init.d/iptables save
		/etc/init.d/iptables restart
        fi
	fi
}

function install_shadowsocksr()
{
    #从GitHub拉取ShadowsocksR镜像
    cd /usr/local
    git clone https://github.com/shadowsocksr/shadowsocksr
}

function cancel_button()
{
    #判断上一个选择框的结果，如果是 ‘取消’，则终止脚本运行。
    exitstatus=$?
    if [ $exitstatus != 0 ]; then
        whiptail --title "SSR图形安装程序" --msgbox "您选择取消安装\n\n安装程序已终止！" 9 19
        exit
    fi
}

function method_choose()
{
    #处理加密方式信息
    if [[ $CHOOSEMETHOD == '1.' ]];then
	    SSRMETHOD="aes-192-cfb"
    fi
    if [[ $CHOOSEMETHOD == '2.' ]];then
    	SSRMETHOD="aes-128-cfb"
    fi
    if [[ $CHOOSEMETHOD == '3.' ]];then
	    SSRMETHOD="aes-256-cfb"
    fi
    if [[ $CHOOSEMETHOD == '4.' ]];then
    	SSRMETHOD="aes-128-ctr"
    fi
    if [[ $CHOOSEMETHOD == '5.' ]];then
	    SSRMETHOD="aes-256-ctr"
    fi
    if [[ $CHOOSEMETHOD == '6.' ]];then
	    SSRMETHOD="rc4-md5"
    fi
    if [[ $CHOOSEMETHOD == '7.' ]];then
	    SSRMETHOD="chacha20"
    fi
    if [[ $CHOOSEMETHOD == '8.' ]];then
	    SSRMETHOD="chacha20-ietf"
    fi
    if [[ $CHOOSEMETHOD == '9.' ]];then
	    SSRMETHOD="salsa20"
    fi
}

function protocol_choose()
{
    #处理协议方式信息
    if [[ $CHOOSEPROTOCOL == '1.' ]];then
	    SSRPROTOCOL="origin"
    fi
    if [[ $CHOOSEPROTOCOL == '2.' ]];then
	    SSRPROTOCOL="auth_sha1_v4"
    fi
    if [[ $CHOOSEPROTOCOL == '3.' ]];then
	    SSRPROTOCOL="auth_aes128_md5"
    fi
    if [[ $CHOOSEPROTOCOL == '4.' ]];then
	    SSRPROTOCOL="auth_aes128_sha1"
    fi
    if [[ $CHOOSEPROTOCOL == '5.' ]];then
	    SSRPROTOCOL="verify_deflate"
    fi
}

function obfs_choose()
{
    #处理混淆方式信息
    if [[ $CHOOSEOBFS == '1.' ]];then
	    SSROBFS="plain"
    fi
    if [[ $CHOOSEOBFS == '2.' ]];then
	    SSROBFS="http_simple"
    fi
    if [[ $CHOOSEOBFS == '3.' ]];then
	    SSROBFS="http_post"
    fi
    if [[ $CHOOSEOBFS == '4.' ]];then
	    SSROBFS="tls1.2_ticket_auth"
    fi
}

#################主程序从此开始####################
#获取当前工作目录
workdir=$(pwd)

#显示第一屏欢迎界面
whiptail --title "SSR图形安装程序 Author：雨落无声" --msgbox " 欢迎来到SSR图形安装程序。\n\n 使用Tab可以在界面中自由切换按钮。" 10 40

#自定义SSR端口
while :; do echo
    SSRPORT=$(whiptail --title "SSR图形安装程序" --inputbox "\n请输入SSR连接端口：" 9 26 2333 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        #此处判断输入的端口是否为有效数字
        if [[ "$SSRPORT" =~ ^(-?|\+?)[0-9]+(\.?[0-9]+)?$ ]];then
            whiptail --title "SSR图形安装程序" --msgbox "\n端口已设置为 $SSRPORT" 9 25
	        break
	    else
	        whiptail --title "SSR图形安装程序" --msgbox "\n端口号输入错误！请重试！" 9 30
	    fi
    else
        #取消安装
        whiptail --title "SSR图形安装程序" --msgbox "您选择取消安装\n\n安装程序已终止！" 9 19
        exit
    fi
done

#自定义连接密码
SSRPASSWORD=$(whiptail --title "SSR图形安装程序" --inputbox "\n请输入SSR连接密码：" 9 36 zhujiboke.com 3>&1 1>&2 2>&3)

#处理取消时候的动作
cancel_button

#自定义加密方式
CHOOSEMETHOD=$(whiptail --title "SSR图形安装程序" --menu "\n请选择加密方式：" 18 60 9 \
"1." "aes-192-cfb" \
"2." "aes-128-cfb" \
"3." "aes-256-cfb" \
"4." "aes-128-ctr" \
"5." "aes-256-ctr" \
"6." "rc4-md5" \
"7." "chacha20" \
"8." "chacha20-ietf" \
"9." "salsa20" 3>&1 1>&2 2>&3)
 
#处理取消时候的动作
cancel_button

#处理加密方式信息
method_choose

#显示加密方式
whiptail --title "SSR图形安装程序" --msgbox "\n加密方式已设置为 $SSRMETHOD" 8 35

#自定义协议方式
CHOOSEPROTOCOL=$(whiptail --title "SSR图形安装程序" --menu "\n请选择协议方式：" 14 60 5 \
"1." "origin" \
"2." "auth_sha1_v4" \
"3." "auth_aes128_md5" \
"4." "auth_aes128_sha1" \
"5." "verify_deflate" 3>&1 1>&2 2>&3)

#处理取消时候的动作
cancel_button

#处理协议方式信息
protocol_choose

#选择兼容模式
if [[ $CHOOSEPROTOCOL == '2.' ]];then
    if (whiptail --title "SSR图形安装程序" --yesno "\n是否兼容原版协议？" 8 23) then
        SSRPROTOCOL=$SSRPROTOCOL"_compatible"
    fi
fi

#显示协议方式
whiptail --title "SSR图形安装程序" --msgbox "\n协议方式已设置为 $SSRPROTOCOL" 8 45

#自定义混淆方式
CHOOSEOBFS=$(whiptail --title "SSR图形安装程序" --menu "\n请选择混淆方式：" 13 60 4 \
"1." "plain" \
"2." "http_simple" \
"3." "http_post" \
"4." "tls1.2_ticket_auth" 3>&1 1>&2 2>&3)

#处理取消时候的动作
cancel_button

#处理混淆方式信息
obfs_choose

if [[ $CHOOSEOBFS != '1.' ]];then
    if (whiptail --title "SSR图形安装程序" --yesno "\n是否兼容原版混淆？" 8 23) then
       SSROBFS=${SSROBFS}"_compatible"
    fi
fi

#显示混淆方式
whiptail --title "SSR图形安装程序" --msgbox "\n混淆方式已设置为 $SSROBFS" 8 50

{
    #检查系统运行环境
    check_os

    #安装依赖包
    install_required_packages

    #安装lisodium库
    install_libsodium

    #安装ShadowsocksR
    install_shadowsocksr >/dev/null 2>&1
    echo 75

    #配置ShadowsocksR
    configure_shadowsocksr >/dev/null 2>&1
    echo 80

    #配置防火墙规则
    setup_firewall >/dev/null 2>&1
    echo 90

    #运行ShadowsocksR
    cd /usr/local/shadowsocksr/shadowsocks/
    ./logrun.sh
    echo 100

    sleep 2
} | whiptail --gauge "正在配置，请勿关闭此窗口！" 6 60 0

#获取当前服务器IP
IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
if [[ "$IP" = "" ]]; then
    IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
fi

#安装完成，显示提示信息
whiptail --title "SSR图形安装程序" --msgbox "Shadowsocksr安装配置完成！\n服务器IP：${IP}\n端口：${SSRPORT}\n密码：${SSRPASSWORD}\n加密方式：${SSRMETHOD}\n协议：${SSRPROTOCOL}\n混淆：${SSROBFS}" 13 45
