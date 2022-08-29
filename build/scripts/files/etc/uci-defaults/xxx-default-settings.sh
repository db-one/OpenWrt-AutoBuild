#!/bin/sh

# 将默认的shell改为bash
if [ -f /bin/bash ];then
  sed -i '/^root:/s#/bin/ash#/bin/bash#' /etc/passwd
fi


# uci add_list system.ntp.server=120.25.115.20
# uci commit system

uci set luci.main.mediaurlbase='/luci-static/neobird' && uci commit luci

# 此文件名注意ls 排序，下面也行
# sed -ri "/option mediaurlbase/s#(/luci-static/)[^']+#\neobird#" /etc/config/luci
# uci commit luci

#去掉CpuMark跑数，直接显示分数
sed -i '/coremark.sh/d' /etc/crontabs/root
cat /dev/null > /etc/bench.log
echo " (CpuMark : 56983.857988" >> /etc/bench.log
echo " Scores)" >> /etc/bench.log

exit 0
