#!/bin/bash

#进入工作目录
cd $HOME

# 移除对uhttpd的依赖
sed -i '/luci-light/d' feeds/luci/collections/luci/Makefile
echo 设置 Nginx 默认配置
nginx_config_path="feeds/packages/net/nginx-util/files/nginx.config"
echo 使用 cat 和 heredoc 覆盖写入 nginx.config 文件
cat > "$nginx_config_path" <<'EOF'
config main 'global'
        option uci_enable 'true'

config server '_lan'
        list listen '443 ssl default_server'
        list listen '[::]:443 ssl default_server'
        option server_name '_lan'
        list include 'restrict_locally'
        list include 'conf.d/*.locations'
        option uci_manage_ssl 'self-signed'
        option ssl_certificate '/etc/nginx/conf.d/_lan.crt'
        option ssl_certificate_key '/etc/nginx/conf.d/_lan.key'
        option ssl_session_cache 'shared:SSL:32k'
        option ssl_session_timeout '64m'
        option access_log 'off; # logd openwrt'

config server 'http_only'
        list listen '80'
        list listen '[::]:80'
        option server_name 'http_only'
        list include 'conf.d/*.locations'
        option access_log 'off; # logd openwrt'
EOF

echo 优化Nginx配置
nginx_template="feeds/packages/net/nginx-util/files/uci.conf.template"
if [ -f "$nginx_template" ]; then
  if ! grep -q "client_body_in_file_only clean;" "$nginx_template"; then
    sed -i "/client_max_body_size 128M;/a\\
        client_body_in_file_only clean;\\
        client_body_temp_path /mnt/tmp;" "$nginx_template"
  fi
fi

echo 对ubus接口安全和性能优化 
luci_support_script="feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support"
if [ -f "$luci_support_script" ]; then
  if ! grep -q "client_body_in_file_only off;" "$luci_support_script"; then
    sed -i '/ubus_parallel_req 2;/a\
        client_body_in_file_only off;\
        client_max_body_size 1M;' "$luci_support_script"

  fi
fi

echo 删除证书定时更新计划任务
sed -i 's|install_cron_job(CRON_C.*);|// &|' feeds/packages/net/nginx-util/src/nginx-ssl-util.hpp
sed -i 's/remove_cron_job(CRON_CHECK);/// &/' feeds/packages/net/nginx-util/src/nginx-ssl-util.hpp

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
  # 返回工作目录
  cd $HOME
fi

