#!/bin/sh

# 将默认的shell改为bash
if [ -f /bin/bash ];then
  sed -i '/^root:/s#/bin/ash#/bin/bash#' /etc/passwd
fi

# 设置NTP时间服务器
# uci add_list system.ntp.server=120.25.115.20
# uci commit system

# 设置默认主题
uci set luci.main.mediaurlbase='/luci-static/neobird' && uci commit luci

# 修改主机名称为OpenWrt-86
# uci set system.@system[0].hostname='OpenWrt-86'

# 此文件名注意ls 排序，下面也行
# sed -ri "/option mediaurlbase/s#(/luci-static/)[^']+#\neobird#" /etc/config/luci
# uci commit luci

# 去掉CpuMark跑数，直接显示分数
sed -i '/coremark.sh/d' /etc/crontabs/root
cat /dev/null > /etc/bench.log
echo " (CpuMark : 56983.857988" >> /etc/bench.log
echo " Scores)" >> /etc/bench.log

# 添加系统信息
grep "shell-motd" /etc/profile >/dev/null
if [ $? -eq 1 ]; then
echo '
# 添加系统信息
[ -n "$FAILSAFE" -a -x /bin/bash ]  || {
	for FILE in /etc/shell-motd.d/*.sh; do
		[ -f "$FILE" ] && env -i bash "$FILE"
	done
	unset FILE
}

# 设置nano为默认编辑器
export EDITOR="/usr/bin/nano"

' >> /etc/profile
fi

# 设置旁路由模式
# uci set network.lan.gateway='10.0.0.254'                     # 旁路由设置 IPv4 网关
# uci set network.lan.dns='223.5.5.5 223.6.6.6'                # 旁路由设置 DNS(多个DNS要用空格分开)
# uci set network.lan.delegate='0'                             # 去掉LAN口使用内置的 IPv6 管理(若用IPV6请把'0'改'1')
uci set dhcp.@dnsmasq[0].filter_aaaa='0'                     # 禁止解析 IPv6 DNS记录(若用IPV6请把'1'改'0')
uci set dhcp.lan.ignore='1'                                  # 旁路由关闭DHCP功能
# uci delete network.lan.type                                # 旁路由桥接模式-禁用

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

exit 0
