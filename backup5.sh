#!/bin/bash
#################################
##   站点备份 GITHUB版
##   下载TAG打包文件
#################################
# 开启失败日志记录 *
logv=0
# GITHUB仓库地址   *
repo=https://github.com/username/rpeo.git
# GITHUB用户名 *
user=demo
# GITHUB TOKEN *
token=11111111111111111111111111111
# 虚拟主机总根
vhost_root=/www
# 站点文档目录
doc_folder=public_html
# 数据库SQL文件名
db_back=db.sql
# 远程分支
branch=main
# 定义工作路径
work_path=/root/.backup_to_repo_$user
# 日志文件
log_file=$work_path/error.log
# 输出颜色信息
function print_msg {
    local _date="[$(date +'%Y-%m-%d %H:%M:%S')]"
    if [ $logv -eq 1 ]; then
        #正常信息不记录日志
        [ "$2" = "normal" ] || echo "$_date $1" >> $log_file
    else
        echo -e "\033[38;5;201m${_date}\033[0m:\033[38;5;203m${1}\033[0m"
    fi
}
# 以root身份运行
[ $(id -u) -gt 0 ] && print_msg "请以root身份运行." && exit 0
# 站点列表
site_list=$@
if [ -z "$site_list" ]; then
    print_msg "[$(date +'%Y-%m-%d %H:%M:%S')] 虚拟主机名称不能为空."
    exit 0
fi
# 检测git是否安装
if [ ! -e /usr/bin/git ]; then
    apt install git -y
fi
# 检测zip是否安装
if [ ! -x /usr/bin/7z ]; then
    apt install p7zip-full -y
fi
# 配置git用户
git config --global user.email "$user@qq.com"
git config --global user.name "$user"
# 错误信息
error_info=(
    [0]="备份完成"
    [1]="站点文档目录不存在"
    [2]="数据库信息文件不存在"
    [3]="数据库名称不能为空"
    [4]="数据库用户不能为空"
    [5]="数据库密码不能为空"
    [6]="数据库不存在"
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
    echo "$2" > $web_doc_root/release.version
    # zip -9qs 45m -r web.zip $web_doc_root
    print_msg "[$site_name] 开始压缩文件" normal
    7z a web.7z $web_doc_root -v46m #-bd
    #删除
    rm -f $web_doc_root/$db_back
}
# 上传函数
function pash_tag {
    #循环上发布
    for item in $site_list; do
        local tag="v.$(date +'%Y.%m%d.%H%M%S')"
        site_backup "$item" "$tag"
        if [ $error_code -gt 0 ]; then
            print_msg "[$item] - ${error_info[$error_code]}"
            continue
        fi
        echo $item > site
        print_msg "[$item] 创建本地标签" normal
        git add -A
        git commit -am "update 1"
        git tag -a $tag -m "$item $tag"
        print_msg "[$item] 推送到仓库" normal
        git push origin $tag
        echo "+ [$tag]($(echo $repo | sed 's/\.git//')/releases/tag/$tag) : $item" >> ../README.md
        rm -rf *
    done
    #备份失败退出脚本
    [ $error_code -gt 0 ] && exit 0
}
# 创建工作路径
[ ! -d $work_path ] && mkdir -p $work_path
# 生成私密仓库可访问地址
repo_address=$(echo $repo | sed "s/github.com/$user:$token@&/")
if [ ! -d $work_path/temp ]; then
    # 克隆仓库
    git clone --depth=1 -b $branch $repo_address $work_path/temp
    #
    if [ ! -d $work_path/temp ]; then
        print_msg "克隆仓库失败" && exit 0
    fi
    # 添加自动发布文件
    wget https://raw.githubusercontent.com/mina998/wtools/scripts/release.yml -P $work_path/temp/.github/workflows -o release.yml
fi
# 切换工作路径
cd $work_path/temp
# 设置为安全路径
git config --global --add safe.directory ./
# 移出README文件
if [ -f README.md ]; then
    sed -i '/^#.*/d' README.md
    mv README.md ../
fi
# 发布tag版本
pash_tag
# 还原README
mv ../README.md . 
# 清理仓库
git checkout --orphan latest_branch
git add .
git commit -m "update2" > /dev/null 2>&1
git branch -D $branch
git branch -m $branch
git push -f origin $branch
