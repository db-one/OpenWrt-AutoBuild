
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
rm -rf package/dbone-packages/passwall/packages/v2ray-geoview

# 自定义定制选项
NET="package/base-files/files/bin/config_generate"
ZZZ="package/emortal/default-settings/files/99-default-settings"

#
sed -i "s#192.168.1.1#10.0.0.1#g" $NET                                                     # 定制默认IP
sed -i "s#ImmortalWrt#AX6600#g" $NET                                          # 修改默认名称为 AX6600
echo "uci set luci.main.mediaurlbase=/luci-static/argon" >> $ZZZ                      # 设置默认主题(如果编译可会自动修改默认主题的，有可能会失效)

# ●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●● #

BUILDTIME=$(TZ=UTC-8 date "+%Y.%m.%d") && sed -i "s/\(_('Firmware Version'), *\)/\1 ('ONE build $BUILDTIME @ ') + /" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js              # 增加自己个性名称

# ●●●●●●●●●●●●●●●●●●●●●●●●定制部分●●●●●●●●●●●●●●●●●●●●●●●● #

# ========================性能跑分========================

echo "rm -f /etc/uci-defaults/xxx-coremark" >> "$ZZZ"
cat >> $ZZZ <<EOF
cat /dev/null > /etc/bench.log
echo " (CpuMark : 23907.846120" >> /etc/bench.log
echo " Scores)" >> /etc/bench.log
EOF

# ================ 网络设置 =======================================

cat >> $ZZZ <<-EOF
# 设置网络-旁路由模式
uci set network.lan.gateway='10.0.0.254'                     # 旁路由设置 IPv4 网关
uci set network.lan.dns='223.5.5.5 119.29.29.29'            # 旁路由设置 DNS(多个DNS要用空格分开)
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
uci delete network.lan.type                                  # 旁路由桥接模式-禁用
uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')

# 设置防火墙-旁路由模式
uci set firewall.@defaults[0].synflood_protect='0'          # 禁用 SYN-flood 防御
uci set firewall.@defaults[0].flow_offloading='0'           # 禁用基于软件的NAT分载
uci set firewall.@defaults[0].flow_offloading_hw='0'       # 禁用基于硬件的NAT分载
uci set firewall.@defaults[0].fullcone='0'                   # 禁用 FullCone NAT
uci set firewall.@defaults[0].fullcone6='0'                  # 禁用 FullCone NAT6
uci set firewall.@zone[0].masq='1'                             # 启用LAN口 IP 动态伪装

# 旁路IPV6需要全部禁用
uci del network.lan.ip6assign                                 # IPV6分配长度-禁用
uci del dhcp.lan.ra                                             # 路由通告服务-禁用
uci del dhcp.lan.dhcpv6                                        # DHCPv6 服务-禁用
uci del dhcp.lan.ra_management                               # DHCPv6 模式-禁用

# 如果有用IPV6的话,可以使用以下命令创建IPV6客户端(LAN口)（去掉全部代码uci前面#号生效）
uci set network.ipv6=interface
uci set network.ipv6.proto='dhcpv6'
uci set network.ipv6.ifname='@lan'
uci set network.ipv6.reqaddress='try'
uci set network.ipv6.reqprefix='auto'
uci set firewall.@zone[0].network='lan ipv6'

# 配置Dropbear SSH服务
uci del dropbear.main.RootPasswordAuth
uci del dropbear.main.DirectInterface
uci set dropbear.main.enable='1'
uci set dropbear.main.Interface='lan'

uci commit dhcp
uci commit network
uci commit firewall
uci commit dropbear
/etc/init.d/dropbear restart

EOF

# =======================================================

# 检查 OpenClash 是否启用编译
if grep -qE '^(CONFIG_PACKAGE_luci-app-openclash=n|# CONFIG_PACKAGE_luci-app-openclash=)' "${WORKPATH}/$CUSTOM_SH"; then
  # OpenClash 未启用，不执行任何操作
  echo "OpenClash 未启用编译"
  echo 'rm -rf /etc/openclash' >> $ZZZ
