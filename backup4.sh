#!/bin/bash
#################################
##   站点备份 GITHUB版
##   下载TAG打包文件 			
##   使用Bandizip软件 解压
##   重新打包为.tgz格式
##   重命名为.tar.gz格式
#################################
# 开启失败日志记录 *
logv=0
# GITHUB仓库地址   *
repo=https://github.com/username/repo.git
# GITHUB用户名 *
user=mina998
# GITHUB TOKEN *
token=6wlfahiL3dq62Efdhv
# 虚拟主机总根
vhost_root=/www
# 站点文档目录
doc_folder=public_html
# 数据库SQL文件名
db_back=db.sql
# 日志文件
log_file=/root/.backup_to_repo.log
# 远程分支
branch=main
# 工作路径
work_path=/root/.backup_to_repo
# 输出颜色信息
function echoCC {
    echo -e "\033[38;5;208m$1\033[0m"
}
# 以root身份运行
[ $(id -u) -gt 0 ] && echoCC "请以root身份运行." && exit 0
# 站点列表
site_list=$@
if [ -z "$site_list" ]; then
    echoCC "[$(date +'%Y-%m-%d %H:%M:%S')] 虚拟主机名称不能为空."
    exit 0
fi
# 检测git是否安装
if [ ! -e /usr/bin/git ]; then
    apt install git -y
fi
# 检测zip是否安装
if [ ! -e /usr/bin/7z ]; then
    apt install p7zip-full -y
fi
# 配置git用户
git config --global user.email "$user@qq.com"
git config --global user.name "$user"
# 错误信息
error_info=(
    local _date="[$(date +'%Y-%m-%d %H:%M:%S')]:"
    [0]="${_date}备份完成"
    [1]="${_date}站点文档目录不存在"
    [2]="${_date}数据库信息文件不存在"
    [3]="${_date}数据库名称不能为空"
    [4]="${_date}数据库用户不能为空"
    [5]="${_date}数据库密码不能为空"
    [6]="${_date}数据库不存在"
)
# 打包备份网站内容
function site_backup {
    #错误代码
    error_code=0
    #设置变量
    local site_name=$1
    #站点文档目录不存在
    local web_doc_root=$vhost_root/$site_name/$doc_folder
    [ ! -d $web_doc_root ] && error_code=1 && return $?
    #数据库信息文件不存在
    local db_info_file=$vhost_root/$site_name/backup/admin
    [ ! -f $db_info_file ] && error_code=2 && return $?
    #数据库名称不能为空
    local db_name=$(grep 'DB Name' $db_info_file | cut -d : -f 2 | sed 's/ //')
    [ -z "$db_name" ] && error_code=3 && return $?
    #数据库用户不能为空
    local db_user=$(grep 'DB User' $db_info_file | cut -d : -f 2 | sed 's/ //')
    [ -z "$db_user" ] && error_code=4 && return $?
    #数据库密码不能为空
    local db_pass=$(grep 'DB Pass' $db_info_file | cut -d : -f 2 | sed 's/ //')
    [ -z "$db_pass" ] && error_code=5 && return $?
    #数据库不存在
    if [ -z $(mysql -u$db_user -p$db_pass -Nse "show DATABASES like '$db_name'") ]; then
        error_code=6 && return $?
    fi
    #导出MySQL数据库
    mysqldump -u$db_user -p$db_pass $db_name > $web_doc_root/$db_back
    #分卷打包压缩
    tr -dc 'a-z' < /dev/urandom | head -c 100 > $web_doc_root/test.version
    # zip -9qs 45m -r web.zip $web_doc_root
    7z a web.7z $web_doc_root -v46m -bd
}
# 上传函数
function pash_tag {
    #循环上发布
    for item in $site_list; do
        local tag="v.$(date +'%Y.%m%d.%H%M%S')"
        site_backup "$item"
        if [ $error_code -gt 0 ]; then
            [ $logv -eq 0 ] && echoCC "[$item] - ${error_info[$error_code]}"
            [ $logv -eq 1 ] && echo "[$item] - ${error_info[$error_code]}" >> $log_file
            continue
        fi
        git add -A
        git commit -am "update 1"
        git tag -a $tag -m "$item $tag"
        git push origin $tag
        echo "+ [$tag]($(echo $repo | sed 's/\.git//')/releases/tag/$tag) : $item" >> ../README.md
        rm -rf *
    done
    #备份失败退出脚本
    [ $error_code -gt 0 ] && exit 0
}
# 创建日志文件
[ -f $log_file ] || echo /dev/null > $log_file
if [ $? -gt 0 ]; then
    echoCC "创建日志文件失败,请手动指定."
    exit 0
fi 
# 创建工作路径
[ -d $work_path ] && rm -rf $work_path; mkdir -p $work_path && cd $work_path
# 生成私密仓库可访问地址
repo_address=$(echo $repo | sed "s/github.com/$user:$token@&/")
# 克隆仓库
git clone --depth=1 -b $branch $repo_address $work_path/temp
#
if [ ! -d $work_path/temp ]; then
    echoCC "克隆仓库失败" && exit 0
fi
# 切换工作路径
cd $work_path/temp
# 设置为安全路径
git config --global --add safe.directory ./
# 移出README文件
sed -i '/^#.*/d' README.md
mv README.md ../
# 发布tag版本
pash_tag
# 
mv ../README.md . 
# 清空分支内容重新提交
git checkout --orphan latest_branch
git add -A
git commit -am "update2" > /dev/null 2>&1
git branch -D $branch
git branch -m $branch
git push -f origin $branch
