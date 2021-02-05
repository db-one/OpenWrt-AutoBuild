
#!/bin/bash

# 安装额外依赖软件包
# sudo -E apt-get -y install rename

# 更新feeds文件
sed -i 's#src-git luci https://github.com/Lienol/openwrt-luci.git;17.01#src-git luci https://github.com/Lienol/openwrt-luci.git;18.06#g' feeds.conf.default #更换luci版本
cat feeds.conf.default

# 添加第三方软件包
git clone https://github.com/db-one/dbone-packages.git -b 19.07 package/dbone-packages

# 更新并安装源
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 为19.07添加libcap-bin依赖
rm -rf feeds/packages/libs/libcap
svn co https://github.com/openwrt/packages/trunk/libs/libcap feeds/packages/libs/libcap

# 自定义定制选项
sed -i 's#192.168.1.1#10.0.0.1#g' package/base-files/files/bin/config_generate #定制默认IP
sed -i 's#max-width:200px#max-width:1000px#g' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index.htm #修改首页样式
sed -i 's#max-width:200px#max-width:1000px#g' feeds/luci/modules/luci-mod-admin-full/luasrc/view/admin_status/index_x86.htm #修改X86首页样式
sed -i 's#option commit_interval 24h#option commit_interval 10m#g' feeds/packages/net/nlbwmon/files/nlbwmon.config #修改流量统计写入为10分钟
sed -i 's#option database_directory /var/lib/nlbwmon#option database_directory /etc/config/nlbwmon_data#g' feeds/packages/net/nlbwmon/files/nlbwmon.config #修改流量统计数据存放默认位置
sed -i 's@interval: 5@interval: 1@g' package/lean/luci-app-wrtbwmon/htdocs/luci-static/wrtbwmon.js #wrtbwmon默认刷新时间更改为1秒
sed -i 's@%D %V, %C@%D %V, %C Lienol_x86_64@g' package/base-files/files/etc/banner #自定义banner显示

# 创建自定义配置文件 - Lienol_x86_64

cd build/Lienol_x86_64
touch ./.config

#
# ========================固件定制部分========================
# 

# 
# 如果不对本区块做出任何编辑, 则生成默认配置固件. 
# 

# 以下为定制化固件选项和说明:
#

#
# 有些插件/选项是默认开启的, 如果想要关闭, 请参照以下示例进行编写:
# 
#          =========================================
#         |  # 取消编译VMware镜像:                    |
#         |  cat >> .config <<EOF                   |
#         |  # CONFIG_VMDK_IMAGES is not set        |
#         |  EOF                                    |
#          =========================================
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
CONFIG_TARGET_ROOTFS_PARTSIZE=160
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
CONFIG_PACKAGE_ipv6helper=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
EOF

# 编译VMware镜像以及镜像填充
cat >> .config <<EOF
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

# 第三方插件选择:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-oaf=y #应用过滤
# CONFIG_PACKAGE_luci-app-openclash=y #OpenClash客户端
# CONFIG_PACKAGE_luci-app-serverchan=y #微信推送
CONFIG_PACKAGE_luci-app-eqos=y #IP限速
CONFIG_PACKAGE_luci-app-poweroff=y #关机（增加关机功能）
CONFIG_PACKAGE_luci-theme-edge=y #edge主题
EOF

# ShadowsocksR插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-ssr-plus=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_ShadowsocksR_Socks=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_Kcptun=y
CONFIG_PACKAGE_luci-app-ssr-plus_INCLUDE_V2ray=y
EOF

# Passwall插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ipt2socks=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ChinaDNS_NG=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_v2ray-plugin=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_simple-obfs=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_Plus=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_GO=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Brook=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_kcptun=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_haproxy=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_dns2socks=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_pdnsd=y
CONFIG_PACKAGE_shadowsocks-libev-config=y
CONFIG_PACKAGE_shadowsocks-libev-ss-local=y
CONFIG_PACKAGE_shadowsocks-libev-ss-redir=y
CONFIG_PACKAGE_shadowsocksr-libev-alt=y
CONFIG_PACKAGE_shadowsocksr-libev-ssr-local=y
CONFIG_PACKAGE_https-dns-proxy=y
CONFIG_PACKAGE_kcptun-client=y
CONFIG_PACKAGE_chinadns-ng=y
CONFIG_PACKAGE_haproxy=y
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_v2ray-plugin=y
CONFIG_PACKAGE_simple-obfs=y
CONFIG_PACKAGE_trojan-plus=y
CONFIG_PACKAGE_trojan-go=y
CONFIG_PACKAGE_brook=y
CONFIG_PACKAGE_ssocks=y
CONFIG_PACKAGE_naiveproxy=y
CONFIG_PACKAGE_ipt2socks=y
CONFIG_PACKAGE_pdnsd-alt=y
CONFIG_PACKAGE_dns2socks=y
EOF

