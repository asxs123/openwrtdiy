opkg update
if [ $? -ne 0 ]; then
    echo "更新软件源列表错误，请检查路由器自身网络连接以及是否有失效的软件源。"
    exit 1
fi
opkg install depends/*.ipk
opkg install luci-app-openclash_0.46.003-beta_all.ipk || exit 1
mv clash clash_meta clash_tun /etc/openclash/core/
/etc/init.d/network restart
