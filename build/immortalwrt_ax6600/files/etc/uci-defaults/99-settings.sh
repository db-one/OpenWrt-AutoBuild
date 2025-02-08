
#!/bin/bash

# 软件源设置
cat << EOF > "/etc/opkg/distfeeds.conf"
src/gz openwrt_base https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/base/
src/gz openwrt_luci https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/luci/
src/gz openwrt_packages https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/packages
src/gz openwrt_routing https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/routing
src/gz openwrt_telephony https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/packages/aarch64_cortex-a53/telephony
EOF

# 指示灯定义
cat >> "/etc/config/system" << 'EOF'
config led
	option name 'LAN'
	option sysfs 'green:status'
	option trigger 'netdev'
	option dev 'br-lan'
	list mode 'tx'
	list mode 'rx'

config led
	option name 'Red load'
	option sysfs 'red:status'
	option trigger 'heartbeat'

config led
	option sysfs 'blue:status'
	option trigger 'none'
	option name 'Blue Off'
	option default '0'
EOF

# ================ WIFI设置 =======================================

# 删除默认WIFI脚本
rm -f /etc/uci-defaults/990_set-wireless.sh

# 检查初始配置文件
if ! grep -q "option ssid 'ImmortalWrt'" /etc/config/wireless; then
    echo "检测到 /etc/config/wireless 文件不包含 ImmortalWrt 的 SSID，跳过配置"
    exit 0
fi

# 配置SSID信息
configure_wifi() {
    local radio=$1
    local channel=$2
    local htmode=$3
    local txpower=$4
    local ssid=$5
    local key=$6
    local encryption=$7

    # 无需设置 band，系统自动推断
    uci -q batch <<EOC
set wireless.radio${radio}.channel="${channel}"
set wireless.radio${radio}.htmode="${htmode}"
set wireless.radio${radio}.mu_beamformer='1'
set wireless.radio${radio}.country='US'
set wireless.radio${radio}.txpower="${txpower}"
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.disabled='0'

set wireless.default_radio${radio}.ssid="${ssid}"
set wireless.default_radio${radio}.encryption="${encryption}"
set wireless.default_radio${radio}.key="${key}"
set wireless.default_radio${radio}.time_advertisement='2'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.wnm_sleep_mode='1'
set wireless.default_radio${radio}.wnm_sleep_mode_no_keys='1'
EOC

    # 特殊加密设置
    if [ "$encryption" = "sae-mixed" ]; then
        uci set wireless.default_radio${radio}.ocv='0'
        uci set wireless.default_radio${radio}.disassoc_low_ack='0'
    fi
}

# 配置无线接口
#            接口顺序    信道     HT频宽      功率      SSID               密码            加密方式
configure_wifi 0      149     'HE80'      22     'JDC_Guest'       '123456789'     'sae-mixed'
configure_wifi 1      6       'HE40'      22     'MX-SmartHome'    '123456789'     'psk2+ccmp'
configure_wifi 2      48      'HE160'     23     'AX6600_5G'       '123456789'     'sae-mixed'

# 添加 radio1 的第二个接口
uci set wireless.wifinet3=wifi-iface
uci set wireless.wifinet3.device='radio1'
uci set wireless.wifinet3.mode='ap'
uci set wireless.wifinet3.network='lan'
uci set wireless.wifinet3.ssid='AX6600'
uci set wireless.wifinet3.encryption='psk2+ccmp'
uci set wireless.wifinet3.key='123456789'
uci set wireless.wifinet3.time_advertisement='2'
uci set wireless.wifinet3.time_zone='CST-8'
uci set wireless.wifinet3.wnm_sleep_mode='1'
uci set wireless.wifinet3.wnm_sleep_mode_no_keys='1'
uci set wireless.wifinet3.disassoc_low_ack='0'

# 提交并重启
uci commit wireless
wifi

# =======================================================



