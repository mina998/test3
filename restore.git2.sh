#!/bin/bash

#### 从GITHUB 还原
#### bash restore.git2.sh xxxx.com
cd ~
#网站权限用户
user=nobody
#用户所属组
group=nogroup
# 所有虚拟机保存目录
vhs_root=/www
# 分支名
branch_name=master
# 站点文档文件夹
doc_folder=public_html
# 输出颜色
echo2(){
    if [ "$2" = "G" ]; then
        color="38;5;71"     #绿色
    elif [ "$2" = "B" ]; then
        color="38;1;34"     #蓝色
    elif [ "$2" = "Y" ]; then
        color="38;5;148"    #黄色
    else
        color="38;5;203"    #红色
    fi
    echo -e "\033[${color}m${1}\033[39m"
}

# 判断站点是否存在
if [ -z "$1" ]; then
    echo2 '请输入站点参数.'
    exit 0
fi
if [ ! -d $vhs_root/$1 ]; then
    echo2 '站点不存在.'
    exit 0
fi
if [ -d temp ]; then
    echo -e "\033[32m"
    read -p "临时目录已存在! 删除[y] 其它任意字符退出.: " ny1
    echo -e "\033[0m"
    if [ "$ny1" = "y" ]; then
        rm -rf temp
    else
        exit 0
    fi
fi
# 数据库参数文件
db_conf_file=$vhs_root/$1/backup/admin
if [ ! -f $db_conf_file ]; then
    echo2 '站点数据库文件不存在.'
    exit 0
fi
# 站点文档根绝对路径 *
site_doc_root=$vhs_root/$1/$doc_folder
# 数据库名
db_name=$(grep 'DB Name' $db_conf_file | cut -d : -f 2 | sed 's/ //')
# 数据库用户
db_user=$(grep 'DB User' $db_conf_file | cut -d : -f 2 | sed 's/ //')
# 数据库密码
db_pass=$(grep 'DB Pass' $db_conf_file | cut -d : -f 2 | sed 's/ //')

#判断数据库是否存在
if [ -z `mysql -u$db_user -p$db_pass -Nse "show DATABASES like '$db_name'"` ] ; then
    echo2 "数据库不存在"
    exit 0
fi
# 接收仓库参数
while true
do
    read -p "请输入仓库地址: " repo_url
    read -p "请输入拉取ID: " commit_id
    echo2 "仓库地址: $repo_url" Y
    echo2 "拉取ID: $commit_id" Y
    read -p "确认?[y/n]: " ny2
    if [ "$ny2" = "y" -o "$ny2" = "Y" ]; then
        break
    fi
done
# 克隆仓库
git clone $repo_url -b $branch_name temp
if [ ! -d temp ]; then
    echo2 "克隆仓库失败, 请检查仓库地址是否隐身."
    exit 0
fi
# 删除当前文件
cd temp && rm -rf *
# 恢复到指定提交
git reset --hard $commit_id
# 解压SQL文件
if [ ! -f db.sql.gz ]; then
    echo2 "SOL文件不存在"
    exit 0
fi
gzip -d db.sql.gz
# 接收参数
replace_db_domain(){
    echo2 "快捷键 ^+c 取消操作" G
    while true
    do
        read -p "请输入旧域名: " old_domain
        if [ -z $old_domain ]; then
            echo2 '旧域名不能为空.'
            continue
        fi
        read -p "请输入新域名: " new_domain
        if [ -z $new_domain ]; then
            echo2 '新域名不能为空.'
            continue
        fi
        echo2 "数据库中的 $old_domain 替换为 $new_domain" Y
        read -p "确认?[y/n]: " ny4
        if [ "$ny4" = "y" -o "$ny4" = "Y" ]; then
            break
        fi
    done
    sed -i "s/www.$old_domain/$new_domain/Ig" db.sql
    sed -i "s/$old_domain/$new_domain/Ig" db.sql
    echo2 '域名替换完成' G
}
read -p "是否替换域名?[y/N]:" ny3
if [ "$ny3" = "Y" -o "$ny3" = "y" ]; then
    replace_db_domain
else
    echo2 '不进行域名替换.' G
fi

# 修改网站配置文件
replace_web_config(){
    local wp_config=wp-config.php
    if [ ! -f "$wp_config" ]; then
        return $?
    fi
    sed -i -r "s/DB_NAME',\s*'(.+)'/DB_NAME', '$db_name'/" $wp_config
    sed -i -r "s/DB_USER',\s*'(.+)'/DB_USER', '$db_user'/" $wp_config
    sed -i -r "s/DB_PASSWORD',\s*'(.+)'/DB_PASSWORD', '$db_pass'/" $wp_config
}
replace_web_config

# 删除数据库所有表
conn="mysql -D$db_name -u$db_user -p$db_pass -s -e"
drop=$($conn "SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '${db_name}'")
$($conn "SET foreign_key_checks = 0; ${drop}")
# 导入SQL文件
mysql -u$db_user -p$db_pass $db_name < ./db.sql
# 删除SQL文件
rm db.sql
# 删除网站文件
rm -rf $site_doc_root/{.[!.],}*
# 还原备份文件
mv {.[!.],}* $site_doc_root/
#
cd $site_doc_root/..
# 设置权限
chown -R $user:$group $doc_folder
find $doc_folder -type d -exec chmod 750 {} \;
find $doc_folder -type f -exec chmod 640 {} \;
# 清理
cd ~ && rm -rf temp
# 重载服务配置
service lsws reload
