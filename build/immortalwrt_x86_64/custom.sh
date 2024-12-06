
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
cat feeds.conf.default

# 添加第三方软件包
git clone https://github.com/db-one/dbone-packages.git -b 23.05 package/dbone-packages

# 更新并安装源
# ./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a -f

# 删除部分默认包
rm -rf feeds/luci/applications/luci-app-qbittorrent
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/themes/luci-theme-argon

# 自定义定制选项
NET="package/base-files/files/bin/config_generate"
ZZZ="package/emortal/default-settings/files/99-default-settings"
# 读取内核版本
KERNEL_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_PATCHVER | sed 's/^.\{17\}//g')
KERNEL_TESTING_PATCHVER=$(cat target/linux/x86/Makefile|grep KERNEL_TESTING_PATCHVER | sed 's/^.\{25\}//g')
if [[ $KERNEL_TESTING_PATCHVER > $KERNEL_PATCHVER ]]; then
  sed -i "s/$KERNEL_PATCHVER/$KERNEL_TESTING_PATCHVER/g" target/linux/x86/Makefile        # 修改内核版本为最新
  echo "内核版本已更新为 $KERNEL_TESTING_PATCHVER"
else
  echo "内核版本不需要更新"
fi

#
sed -i "s#192.168.1.1#10.0.0.1#g" $NET                                                     # 定制默认IP
# sed -i "s#ImmortalWrt#ImmortalWrt-X86#g" $NET                                          # 修改默认名称为 ImmortalWrt-X86
# sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' $ZZZ                                          # 取消系统默认密码
echo "uci set luci.main.mediaurlbase=/luci-static/argon" >> $ZZZ                      # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)
# sed -i 's#localtime  = os.date()#localtime  = os.date("%Y年%m月%d日") .. " " .. translate(os.date("%A")) .. " " .. os.date("%X")#g' package/lean/autocore/files/*/index.htm               # 修改默认时间格式

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
BUILDTIME=$(TZ=UTC-8 date "+%Y.%m.%d") && sed -i "s#%D %V %C#ONE build $BUILDTIME @ %D %V %C#g" package/base-files/files/etc/openwrt_release              # 增加自己个性名称
# sed -i "s@list listen_https@# list listen_https@g" package/network/services/uhttpd/files/uhttpd.config               # 停止监听443端口
# sed -i '/exit 0/i\ethtool -s eth0 speed 2500 duplex full' package/base-files/files//etc/rc.local               # 强制显示2500M和全双工（默认PVE下VirtIO不识别） ImmortalWrt固件内不显示端口状态，可以关闭

# ●●●●●●●●●●●●●●●●●●●●●●●●定制部分●●●●●●●●●●●●●●●●●●●●●●●● #

cat >> $ZZZ <<-EOF
# 设置旁路由模式
uci set network.lan.gateway='10.0.0.254'                     # 旁路由设置 IPv4 网关
uci set network.lan.dns='223.5.5.5 119.29.29.29'            # 旁路由设置 DNS(多个DNS要用空格分开)
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
uci delete network.lan.type                                  # 旁路由桥接模式-禁用
uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')

# 旁路IPV6需要全部禁用
uci set network.lan.ip6assign=''                             # IPV6分配长度-禁用
uci set dhcp.lan.ra=''                                       # 路由通告服务-禁用
uci set dhcp.lan.dhcpv6=''                                   # DHCPv6 服务-禁用
uci set dhcp.lan.ra_management=''                            # DHCPv6 模式-禁用

# 如果有用IPV6的话,可以使用以下命令创建IPV6客户端(LAN口)（去掉全部代码uci前面#号生效）
uci set network.ipv6=interface
uci set network.ipv6.proto='dhcpv6'
uci set network.ipv6.ifname='@lan'
uci set network.ipv6.reqaddress='try'
uci set network.ipv6.reqprefix='auto'
uci set firewall.@zone[0].network='lan ipv6'

EOF

