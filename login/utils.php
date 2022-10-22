<?php

/**
 * 获取系统面板用户列表
 *
 * @return array
 */
function read_user_list(){
    // 保证此文件有可读权限
    $htpasswd = '/usr/local/lsws/admin/conf/htpasswd';
    $fd = fopen($htpasswd, 'r');
    if (!$fd) return false;
    $all = trim(fread($fd, filesize($htpasswd)));
    fclose($fd);
    $lines = explode("\n", $all);
    $users = [];
    foreach ($lines as $line) {
        list($name, $password) = explode(':', $line);
        $users[$name] = $password;
    }
    return $users;
}

/**
 * 重写登陆验证方法
 * @param [type] $name
 * @param [type] $pass
 * @return void
 */
function verify_auth_user($name, $pass){
    $users = read_user_list();
    if(array_key_exists($name, $users)){
        $password = $users[$name];
        if ($password[0] != '$') {
            $salt = substr($password, 0, 2);
        } else{
            $salt = substr($password, 0, 12);
        } 
        $encypt = crypt($pass, $salt);
        if ($password == $encypt) {
            $_SESSION['login'] = $name;
            return true;
        }else{
            session_destroy();
        }
    }
    return false;
}