else
  # OpenClash 已启用，执行配置
  if grep -q "CONFIG_PACKAGE_luci-app-openclash=y" "${WORKPATH}/$CUSTOM_SH"; then
    # 判断系统架构
    arch=$(uname -m)  # 获取系统架构
    case "$arch" in
      x86_64)
        arch="amd64"
        ;;
      aarch64|arm64)
        arch="arm64"
        ;;
    esac
    # OpenClash Meta 开始配置内核
    echo "正在执行：为OpenClash下载内核"
    mkdir -p $HOME/clash-core
    mkdir -p $HOME/files/etc/openclash/core
    cd $HOME/clash-core
    # 下载Meta内核
    wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$arch.tar.gz
    if [[ $? -ne 0 ]];then
      wget -q https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$arch.tar.gz
    else
      echo "OpenClash Meta内核压缩包下载成功，开始解压文件"
    fi
    tar -zxvf clash-linux-$arch.tar.gz
    if [[ -f "$HOME/clash-core/clash" ]]; then
      mv -f $HOME/clash-core/clash $HOME/files/etc/openclash/core/clash_meta
      chmod +x $HOME/files/etc/openclash/core/clash_meta
      echo "OpenClash Meta内核配置成功"
    else
      echo "OpenClash Meta内核配置失败"
    fi
    rm -rf $HOME/clash-core/clash-linux-$arch.tar.gz
    rm -rf $HOME/clash-core
  fi
fi

# =======================================================

# 修改退出命令到最后
cd $HOME && sed -i '/exit 0/d' $ZZZ && echo "exit 0" >> $ZZZ

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

# 编译 雅典娜 AX6600 固件:
cat >> .config <<EOF
# TARGET config
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y
CONFIG_TARGET_DEVICE_PACKAGES_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02="ipq-wifi-jdcloud_re-cs-02 ath11k-firmware-qcn9074 kmod-ath11k-pci luci-app-athena-led luci-i18n-athena-led-zh-cn"
CONFIG_TARGET_ROOTFS_INITRAMFS=n

# Compile
CONFIG_USE_APK=n
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_TARGET_OPTIONS=y
CONFIG_TARGET_OPTIMIZATION="-O2 -pipe -march=armv8-a+crc+crypto -mtune=cortex-a53 -mcpu=cortex-a53 -mfix-cortex-a53-835769 -mfix-cortex-a53-843419"
CONFIG_TOOLCHAINOPTS=y
CONFIG_GCC_USE_VERSION_13=y
CONFIG_GDB=n

# BUSYBOX
CONFIG_BUSYBOX_CUSTOM=y
CONFIG_BUSYBOX_CONFIG_TELNET=y

# Swap
CONFIG_PACKAGE_zram-swap=n

# NSS
CONFIG_IPQ_MEM_PROFILE_256=y
CONFIG_ATH11K_MEM_PROFILE_512M=y
CONFIG_NSS_MEM_PROFILE_HIGH=y
CONFIG_NSS_FIRMWARE_VERSION_12_2=y
CONFIG_PACKAGE_sqm-scripts-nss=y
CONFIG_PACKAGE_kmod-qca-mcs=y
CONFIG_KERNEL_SKB_RECYCLER=y
CONFIG_PACKAGE_kmod-ath11k-pci=m
CONFIG_NSS_DRV_WIFI_MESH_ENABLE=n
CONFIG_PACKAGE_MAC80211_MESH=n
CONFIG_ATH11K_NSS_MESH_SUPPORT=n

# Proto
CONFIG_PACKAGE_proto-bonding=y
CONFIG_PACKAGE_luci-proto-quectel=y
CONFIG_PACKAGE_luci-proto-wireguard=n
CONFIG_PACKAGE_luci-proto-relay=y

# Kernel modules
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_kmod-fs-ntfs3=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_kmod-tls=y
CONFIG_PACKAGE_kmod-tun=y

#  USB Support
CONFIG_PACKAGE_kmod-usb-acm=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-asix-ax88179=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
CONFIG_PACKAGE_kmod-usb-net-sierrawireless=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb2=y

