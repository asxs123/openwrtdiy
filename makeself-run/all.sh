#!/bin/bash

opkg update
if [ $? -ne 0 ]; then
    echo "更新软件源列表错误，请检查路由器自身网络连接以及是否有失效的软件源。"
    exit 1
fi
opkg install openclash/depends/*.ipk
opkg install openclash/luci-app-openclash_0.46.003-beta_all.ipk || exit 1
/etc/init.d/network restart

opkg install passwall2/depends/*.ipk
opkg install passwall2/luci-app-passwall2_1.28-4_all.ipk passwall2/luci-i18n-passwall2-zh-cn_git-24.079.57320-3ba865f_all.ipk