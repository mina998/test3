#!/bin/bash
#####################################################
####               备份到阿里网盘                 ####
####       bash /root/backup3.sh demo.com        ####            
#####################################################
# 阿里云盘用户登陆令牌
refresh_token=6924ba0095c34b819cdc3f5ef7e26043
# 数据库root密码
mysql_root_password=hpesdagmvhoh
##################################################
# 虚拟主机总根
vhost_root=/www
# 站点文档目录
doc_folder=public_html
# 数据库SQL文件名
db_back=db.sql
# 阿里网盘客户端安装位置
aliyunpan_dir=/root/alipan
# 日志文件
aliyunpan_log=$aliyunpan_dir/error.log
# 导出数据库文件
function export_db_sql {
	#0=无错 1=数据库名字不能为空 2=数据库不存在 3=导出数据库失败
	db_sql_err=0; local db_name=$1
	#数据库名字为空
	[ -z "$1" ] && db_sql_err=1 && return $?
    #检测数据库是否存在
    if [ -z $(mysql -uroot -p$mysql_root_password -Nse "show DATABASES like '$db_name'") ]; then
    	db_sql_err=2
    	return $?
    fi
    #导出MySQL数据库
    mysqldump -uroot -p$mysql_root_password $db_name > $db_back
    #测数据库是否导出成功
    [ ! -f $db_back ] && db_sql_err=3
}
# 打包备份网站内容
function site_backup {
	#设置变量
	local site_name=$1
	local i=0; local error_msg=()
	local web_doc_root=$vhost_root/$site_name/$doc_folder
	local db_name=$(grep 'DB Name' $vhost_root/$site_name/backup/admin | cut -d : -f 2 | sed 's/ //')
	local temp=$aliyunpan_dir/temp
	[ -d $temp ] && rm -rf $temp
	#切换工作目录
	mkdir $temp && cd $web_doc_root
	#
	while [ $i -lt 3 ]; do
		let i++
		#删除已有数据库备份
		[ -f $db_back ] && rm $db_back
	    #导出数据库SQL文件
    	export_db_sql "$db_name"
    	#如果失败重来
    	[ $db_sql_err -gt 0 ] && continue
	    #备份网站保存名称
    	local web_save_name="${site_name}_$(date +'%Y%m%d%H%M%S').tar.gz"
	    #打包本地网站数据,这里用--exclude排除文件及无用的目录
    	tar -zcf $temp/$web_save_name -C $web_doc_root ./
	    #测数网站是否备份成功
	    [ ! -f $temp/$web_save_name ] && continue
        #打包压缩完成删除数据库文件
    	rm -f $db_back
    	return $?
	done
	error_msg[1]="数据库名字不能为空";
	error_msg[2]="数据库不存在";
	error_msg[3]="导出数据库失败";
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] [打包压缩文件失败]: $error_msg[$db_sql_err]" >> $aliyunpan_log
}

# 上传函数
function upload_file_pan {
	[ ! -d $aliyunpan_dir/temp ] && mkdir $aliyunpan_dir/temp
	for item in $site_list; do
		if [ ! -d $vhost_root/$item ]; then
			echo "[$(date +'%Y-%m-%d %H:%M:%S')][站点不存在]: $item" >> $aliyunpan_log
			continue
		fi
		site_backup "$item"
	done
	cd $aliyunpan_dir
	[ -z "$(ls temp)" ] && exit 0 
	./aliyunpan upload --timeout 38 --ow --norapid ./temp/ /
	rm -rf ./temp/{.[!.],}*
}
# 阿里网盘登陆函数,如果三次登陆失败退出脚本
function login_aliyun {
	local i=0
	if (./aliyunpan who | grep '当前帐号UID' >/dev/null); then
		return $?
	else
		while [ $i -lt 3 ]; do
			let i++; sleep 2s
			(./aliyunpan login --RefreshToken=$refresh_token | grep '登录成功') && return $?
		done
	fi
	echo "[$(date +'%Y-%m-%d %H:%M:%S')][登陆失败]:$refresh_token" >> $aliyunpan_log
	exit 0
}
# 安装阿里网盘函数
function install_aliyunpan {
	wget https://github.com/tickstep/aliyunpan/releases/download/v0.2.2/aliyunpan-v0.2.2-linux-amd64.zip
	unzip aliyunpan-v0.2.2-linux-amd64.zip && mv aliyunpan-v0.2.2-linux-amd64 alipan
	rm -f aliyunpan-*.zip
}
cd ~
# 检测是否需要安装
[ ! -f $aliyunpan_dir/aliyunpan ] && install_aliyunpan
# 站点列表
site_list=$@
if [ -z "$site_list" ]; then
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] 站点参数不能为空" > $aliyunpan_log
	exit 0
fi
# 更新网盘客户端版本
cd $aliyunpan_dir && ./aliyunpan update -y
# 登陆阿里网盘
login_aliyun
# 上传备份文件到网盘
upload_file_pan
# 退出登陆
# ./aliyunpan logout -y
