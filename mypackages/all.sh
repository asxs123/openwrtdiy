opkg update
if [ $? -ne 0 ]; then
    echo "更新软件源列表错误，请检查路由器自身网络连接以及是否有失效的软件源。"
    exit 1
fi
opkg install adguardhome/luci-app-adguardhome_1.8-11_all.ipk

opkg install alist/deppends/alist_3.35.0-7_x86_64.ipk
opkg install alist/luci-app-alist_1.0.13_all.ipk
opkg install alist/luci-i18n-alist-zh-cn_git-24.152.42526-e0423c5_all.ipk

opkg install ddns-go/deppends/ddns-go_6.6.0-1_x86_64.ipk
opkg install ddns-go/luci-app-ddns-go_1.4.5_all.ipk
opkg install ddns-go/luci-i18n-ddns-go-zh-cn_git-24.152.42526-e0423c5_all.ipk

opkg install openclash/luci-app-openclash_0.46.011-beta_all.ipk

opkg install passwall2/deppends/*.ipk
opkg install passwall2/luci-app-passwall2_1.29-1_all.ipk
opkg install passwall2/luci-i18n-passwall2-zh-cn_git-24.152.42526-e0423c5_all.ipk

opkg install unblockneteasemusic/luci-app-unblockneteasemusic_3.2_all.ipk
