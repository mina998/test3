#!/bin/bash

#### 站点备份 本地版

#网站根路径 后缀不加/
web_root=/www/v2.hq4.net
#网站运行目录
run_path=wordpress
#备份文件保存路径 后缀不加/
backup=~/backup
#网站权限用户
user='nobody'
#用户所属组
group='nogroup'

#数据库名
db_name='d5b8623e1fb'
#数据库账号
db_user='u114c03bc4e24'
#数据库密码
db_pass='u114c03bc4e24'

#数据备份
db_back=db.sql
#备份网站保存名称
web_save_name=$(date +%Y-%m-%d.%H%M%S).web.tar.gz
#备份记录文件
description='.description'

# 输出红颜色
echoR(){
	echo -e "\033[38;5;203m$1\033[39m"
}
# 输出绿颜色
echoG(){
    echo -e "\033[38;5;71m$1\033[39m"
}
# 输出黄颜色
echoY(){
    echo -e "\033[38;5;148m$1\033[39m"
}
# 输出错误信息
_error(){
    echoR $1
    exit 0
}
#检测数据库是否存在
isDBExist(){
    #判断数据库是否存在
    if [ -z `mysql -u$db_user -p$db_pass -Nse "show DATABASES like '$db_name'"` ] ; then
       _error "数据库不存在"
    fi
}
# 删除数据库所有表
dropDBTables(){
    isDBExist
    conn="mysql -D$db_name -u$db_user -p$db_pass -s -e"
    drop=$($conn "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '${db_name}'")
    $($conn "SET foreign_key_checks = 0; ${drop}")
}
# 显示备份信息
view_backup_info(){
    echo -e "\033[32m"
    cat $backup/$description
    echo -e "\033[0m"
}
# 备份数据
backup(){
    # 判断本地备份目录，不存在则创建
    if [ ! -d $backup ] ; then
        mkdir -p $backup
    fi
    # 判断网站是否存在
    if [ ! -d $web_root/$run_path ] ; then
        echoR "站点文件不存在"
    fi
    # 切换工作目录
    cd $web_root/$run_path
    # 导出MySQL数据库
    mysqldump -u$db_user -p$db_pass $db_name > $db_back
    # 测数据库是否导出成功
    ! test -e $db_back && _error '备份数据库失败' 
    # 切换目录
    cd $backup
    # 打包本地网站数据,这里用--exclude排除文件及无用的目录
    tar -C $web_root/$run_path -zcf $web_save_name ./
    # 测数网站是否备份成功
    ! test -e $web_save_name && _error '网站备份失败'
    # 删除
    rm $web_root/$run_path/$db_back
    # 查看备份
    echo -e "\033[32m"
    ls -lrthgG
    echo -e "\033[0m"
    # 
    read -p "请输入本次备份描述: " backup_description
    # 该处 -z "$backup_description"  必须用双引号
    if [ -z "$backup_description" ]; then
        echo "${web_save_name} : [is null]" >> $backup/$description
    else
        echo "${web_save_name} : [${backup_description}]" >> $backup/$description
    fi
}
# 恢复数据
huifu(){
    cd $backup
    # 查看备份说明 # ls -lrthgG
    view_backup_info
    # 接收用户输入
    read -p "请输入要还原的文件名:" site
    # 检查文件是否存在
    ! test -e $site && _error '文件不存在'
    # 判断临时目录
    if [ -d temp ] ; then
        rm -rf temp
    fi
    # 创建临时目录
    mkdir temp
    # 解压备份文件
    tar -zxf $site -C ./temp
    #
    cd temp
    # 判断数据库文件是否存在
    ! test -e $db_back && _error '找不到SQL文件'
    # 删除数据库中的所有表
    dropDBTables
    # 导入备份数据
    mysql -u$db_user -p$db_pass $db_name < $backup/temp/$db_back
    # 删除SQL
    rm $db_back
    # 删除网站文件
    rm -rf $web_root/$run_path/*
    # 还原备份文件
    mv ./* $web_root/$run_path/
    # 删除临时目录
    cd .. && rm -rf temp
    # 还原指定伪静态文件
    if [ -a .htaccess ] ; then
        cp .htaccess $web_root/$run_path/
    fi
    # 切换工作目录
    cd $web_root
    # 修改所有者
    chown -R $user:$group $run_path/
    # 修改目录权限
    find $run_path/ -type d -exec chmod 750 {} \;
    # 修改文件权限
    find $run_path/ -type f -exec chmod 640 {} \;
}
#删除备份文件
delete_backup_file(){
    cd $backup
    # 查看备份
    view_backup_info
    #
    read -p "请输入要删除的完整文件名: " backup_file_name
    # 该处 -z "$backup_file_name"  必须用双引号
    if [ -n "$backup_file_name" ]; then
        ! test -e $backup_file_name && _error '备份文件不存在'
        rm $backup_file_name
    fi
    # 
    ! test -e $description && _error '备份描述文件不存在'
    #删除文件所在行
    sed -i -r "/^$backup_file_name/d" $description
}
#
menu(){
    echoG "备份(1)  还原(2) 查看备份(3) 删除指定备份(4) 清空所有备份(5)"
    read -p "请选择:" num
    if [ $num -eq 1 ]; then
        backup
    elif [ $num -eq 2 ]; then
        huifu
    elif [ $num -eq 3 ]; then
        view_backup_info
    elif [ $num -eq 4 ]; then
        delete_backup_file
    elif [ $num -eq 5 ]; then
        echo '' > $backup/$description
        rm $backup/*.web.tar.gz
    else
        echoR "输入有误."
    fi
}
menu