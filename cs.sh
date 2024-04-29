#!/bin/bash
proxy_github=""
third_party_source="https://op.dllkids.xyz/packages/"
setup_base_init() {
	##设置时区
	uci set system.@system[0].zonename='Asia/Shanghai'
	uci set system.@system[0].timezone='CST-8'
	uci commit system
	/etc/init.d/system reload

	## 设置防火墙wan 打开
	uci set firewall.@zone[1].input='ACCEPT'
	uci commit firewall

	##设置Argon 紫色主题 并且 设置第三方软件源
	setup_software_source 1
	opkg update
	opkg install luci-app-argon-config
	uci set luci.main.mediaurlbase='/luci-static/argon'
	uci set luci.main.lang='zh_cn'
	uci commit
}

## 去除签名
remove_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	sed -i '/option check_signature/d' "$opkg_conf"
}

## 添加签名
add_check_signature_option() {
	local opkg_conf="/etc/opkg.conf"
	echo "option check_signature 1" >>"$opkg_conf"
}

# 判断系统是否为iStoreOS
is_iStoreOS() {
	# 提取DISTRIB_ID的值，去掉单引号并赋给变量
	DISTRIB_ID=$(cat /etc/openwrt_release | grep "DISTRIB_ID" | cut -d "'" -f 2)

	# 检查DISTRIB_ID的值是否等于'iStoreOS'
	if [ "$DISTRIB_ID" = "iStoreOS" ]; then
		return 0 # true
	else
		return 1 # false
	fi
}

#设置第三方软件源
setup_software_source() {
	## 传入0和1 分别代表原始和第三方软件源
	if [ "$1" -eq 0 ]; then
		echo "# add your custom package feeds here" >/etc/opkg/customfeeds.conf
		##如果是iStoreOS系统,还原软件源之后，要添加签名
		if is_iStoreOS; then
			add_check_signature_option
		else
			echo
		fi
		# 还原软件源之后更新
		opkg update
	elif [ "$1" -eq 1 ]; then
		#传入1 代表设置第三方软件源 先要删掉签名
		remove_check_signature_option
		# 检查是否是x86_64路由器
		if is_x86_64_router; then
			echo "src/gz customfeed ${third_party_source}x86_64" >>/etc/opkg/customfeeds.conf
		else
			echo "src/gz customfeed ${third_party_source}aarch64_cortex-a53" >>/etc/opkg/customfeeds.conf
		fi
		# 设置第三方源后要更新
		opkg update
	else
		echo "Invalid option. Please provide 0 or 1."
	fi
}

## 安装应用商店
install_istore() {
	## 安装iStore 参考 https://github.com/linkease/istore
	opkg update
	ISTORE_REPO=https://istore.linkease.com/repo/all/store
	FCURL="curl --fail --show-error"

	curl -V >/dev/null 2>&1 || {
		echo "prereq: install curl"
		opkg info curl | grep -Fqm1 curl || opkg update
		opkg install curl
	}

	IPK=$($FCURL "$ISTORE_REPO/Packages.gz" | zcat | grep -m1 '^Filename: luci-app-store.*\.ipk$' | sed -n -e 's/^Filename: \(.\+\)$/\1/p')

	[ -n "$IPK" ] || exit 1

	$FCURL "$ISTORE_REPO/$IPK" | tar -xzO ./data.tar.gz | tar -xzO ./bin/is-opkg >/tmp/is-opkg

	[ -s "/tmp/is-opkg" ] || exit 1

	chmod 755 /tmp/is-opkg
	/tmp/is-opkg update
	# /tmp/is-opkg install taskd
	/tmp/is-opkg opkg install --force-reinstall luci-lib-taskd luci-lib-xterm
	/tmp/is-opkg opkg install --force-reinstall luci-app-store || exit $?
	[ -s "/etc/init.d/tasks" ] || /tmp/is-opkg opkg install --force-reinstall taskd
	[ -s "/usr/lib/lua/luci/cbi.lua" ] || /tmp/is-opkg opkg install luci-compat >/dev/null 2>&1
}