# 写入 proxy-server-nameserver 参数
sed -i '/ruby_edit "$CONFIG_FILE" "\[.dns.\]\[.proxy-server-nameserver.\]"/a\    ruby_edit "$CONFIG_FILE" "['\''dns'\''\]['\''proxy-server-nameserver'\'']" "['\''https://doh.pub/dns-query'\'','\''https://dns.alidns.com/dns-query'\'','\''https://223.5.5.5:443/dns-query'\'','\''https://dns.cloudflare.com/dns-query'\'','\''https://dns.google/dns-query'\'']"' package/dbone-packages/luci-app-openclash/root/etc/openclash/custom/openclash_custom_overwrite.sh

# 写入自定义规则
cat >> package/dbone-packages/luci-app-openclash/root/etc/openclash/custom/openclash_custom_rules.list <<EOF


##########################################################################################
##########################################################################################


##域名黑名单/强制走代理的域名/代理列表
##- DOMAIN-SUFFIX,google.com,Proxy #匹配域名后缀(交由Proxy代理服务器组)
# ==========自定义规则==========
- DOMAIN-SUFFIX,api.telegram.org,🚀 节点选择
- DOMAIN-SUFFIX,rizonesoft.com,🚀 节点选择
- DOMAIN-SUFFIX,cordcloud.one,🚀 节点选择
- DOMAIN-SUFFIX,namecheap.com,🚀 节点选择
- DOMAIN-SUFFIX,555dianying.cc,🚀 节点选择
- DOMAIN-SUFFIX,apkpure.com,🚀 节点选择
- DOMAIN-SUFFIX,time.android.com,🚀 节点选择
- DOMAIN-SUFFIX,wangzi.uk,🚀 节点选择
- DOMAIN-SUFFIX,telegra.ph,🚀 节点选择

# ==========微软TTS规则==========
- DOMAIN-SUFFIX,eastus.tts.speech.microsoft.com,🚀 节点选择

# ==========微软New Bing规则==========
- DOMAIN-SUFFIX,bing.com,💬 Ai平台
- DOMAIN-SUFFIX,bingapis.com,💬 Ai平台
- DOMAIN-SUFFIX,edge.microsoft.com,💬 Ai平台
- DOMAIN-SUFFIX,copilot.microsoft.com,💬 Ai平台

# ==========TMM==========
- DOMAIN-SUFFIX,tmdb.org,🚀 节点选择
- DOMAIN-SUFFIX,themoviedb.org,🚀 节点选择

# ==========Docker规则==========
- DOMAIN-SUFFIX,gcr.io,🚀 节点选择
- DOMAIN-SUFFIX,quay.io,🚀 节点选择
- DOMAIN-SUFFIX,ghcr.io,🚀 节点选择
- DOMAIN-SUFFIX,k8s.gcr.io,🚀 节点选择
- DOMAIN-SUFFIX,docker.io,🚀 节点选择
- DOMAIN-SUFFIX,docker.com,🚀 节点选择

# ==========GitHub==========
- DOMAIN-SUFFIX,github.io,🚀 节点选择
- DOMAIN-SUFFIX,github.com,🚀 节点选择
- DOMAIN-SUFFIX,githubstatus.com,🚀 节点选择
- DOMAIN-SUFFIX,githubassets.com,🚀 节点选择
- DOMAIN-SUFFIX,github.community,🚀 节点选择
- DOMAIN-SUFFIX,github.map.fastly.net,🚀 节点选择
- DOMAIN-SUFFIX,githubusercontent.com,🚀 节点选择
- DOMAIN-SUFFIX,github-com.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github.global.ssl.fastly.net,🚀 节点选择
- DOMAIN-SUFFIX,github-cloud.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-user-asset-6210df.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-release-asset-2e65be.s3.amazonaws.com,🚀 节点选择
- DOMAIN-SUFFIX,github-production-repository-file-5c1aeb.s3.amazonaws.com,🚀 节点选择

# ==========谷歌规则==========
- DOMAIN-SUFFIX,youtube.com,📹 油管视频
- DOMAIN-SUFFIX,google.com,📹 油管视频
- DOMAIN-SUFFIX,google.com.hk,📹 油管视频
- DOMAIN-SUFFIX,hegoogle.com.sgroku,📹 油管视频
- DOMAIN-SUFFIX,google.com.tw,📹 油管视频
- DOMAIN-SUFFIX,googleapis.com,📹 油管视频
- DOMAIN-SUFFIX,googleapis.cn,📹 油管视频
- DOMAIN-SUFFIX,googletagmanager.com,📹 油管视频
- DOMAIN-SUFFIX,googleusercontent.com,📹 油管视频
- DOMAIN-SUFFIX,googlevideo.com,📹 油管视频
- DOMAIN-SUFFIX,www.google.com,📹 油管视频
- DOMAIN-SUFFIX,translate.google.com,📹 油管视频
- DOMAIN-SUFFIX,voice.google.com,📹 油管视频

## ==========游戏规则==========
- DOMAIN-SUFFIX,epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,ol.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,store.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,www.epicgames.com,🎮 游戏平台
- DOMAIN-SUFFIX,steamcontent.com,🎮 游戏平台
- DOMAIN-SUFFIX,dl.steam.clngaa.com,🎮 游戏平台
- DOMAIN-SUFFIX,dl.steam.ksyna.com,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.bscstorage.net,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.eccdnx.com,🎮 游戏平台
- DOMAIN-SUFFIX,st.dl.pinyuncloud.com,🎮 游戏平台
- DOMAIN-SUFFIX,test.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,media.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.cloudflare.steamstatic.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.akamai.steamstatic.com,🎮 游戏平台
- DOMAIN-SUFFIX,steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,store.steampowered.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn.mileweb.cs.steampowered.com.8686c.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-ws.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-qc.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,cdn-ali.content.steamchina.com,🎮 游戏平台
- DOMAIN-SUFFIX,epicgames-download1-1251447533.file.myqcloud.com,🎮 游戏平台

##域名白名单/不走代理的域名/直连列表
##- DOMAIN-SUFFIX,alipay.com,DIRECT #匹配域名后缀(直连)
##- DOMAIN-KEYWORD,google,DIRECT #匹配域名关键字(直连)
- DOMAIN-KEYWORD,alipay,DIRECT
- DOMAIN-KEYWORD,taobao,DIRECT
- DOMAIN-KEYWORD,aliexpress,DIRECT
- DOMAIN-KEYWORD,pinduoduo,DIRECT
- DOMAIN-KEYWORD,speedtest,DIRECT
- DOMAIN-KEYWORD,mxnas,DIRECT

#域名解析
- DOMAIN-SUFFIX,api.cloudflare.com,🚀 节点选择
##IP获取
- DOMAIN-SUFFIX,ip.cip.cc,DIRECT
- DOMAIN-SUFFIX,ip.3322.net,DIRECT
- DOMAIN-SUFFIX,myip.ipip.net,DIRECT
##https://api.ip.sb/ip
- DOMAIN-SUFFIX,api.ip.sb,DIRECT
##https://api-ipv4.ip.sb/ip
- DOMAIN-SUFFIX,api-ipv4.ip.sb,DIRECT
##http://members.3322.org/dyndns/getip
- DOMAIN-SUFFIX,members.3322.org,DIRECT
##icanhazip.com
- DOMAIN-SUFFIX,icanhazip.com,DIRECT
##cip.cc
- DOMAIN-SUFFIX,cip.cc,DIRECT


## DNS
- DOMAIN-SUFFIX,cloudflare-dns.com,🚀 节点选择
- DOMAIN-SUFFIX,dns.google,🚀 节点选择
- DOMAIN-SUFFIX,dns.adguard.com,🚀 节点选择
- DOMAIN-SUFFIX,doh.opendns.com,🚀 节点选择

##IP白名单/不走代理的IP/直连列表
##- IP-CIDR,127.0.0.0/8,DIRECT #匹配数据目标IP(直连)
## VPN DDNS服务
- IP-CIDR,130.158.75.0/24,DIRECT
- IP-CIDR,130.158.6.0/24,DIRECT

##########################################################################################
##########################################################################################
EOF