# 修改退出命令到最后
sed -i '/exit 0/d' $ZZZ && echo "exit 0" >> $ZZZ

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #
# 下载 OpenClash 内核
grep "CONFIG_PACKAGE_luci-app-openclash=y" $WORKPATH/$CUSTOM_SH >/dev/null
if [ $? -eq 0 ]; then
  echo "正在执行：为OpenClash下载内核"
  mkdir -p $HOME/clash-core
  mkdir -p $HOME/files/etc/openclash/core
  cd $HOME/clash-core

# 下载Meta内核
  wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  if [[ $? -ne 0 ]];then
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz
  else
    echo "OpenClash Meta内核压缩包下载成功，开始解压文件"
  fi
  tar -zxvf clash-linux-amd64.tar.gz
  if [[ -f "$HOME/clash-core/clash" ]]; then
    mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash_meta
    chmod +x $HOME/files/etc/openclash/core/clash_meta
    echo "OpenClash Meta内核配置成功"
  else
    echo "OpenClash Meta内核配置失败"
  fi
  rm -rf $HOME/clash-core/clash-linux-amd64.tar.gz

  rm -rf $HOME/clash-core
fi

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #


# 创建自定义配置文件

cd $WORKPATH
touch ./.config

#
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分●●●●●●●●●●●●●●●●●●●●●●●●
# 

# 
# 如果不对本区块做出任何编辑, 则生成默认配置固件. 
# 

# 以下为定制化固件选项和说明:
#

#
# 有些插件/选项是默认开启的, 如果想要关闭, 请参照以下示例进行编写:
# 
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#        ■|  # 取消编译VMware镜像:                    |■
#        ■|  cat >> .config <<EOF                   |■
#        ■|  # CONFIG_VMDK_IMAGES is not set        |■
#        ■|  EOF                                    |■
#          ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
#

# 
# 以下是一些提前准备好的一些插件选项.
# 直接取消注释相应代码块即可应用. 不要取消注释代码块上的汉字说明.
# 如果不需要代码块里的某一项配置, 只需要删除相应行.
#
# 如果需要其他插件, 请按照示例自行添加.
# 注意, 只需添加依赖链顶端的包. 如果你需要插件 A, 同时 A 依赖 B, 即只需要添加 A.
# 
# 无论你想要对固件进行怎样的定制, 都需要且只需要修改 EOF 回环内的内容.
# 

# 编译x64固件:
cat >> .config <<EOF
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_Generic=y
EOF

# 设置固件大小:
cat >> .config <<EOF
CONFIG_TARGET_KERNEL_PARTSIZE=16
CONFIG_TARGET_ROOTFS_PARTSIZE=360
EOF

# 固件压缩:
cat >> .config <<EOF
CONFIG_TARGET_IMAGES_GZIP=y
EOF

# 编译UEFI固件:
cat >> .config <<EOF
CONFIG_EFI_IMAGES=y
EOF

# IPv6支持:
cat >> .config <<EOF
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ipv6helper=y
EOF

# 编译PVE/KVM、Hyper-V、VMware镜像以及镜像填充
cat >> .config <<EOF
CONFIG_QCOW2_IMAGES=y
CONFIG_VHDX_IMAGES=y
CONFIG_VMDK_IMAGES=y
CONFIG_TARGET_IMAGES_PAD=y
EOF

# 多文件系统支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-fs-nfs=y
# CONFIG_PACKAGE_kmod-fs-nfs-common=y
# CONFIG_PACKAGE_kmod-fs-nfs-v3=y
# CONFIG_PACKAGE_kmod-fs-nfs-v4=y
# CONFIG_PACKAGE_kmod-fs-ntfs=y
# CONFIG_PACKAGE_kmod-fs-squashfs=y
# EOF

# USB3.0支持:
# cat >> .config <<EOF
# CONFIG_PACKAGE_kmod-usb-ohci=y
# CONFIG_PACKAGE_kmod-usb-ohci-pci=y
# CONFIG_PACKAGE_kmod-usb2=y
# CONFIG_PACKAGE_kmod-usb2-pci=y
# CONFIG_PACKAGE_kmod-usb3=y
# EOF

