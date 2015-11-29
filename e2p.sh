#!/bin/bash
#***************************************************
#脚本：E2P(Email 2 Post)
#编写：zjhou
#日期：2015-11-12
#描述：解析博客管理员的邮件，自动部署，或删除，更改
#      博客系统完成博客管理更新工作。
#
#功能：1. 部署文章
#      2. 删除文章
#      3. 查询博博客信息
#      4. ..详见帮助文档..
#
#备注：该脚本作为Crontab的例行脚本,将被自动调用。
#***************************************************

include() {
	. UTIL_SYS
	. HEXO_SYS
	. MAIL_SYS
}

global_var() {
    #临时文件存放路径，不能为空
    global_tmpbox="$HOME/tmpbox"
    #支持的命令集，如果邮件主题不在命令集中，脚本将不做处理。
    global_cmd_set=("发布" "删除" "目录" "帮助")
    #管理员白名单	
    global_white_list=("wintrace@outlook.com" "313721293@qq.com"  )		
    #默认管理员
    global_default_manager="${global_white_list[0]}"
    #邮件通知开关，如果设置为off, 将不会发送邮件通知给用户
    global_mail_info="on"
    #e2p.sh的目录
    global_e2p_path="$HOME/bin/E2P/"
}

#返回管理员邮件序号。
get_manager_mailnum() {
	#通过在配置文件~/.mailrc或/etc/nail.rc中设置headline的值
	#可以控制mail -H的输出字段。
	#这里headline的值为"%m %30s %s"
	#第一个字段的值是邮件序号。
	#第二个字段的值是发件人的地址。
	#第三个字段的值是邮件主题。
	local user=(`mail -H | awk '{print $2}'`)
	local subj=(`mail -H | awk '{print $3}'`)

	local len=${#user[@]}
	for ((i = 0; i < $len; i++)); do
		is_in? ${user[$i]} ${global_white_list[@]} && \
		is_in? ${subj[$i]} ${global_cmd_set[@]} && \
		echo $(($i+1)) && return 0
	done
	return 1
}

#设置当前管理员
#-------------------------
# 参数   描述
#  $1     邮件序号
#-------------------------
set_manager() {
	global_default_manager=`mail -H | awk '{if($1 == "'$1'") print $2}'`
}


#add_helper - format text 
format() {
	sed -e '1 s/\(.*\)/title: \1/' -e '1 a ---' $1
}


#根据邮件主题调用不同的API函数
#参数  描述
# $1    邮件主题
run_cmd() {
	case "$1" in
		"发布" ) get_mail_text $2 | format | publish ;;
		"删除" ) del `get_mail_text $2` ;;
		"目录" ) list ;;
		"更新" ) refresh ;;
		#"帮助" ) doc ;;
	esac
}

#***************************************************
#*MAIN函数*
#***************************************************
#为了程序可读性，统一在主函数调用该脚本里其他函数
MAIN (){
	mail -e || exit

	global_var
	include

	email_num=`get_manager_mailnum`

	if [ -z $email_num ];then 
		exit
	fi

	subj_cmd=`get_mail_subj $email_num`

	run_cmd $subj_cmd $email_num

	del_mail $email_num
}

#***************************************************
#***************************************************
#DO NOT CHANGE ANYTHING HERE ***********************
MAIN #**********************************************
#***************************************************
#***************************************************
