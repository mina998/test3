<?php

class Auth{

    public function __construct(){

        if(session_status() < 2){
            session_start();
        }
        if( empty($_SESSION['login']) ){
            $this->redirect_to();
            exit();
        }
    }

    private function redirect_to(){
        if( substr($_SERVER['REQUEST_URI'], 0, 4) == '/php' ){
            $url = '../login/';
        }else{
            $url = './login/';
        }
        header('Location: ' . $url);
    }
}
new Auth();