# 多线多拨:
# cat >> .config <<EOF
# CONFIG_PACKAGE_luci-app-syncdial=y #多拨虚拟WAN
# CONFIG_PACKAGE_luci-app-mwan3=y #MWAN负载均衡
# CONFIG_PACKAGE_luci-app-mwan3helper=n #MWAN3分流助手
# EOF

# 第三方插件选择:
cat >> .config <<EOF
# CONFIG_PACKAGE_luci-app-oaf=y #应用过滤
CONFIG_PACKAGE_luci-app-openclash=y #OpenClash客户端
# CONFIG_PACKAGE_luci-app-serverchan=y #微信推送
# CONFIG_PACKAGE_luci-app-eqos=y #IP限速
# CONFIG_PACKAGE_luci-app-control-weburl=y #网址过滤
# CONFIG_PACKAGE_luci-app-smartdns=y #smartdns服务器
# CONFIG_PACKAGE_luci-app-adguardhome=y #ADguardhome
CONFIG_PACKAGE_luci-app-poweroff=y #关机（增加关机功能）
# CONFIG_PACKAGE_luci-app-argon-config=y #argon主题设置
# CONFIG_PACKAGE_luci-app-autotimeset=y #定时重启系统，网络
# CONFIG_PACKAGE_luci-app-ddnsto=y #小宝开发的DDNS.to内网穿透
# CONFIG_PACKAGE_ddnsto=y #DDNS.to内网穿透软件包
EOF

# ShadowsocksR插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-ssr-plus=y
# CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_SagerNet_Core is not set
EOF

# Passwall插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall2=y
# CONFIG_PACKAGE_naiveproxy=y
CONFIG_PACKAGE_chinadns-ng=y
# CONFIG_PACKAGE_brook=y
CONFIG_PACKAGE_trojan-go=y
CONFIG_PACKAGE_xray-plugin=y
CONFIG_PACKAGE_shadowsocks-rust-sslocal=y
EOF

# 常用LuCI插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-accesscontrol=n #上网时间控制
CONFIG_PACKAGE_luci-app-filetransfer=y #文件传输
CONFIG_PACKAGE_luci-app-frpc=y #Frpc客户端
CONFIG_PACKAGE_luci-app-upnp=n #UPNP服务器
CONFIG_PACKAGE_luci-app-vlmcsd=n #KMS激活服务器
CONFIG_PACKAGE_luci-app-nlbwmon=n #宽带流量监控
CONFIG_PACKAGE_luci-app-wol=n #网络唤醒
#
# VPN相关插件(禁用):
#
CONFIG_PACKAGE_luci-app-v2ray-server=y #V2ray服务器
CONFIG_PACKAGE_luci-app-ipsec-vpnd=n #ipsec VPN服务
CONFIG_PACKAGE_luci-app-openvpn-server=n #openvpn服务
CONFIG_PACKAGE_luci-app-softethervpn=n #SoftEtherVPN服务器
#
# 文件共享相关(禁用):
#
CONFIG_PACKAGE_luci-app-minidlna=n #miniDLNA服务
CONFIG_PACKAGE_luci-app-vsftpd=n #FTP 服务器
CONFIG_PACKAGE_luci-app-samba=n #网络共享
CONFIG_PACKAGE_autosamba=n #网络共享
EOF

# LuCI主题:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-edge=n
EOF

# 常用软件包:
cat >> .config <<EOF
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
# CONFIG_PACKAGE_screen=y
# CONFIG_PACKAGE_tree=y
# CONFIG_PACKAGE_vim-fuller=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_snmpd=y
CONFIG_PACKAGE_libcap=y
CONFIG_PACKAGE_libcap-bin=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_iptables-mod-extra=y
CONFIG_PACKAGE_vsftpd=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_qemu-ga=y
CONFIG_PACKAGE_autocore-x86=y
EOF

# 其他软件包:
cat >> .config <<EOF
CONFIG_HAS_FPU=y
EOF


# 
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分结束●●●●●●●●●●●●●●●●●●●●●●●● #
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回目录
cd $HOME

# 配置文件创建完成