# 常用LuCI插件:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-app-adbyby-plus=y #adbyby去广告
CONFIG_PACKAGE_luci-app-webadmin=y #Web管理页面设置
CONFIG_PACKAGE_luci-app-filetransfer=y #系统-文件传输
CONFIG_PACKAGE_luci-app-autoreboot=y #定时重启
CONFIG_PACKAGE_luci-app-frpc=y #Frp内网穿透
CONFIG_PACKAGE_luci-app-upnp=y #通用即插即用UPnP(端口自动转发)
CONFIG_DEFAULT_luci-app-vlmcsd=y #KMS激活服务器
CONFIG_PACKAGE_luci-app-ddns=y #DDNS服务
CONFIG_PACKAGE_luci-app-wol=y #网络唤醒
CONFIG_PACKAGE_luci-app-control-mia=y #时间控制
CONFIG_PACKAGE_luci-app-control-timewol=y #定时唤醒
CONFIG_PACKAGE_luci-app-control-webrestriction=y #访问限制
CONFIG_PACKAGE_luci-app-control-weburl=y #网址过滤
CONFIG_PACKAGE_luci-app-nlbwmon=y #宽带流量监控
CONFIG_PACKAGE_luci-app-wrtbwmon=y #实时流量监测
CONFIG_PACKAGE_luci-app-sfe=y #高通开源的 Shortcut FE 转发加速引擎
# CONFIG_PACKAGE_luci-app-smartdns is not set #smartdns服务器
# CONFIG_PACKAGE_luci-app-diskman is not set #磁盘管理磁盘信息
# CONFIG_PACKAGE_luci-app-adguardhome is not set #ADguardHome去广告服务
# CONFIG_PACKAGE_luci-app-unblockmusic is not set #解锁网易云灰色歌曲
# CONFIG_PACKAGE_luci-app-xlnetacc is not set #迅雷快鸟
# CONFIG_PACKAGE_luci-app-usb-printer is not set #USB打印机
# CONFIG_PACKAGE_luci-app-mwan3helper is not set #多拨负载均衡
# CONFIG_PACKAGE_luci-app-mwan3 is not set #多线多拨
# CONFIG_PACKAGE_luci-app-hd-idle is not set #磁盘休眠
# CONFIG_PACKAGE_luci-app-zerotier is not set #Zerotier内网穿透
# CONFIG_PACKAGE_luci-app-sqm is not set #SQM智能队列管理
#
# passwall相关(禁用):
#
#
# VPN相关插件(禁用):
#
# CONFIG_PACKAGE_luci-app-ipsec-vpnserver-manyusers is not set #ipsec VPN服务
# CONFIG_PACKAGE_luci-app-pppoe-relay is not set #PPPoE穿透
# CONFIG_PACKAGE_luci-app-pppoe-server is not set #PPPoE服务器
# CONFIG_PACKAGE_luci-app-pptp-vpnserver-manyusers is not set #PPTP VPN 服务器
# CONFIG_PACKAGE_luci-app-trojan-server is not set #Trojan服务器
# CONFIG_PACKAGE_luci-app-v2ray-server is not set #V2ray服务器
# CONFIG_PACKAGE_luci-app-brook-server is not set #brook服务端
# CONFIG_PACKAGE_luci-app-ssr-libev-server is not set #ssr-libev服务端
# CONFIG_PACKAGE_luci-app-ssr-python-pro-server is not set #ssr-python服务端
# CONFIG_PACKAGE_luci-app-kcptun is not set #Kcptun客户端
# CONFIG_PACKAGE_luci-app-softethervpn is not set #SoftEtherVPN服务器
#
# 文件共享相关(禁用):
#
# CONFIG_PACKAGE_luci-app-aria2 is not set #Aria2离线下载
# CONFIG_PACKAGE_luci-app-minidlna is not set #miniDLNA服务
# CONFIG_PACKAGE_luci-app-kodexplorer is not set #可到私有云
# CONFIG_PACKAGE_luci-app-filebrowser is not set #File Browser私有云
# CONFIG_PACKAGE_luci-app-fileassistant is not set #文件助手
# CONFIG_PACKAGE_luci-app-vsftpd is not set #FTP 服务器
# CONFIG_PACKAGE_luci-app-samba is not set #网络共享
# CONFIG_PACKAGE_autosamba is not set #网络共享
# CONFIG_PACKAGE_samba36-server is not set #网络共享
EOF

# LuCI主题:
cat >> .config <<EOF
CONFIG_PACKAGE_luci-theme-argon-dark-mod=y
CONFIG_PACKAGE_luci-theme-argon-light-mod=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
# CONFIG_PACKAGE_luci-theme-bootstrap-mod is not set
# CONFIG_PACKAGE_luci-theme-darkmatter is not set
# CONFIG_PACKAGE_luci-theme-freifunk-generic is not set
# CONFIG_PACKAGE_luci-theme-material is not set
# CONFIG_PACKAGE_luci-theme-openwrt is not set
EOF

# 常用软件包:
cat >> .config <<EOF
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano=y
# CONFIG_PACKAGE_screen=y
# CONFIG_PACKAGE_tree=y
# CONFIG_PACKAGE_vim-fuller=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_node=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_libcap=y
CONFIG_PACKAGE_libcap-bin=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_iptables-mod-extra=y
EOF

# 其他软件包:
cat >> .config <<EOF
CONFIG_HAS_FPU=y
EOF


# 
# ========================固件定制部分结束========================
# 

sed -i 's/^[ \t]*//g' ./.config

# 返回工作目录
cd ../..

# 配置文件创建完成