#  docker kernel dependencies
CONFIG_PACKAGE_kmod-br-netfilter=y
CONFIG_PACKAGE_kmod-ip6tables=y
CONFIG_PACKAGE_kmod-ipt-conntrack=y
CONFIG_PACKAGE_kmod-ipt-extra=y
CONFIG_PACKAGE_kmod-ipt-nat=y
CONFIG_PACKAGE_kmod-ipt-nat6=y
CONFIG_PACKAGE_kmod-ipt-physdev=y
CONFIG_PACKAGE_kmod-nf-ipt6=y
CONFIG_PACKAGE_kmod-nf-ipvs=y
CONFIG_PACKAGE_kmod-nf-nat6=y
CONFIG_PACKAGE_kmod-dummy=y
CONFIG_PACKAGE_kmod-veth=y

# Libraries
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_libopenssl-legacy=y

# Package
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_snmpd=y
CONFIG_PACKAGE_fuse-utils=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_sgdisk=y
CONFIG_PACKAGE_openssl-util=y
CONFIG_PACKAGE_resize2fs=y
CONFIG_PACKAGE_qrencode=y
CONFIG_PACKAGE_smartmontools-drivedb=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_default-settings=y
CONFIG_PACKAGE_default-settings-chn=y

#  Coremark
CONFIG_PACKAGE_coremark=y
CONFIG_COREMARK_OPTIMIZE_O3=y
CONFIG_COREMARK_ENABLE_MULTITHREADING=y
CONFIG_COREMARK_NUMBER_OF_THREADS=6

#  docker dependencies
CONFIG_PACKAGE_iptables-mod-extra=y
CONFIG_PACKAGE_ip6tables-nft=y
CONFIG_PACKAGE_ip6tables-mod-fullconenat=y
CONFIG_PACKAGE_iptables-mod-fullconenat=y
CONFIG_PACKAGE_libip4tc=y
CONFIG_PACKAGE_libip6tc=y

#  mwan3 dependencies
CONFIG_PACKAGE_iptables-mod-conntrack-extra=y

# LuCI主题:
CONFIG_PACKAGE_luci-theme-argon=y

# Enable Luci App
CONFIG_PACKAGE_luci-app-adguardhome=n
CONFIG_PACKAGE_luci-app-adguardhome_INCLUDE_binary=n
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-diskman=n
CONFIG_PACKAGE_luci-app-dockerman=n
CONFIG_PACKAGE_luci-app-istorex=y
CONFIG_PACKAGE_luci-app-lucky=n
CONFIG_PACKAGE_luci-app-mosdns=n
CONFIG_PACKAGE_luci-app-samba4=n
CONFIG_PACKAGE_luci-app-smartdns=n
CONFIG_PACKAGE_luci-app-sqm=n
CONFIG_PACKAGE_luci-app-ttyd=n
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-vlmcsd=n
CONFIG_PACKAGE_luci-app-wol=n
CONFIG_PACKAGE_luci-app-zerotier=n
CONFIG_PACKAGE_luci-app-athena-led=m
CONFIG_PACKAGE_luci-i18n-athena-led-zh-cn=m
CONFIG_PACKAGE_luci-app-poweroff=y #关机（增加关机功能）
CONFIG_PACKAGE_luci-app-filetransfer=y #文件传输

# Proxy
#  OpenClash
CONFIG_PACKAGE_luci-app-openclash=n #OpenClash客户端

#  mihomo 客户端
CONFIG_PACKAGE_luci-app-nikki=n #nikki 客户端

#  HomeProxy
CONFIG_PACKAGE_luci-app-homeproxy=n

#  Passwall
CONFIG_PACKAGE_luci-app-passwall=n
# CONFIG_PACKAGE_luci-app-passwall2=n
# CONFIG_PACKAGE_naiveproxy=n
CONFIG_PACKAGE_chinadns-ng=n
# CONFIG_PACKAGE_brook=n
CONFIG_PACKAGE_trojan-go=n
CONFIG_PACKAGE_xray-plugin=n
CONFIG_PACKAGE_shadowsocks-rust-sslocal=n
EOF


# 
# ●●●●●●●●●●●●●●●●●●●●●●●●固件定制部分结束●●●●●●●●●●●●●●●●●●●●●●●● #
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回目录
cd $HOME

# 配置文件创建完成