setup_cpu_fans() {
	##Modify the starting cpu temperature for fan work
	cd /tmp
	sed -i 's/76/48/g' /etc/config/glfan
}

##判断软路由架构
check_architecture() {
	local arch=$(uname -m)
	echo
	if [ "$arch" = "x86_64" ]; then
		echo "你使用的是x86_64的软路由,本程序会自动帮你安装x86_64版本的插件"
		echo
	else
		echo "你使用的是arm软路由,本程序会自动帮你安装arm版本的插件"
		echo
	fi
	echo

}

is_x86_64_router() {
	arch=$(uname -m)
	if [ "$arch" = "x86_64" ]; then
		return 0
	else
		return 1
	fi
}
# 安装run app
install_run_apps() {
	cd /tmp
	arm_base_url=$proxy_github"https://raw.githubusercontent.com/AUK9527/Are-u-ok/main/apps/all/"
	x86_base_url=$proxy_github"https://github.com/AUK9527/Are-u-ok/raw/main/x86/all/"

	x86apps=("OpenClash_0.46.001+x86_64_core.run" "PassWall_4.73-3_x86_64_all_sdk_22.03.6.run" "SSR-Plus_188-3_x86_64_all_sdk_22.03.6.run" "PassWall2_1.25-5_x86_64_all_sdk_22.03.6.run" "VSSR_x86.run" "ByPass_x86.run")
	armapps=("OpenClash_0.46.001+aarch_64_core.run" "PassWall_4.73-3_aarch64_a53_all_sdk_22.03.6.run" "SSR-Plus_188-3_aarch64_a53_all_sdk_22.03.6.run" "PassWall2_1.25-5_aarch64_a53_all_sdk_22.03.6.run" "VSSR_a53.run" "ByPass_a53.run")

	if is_x86_64_router; then
		base_url=$x86_base_url
		base_apps=("${x86apps[@]}") # 使用双引号和 @ 符号来复制数组
	else
		base_url=$arm_base_url
		base_apps=("${armapps[@]}") # 使用双引号和 @ 符号来复制数组
	fi

	if [ $# -eq 1 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
		num_to_install=$1 # 传入的参数是一个数字，表示要安装的数量,3就是从数组里取前三个 6表示从数组里取6个
		for ((i = 0; i < num_to_install; i++)); do
			run="${base_apps[i]}"
			wget -O "$run" "$base_url$run"
			sh "$run"
		done
	elif [ $# -eq 2 ] && [[ "$1" =~ ^[0-9]+$ ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
		index_to_execute=$2 # 传入的参数是两个数字，第二个数字表示要执行的数组索引，此时第一个数字随便写,因为只取第二个数字 比如1 0
		if [ "$index_to_execute" -ge 0 ] && [ "$index_to_execute" -lt ${#base_apps[@]} ]; then
			run="${base_apps[index_to_execute]}"
			wget -O "$run" "$base_url$run"
			sh "$run"
		else
			echo "索引超出范围"
		fi
	else
		echo "请提供正确的参数：一个数字（安装数量）或两个数字（第一个数字不作数，第二个数字代表数组下标）"
	fi
}

## 升级clash core版本
upgrade_clash_core() {
	echo -e "***********update Clash Core *************************"
	dev_base_url=$proxy_github"https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/"
	meta_base_url=$proxy_github"https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/"

	if is_x86_64_router; then
		dev_filename_x86="clash-linux-amd64.tar.gz"
		tun_filename_x86="clash-linux-amd64-.gz"
		meta_filename_x86=$dev_filename_x86
		## 下载x86 Dev 内核
		wget -O clashdev.tar.gz $dev_base_url$dev_filename_x86
		## 下载x86 Tun内核
		wget -O clashtun.gz $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/x86/tun.gz"
		## 下载x86 meta内核
		wget -O clashmeta.tar.gz $meta_base_url$meta_filename_x86
	else
		dev_filename_arm="clash-linux-arm64.tar.gz"
		meta_filename_arm=$dev_filename_arm
		## 下载ARM Dev arm 内核
		wget -O clashdev.tar.gz $dev_base_url$dev_filename_arm
		## 下载ARM Tun arm 内核
		wget -O clashtun.gz $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/arm64/tun.gz"
		## 下载ARM meta arm内核
		wget -O clashmeta.tar.gz $meta_base_url$meta_filename_arm
	fi
	# 解压 clashdev.tar.gz 到 /etc/openclash/core/clash 目录
	tar -xzvf /tmp/clashdev.tar.gz -C /etc/openclash/core/
	#解压 clashtun.gz 文件到 /etc/openclash/core/ 目录，并设置可执行权限
	gzip -d -c /tmp/clashtun.gz >/etc/openclash/core/clash_tun && chmod +x /etc/openclash/core/clash_tun
	#解压 meta内核 文件到 /etc/openclash/core/meta/
	mkdir -p /etc/openclash/core/meta/
	tar -xzvf /tmp/clashmeta.tar.gz -C /etc/openclash/core/meta/
	mv /etc/openclash/core/meta/clash /etc/openclash/core/clash_meta
	rm -rf /etc/openclash/core/meta/
}

## 升级openclash客户端版本
upgrade_openclash() {
	echo -e "\n\n*********** update Openclash client ***********\n"
	setup_software_source 1
	opkg install luci-app-openclash
	setup_software_source 0
}

# 添加主机名映射(解决安卓原生TV首次连不上wifi的问题)
add_dhcp_domain() {
	local domain_name="$1"
	local domain_ip="$2"

	# 检查是否存在相同的域名记录
	existing_records=$(uci show dhcp | grep "dhcp.@domain\[[0-9]\+\].name='$domain_name'")
	if [ -z "$existing_records" ]; then
		# 添加新的域名记录
		uci add dhcp domain
		uci set "dhcp.@domain[-1].name=$domain_name"
		uci set "dhcp.@domain[-1].ip=$domain_ip"
		uci commit dhcp
		echo
		echo "已添加新的域名记录"
	else
		echo "相同的域名记录已存在，无需重复添加"
	fi
	echo -e "\n"
	echo -e "time.android.com    203.107.6.88 "
}

# 添加emotn域名
add_emotn_domain() {
	echo -e "\n\n"
	# 检查 passwall 的代理域名文件是否存在
	if [ -f "/usr/share/passwall/rules/proxy_host" ]; then
		sed -i "s/keeflys.com//g" "/usr/share/passwall/rules/proxy_host"
		echo -n "keeflys.com" | tee -a /usr/share/passwall/rules/proxy_host
		echo "已添加到passwall代理域名"
	else
		echo "添加失败! 请确保 passwall 已安装"
	fi

	# 检查 SSRP 的黑名单文件是否存在
	if [ -f "/etc/ssrplus/black.list" ]; then
		sed -i "s/keeflys.com//g" "/etc/ssrplus/black.list"
		echo -n "keeflys.com" | tee -a /etc/ssrplus/black.list
		echo "已添加到SSRP强制域名代理"
	else
		echo "添加失败! 请确保 SSRP 已安装"
	fi

	echo -e "\n\n"
}

#装机必备
requiredInstallation() {
	echo -e "\n\n"
	echo -e "**************安装关机等必备插件**********************************"
	echo -e "\n"
	is-opkg do_self_upgrade
	is-opkg install 'app-meta-poweroff'
	is-opkg install 'app-meta-ddnsto'
	is-opkg install 'app-meta-systools'
	is-opkg install 'app-meta-autotimeset'
}

#添加作者信息
add_author_info() {
	cd /tmp
	uci set system.@system[0].description='wukongdaily'
	uci set system.@system[0].notes='项目出处:
    https://github.com/wukongdaily/allinonescript'
	uci commit system
}

## 一键脚本
run_all_in_one_script() {
	## 先判断是否为x86_64,再判断num_scripts
	num_scripts=$1
	if is_x86_64_router; then
		if [ "$num_scripts" -eq 3 ]; then
			wget -qO /tmp/OPS.run $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/x86/OPS.run" && chmod +x /tmp/OPS.run && /tmp/OPS.run
		else
			wget -qO /tmp/OPSPVB.run $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/x86/OPSPVB.run" && chmod +x /tmp/OPSPVB.run && /tmp/OPSPVB.run
		fi
	else
		if [ "$num_scripts" -eq 3 ]; then
			wget -qO /tmp/OPS.run $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/arm64/OPS.run" && chmod +x /tmp/OPS.run && /tmp/OPS.run
		else
			wget -qO /tmp/OPSPVB.run $proxy_github"https://raw.githubusercontent.com/wukongdaily/allinonescript/main/arm64/OPSPVB.run" && chmod +x /tmp/OPSPVB.run && /tmp/OPSPVB.run
		fi
	fi
}

##获取软路由型号信息
get_router_name() {
	if is_x86_64_router; then
		model_name=$(grep "model name" /proc/cpuinfo | head -n 1 | awk -F: '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
		echo "$model_name"
	else
		model_info=$(cat /tmp/sysinfo/model)
		echo "$model_info"
	fi
}

jump_shell_clash() {
	export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &>/dev/null
}

while true; do
	clear
	add_author_info
	echo "***********************************************************************"
	echo "*      一键安装工具箱(for iStoreOS) v1.1 20231112        "
	echo "*      目前只是配了iStoreOS系统(其他版本的OpenWrt均无测试)        "
	echo "*      自动识别CPU架构: x86_64/Arm 均可使用         "
	echo "*      Developed by @wukongdaily        "
	echo "**********************************************************************"
	echo
	echo "*      当前的软路由型号: $(get_router_name)"
	echo
	echo "**********************************************************************"
	echo
	echo " 1. 一键安装三大插件"
	echo " 2. 一键安装六大插件"
	echo " 3. 单独安装OC"
	echo " 4. 单独安装PW"
	echo " 5. 单独安装S+"
	echo " 6. 单独安装PW2"
	echo " 7. 单独安装HW"
	echo " 8. 单独安装BP"
	echo " 9. 添加主机名映射(解决安卓原生TV首次连不上wifi的问题)"
	echo "10. 添加Emotn Store域名(解决打开emotn弹框问题)"
	echo "11. 安装关机等必备插件"
	echo "12. 查询软路由架构"
	echo "13. 跳转到Shell_C"
	echo " R. 重启设备"
	echo " P. 关机"
	echo " Q. 退出本程序"
	echo
	read -p "请选择一个选项: " choice

	case $choice in
	1)
		install_run_apps 3
		upgrade_clash_core
		upgrade_openclash
		;;
	2)
		install_run_apps 6
		upgrade_clash_core
		upgrade_openclash
		;;
	3)
		install_run_apps 1 0
		upgrade_clash_core
		upgrade_openclash
		;;
	4)
		install_run_apps 1 1
		;;
	5)
		install_run_apps 1 2
		;;
	6)
		install_run_apps 1 3
		;;
	7)
		install_run_apps 1 4
		;;
	8)
		install_run_apps 1 5
		;;
	9)
		echo "添加主机名映射(解决安卓原生TV首次连不上wifi的问题)"
		# 调用函数来添加域名记录
		add_dhcp_domain time.android.com 203.107.6.88
		;;
	10)
		echo "添加Emotn Store域名(解决打开emotn弹框问题)"
		add_emotn_domain
		;;
	11)
		echo "安装关机等装机必备插件"
		## 装机必备插件
		requiredInstallation
		;;
	12)
		echo "查询软路由架构"
		## 查询软路由架构
		check_architecture
		;;
	13)
		jump_shell_clash
		;;
	r | R)
		echo "正在重启设备..."
		reboot
		;;
	p | P)
		echo "正在关闭路由器..."
		poweroff
		;;

	q | Q)
		echo "退出"
		exit 0
		;;
	*)
		echo "无效选项，请重新选择。"
		;;
	esac

	read -p "按 Enter 键继续..."
done
