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
#      3. 更改文章
#      4. 查询博博客信息
#      5. ..详见帮助文档..
#
#备注：该脚本作为Crontab的例行脚本,将被自动调用。
#***************************************************

include() {
	#引用全局配置
	. VARS_CONF
	. MAIL_MSGS

	#引用工具库
	. UTILS_LIB
}

#*工具函数*

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


#*API函数*

#重新从markdown生成html文件
update() {
	cd $global_local_blog && hexo clean --silent && hexo g --silent

	rm -r $global_site_blog/*
	cp -R $global_local_htmls/* $global_site_blog/
}

#把邮件内容作为博文。发布到博客。
# $1 邮件序号
# * 此时邮件内容必须为准备发布的博文。
# * 格式：第一行为博文的名字，不能为空行。

#add_helper - format text 
format() {
	sed -e '1 s/\(.*\)/title: \1/' -e '1 a ---' $1
}

add() {
	local title=`get_mail_text $1 | sed -n '1p'`		
	get_mail_text $1 | format > $global_local_posts/$title.md

	if has_attach? $1; then
		local imgs=(`get_mail_attachment $1 $global_local_imgs`)
		cd $global_local_posts 

		if need_render? $title.md; then
			img_tag_render $title.md $global_blog_imgs ${imgs[@]} 
		else
			img_tag_appender $title.md $global_blog_imgs ${imgs[@]} 
		fi
	fi

	update

	if is_mail_on; then
		echo "博文《$title》部署成功，您可以点击查看：http://$global_blog_url" \
		| mail -s "部署成功" $global_default_manager
	fi
}
#列出所有博文的目录
list() {
	#设置ls输出的时间格式，并按时间排序，最近的在前。
#	ls -lt --time-style=+"%Y/%m/%d" $global_local_posts \

	#注意！根据此时ls的输出，第九个字段刚好是博文名字。
	ls -lt $global_local_posts \
	| awk 'NR!=1 {gsub(/\.md/,"",$0);printf("%s\n",$9)}' \
	| mail -s "博文列表" $global_default_manager #将结果通过邮件回传给管理员
}


#删除文章引用的图片。
#注意！此函数硬编码了文章目录$global_local_posts
#以及图片目录$global_local_imgs,不具有通用性。只用作del辅助函数。
#请勿在其他地方调用！！！
#参数  描述 
#  $1 	文章标题。
del_img_ref() {
	#首先粗略判断文章是否引用了图片。
	grep "<img*" $global_local_posts/$1.md || return 0 

	#正则匹配出所有引用的图片标题。
	local imgs=(`grep -oE "[-_0-9a-zA-Zu4e00-u9fa5]+\.(jpg|png|gif)" $global_local_posts/$1.md`)

	#遍历删除图片
	for img in ${imgs[@]};do
		[[ -f $global_local_imgs/$img ]] && \
		rm "$global_local_imgs/$img"
	done
}

#批量删除博文
# * 邮件正文内容必须为准备删除的博文名字。
# * 格式必须为一行一个条目。
del() {
	#获取要删除的目标博文并初始化操作标识
	#local target=(`cat $global_tmpbox/body.txt`)
	local target=(`get_mail_text $1`)
	local error=0
	local norm=0

	#静默创建日志文件
	{ 
		echo -e "*操作日志*" > $global_tmpbox/del.log
		echo -e "_____\n成功删除的博文：" > $global_tmpbox/del_norm.log
		echo -e "_____\n无法删除的博文（请检查文件名是否正确）：" > $global_tmpbox/del_err.log
	} &> /dev/null

	#遍历博文
	for file in ${target[@]}; do
		if [ -e $global_local_posts/$file.md ]; then
			#删除引用图片。
			del_img_ref $file
			rm $global_local_posts/$file.md	
			[[ $norm -eq 0 ]] && norm=1
			echo -e "《$file》" >> $global_tmpbox/del_norm.log
		else
			[[ $error -eq 0 ]] && error=1
			echo -e "《$file》" >> $global_tmpbox/del_err.log
		fi
	done

	update

	#将日志发送给博客管理员
	[[ $norm -eq 1 ]] && \
	cat $global_tmpbox/del_norm.log >> $global_tmpbox/del.log

	[[ $error -eq 1 ]] && \
	cat $global_tmpbox/del_err.log >> $global_tmpbox/del.log

	is_mail_on && \
	cat $global_tmpbox/del.log \
	| mail -s "操作日志" $global_default_manager #将结果通过邮件回传给管理员
}

edit(){
	#获取待改动文章的标题&删除标题
	local title=`sed "1q" $global_tmpbox/body.txt`
	sed -i '1d' $global_tmpbox/body.txt

	[[ -z $title ]] && \
	echo $wrong_msg0 | mail -s "编辑失败" $global_default_manager && \
	return 1

	cd $global_local_posts 

	#检查文件是否存在
	if [ -f $title.md ]; then

		while read LINE; do
			sub $title.md $LINE
		done < $global_tmpbox/body.txt

		update && is_mail_on && echo $done_msg \
		| mail -s "编辑完成" $global_default_manager 

	else
		echo $wrong_msg | mail -s "编辑失败" $global_default_manager && \
		return 1
	fi
}

#API
#将所有博文归档后，清空博客里所有博文。
hide() {
	cd $global_local_posts 
	tar uf .posts.bkp.tar *.md && rm *.md && \
	update && \
	is_mail_on && echo -e $reset_msg \
	| mail -s "重置完成" $global_default_manager 
}

#API
#备份整个博客资源。移到备份目录下。
backup() {
	#备份整个博客
	local time_stamp=`date +"%Y-%m-%d"`

	cd $global_local_blog/source/
	tar uf blog.bkp$time_stamp.tar * && mv blog.bkp$time_stamp.tar $global_blog_bkp

	is_mail_on && echo -e "$time_stamp\n$bkp_msg" \
	| mail -s "备份完成" $global_default_manager
}

#API
#将所有博文从归档中解压，并部署到博客。
recovery() {
	cd $global_local_posts && \
	tar xf .posts.bkp.tar && \
	update && \
	is_mail_on && echo $recov_msg | mail -s "恢复完成" $global_default_manager 
}

#API
#返回帮助文档
doc() {
	echo -e "$help_msg" | mail -s "帮助文档" $global_default_manager 
}

#API
#返回博客里所有资源的大小情况。
#附带服务器空间使用情况。
res_size() {
	local local_size=`du -sh $global_local_blog | cut -f1`
	local site_size=`du -sh $global_site_blog | cut -f1`
	local server_usage=`df -h | \
	awk '/^\/dev/ {print "总共: "$2,"已用: "$3"("$5")","剩余: "$4}'`

	echo -e "HEXO系统大小：$local_size\n网页资源大小：$site_size\n服务器空间使用情况：\n$server_usage" \
	| mail -s "博客资源大小" $global_default_manager 
}


#API
#添加或删除管理员
#$1 - 添加/删除
#$2 - 添加或删除的管理员邮箱。
manager() {
	case $1 in 	
		"添加") 
			if is_in? $2 ${global_white_list[@]}; then  
				return 0
			else
				ele_append $2 $global_white_list VARS_CONF
			fi 
			;;
		"删除")
			if is_in? $2 ${global_white_list[@]}; then
				ele_del $2 $global_white_list VARS_CONF
			else
			   return 0
			fi
			;;
	esac
}

#API
#改变邮件通知状态。
#如果邮件通知开，服务器会用邮件通知用户每次操作的结果
#如果邮件通知关，则不会返回任何通知邮件。
chage_info_state() {
	#如果通知开，则关闭
	is_mail_on && set_var $global_mail_info off && return 0

	#否则打开。
	set_var $global_mail_info on
}


#根据邮件主题调用不同的API函数
#参数  描述
# $1    邮件主题
run_cmd() {
	case "$1" in
		"发布" ) add $2;;
		"删除" ) del $2;;
		"目录" ) list ;;
#		"编辑" ) edit ;;
		"隐藏" ) hide ;;
		"恢复" ) recovery ;; 
		"备份" ) backup ;;
		"更新" ) update;; #重新渲染。
		"帮助" ) doc ;;
		"通知" ) chage_info_state ;;
		"空间" ) res_size ;; #空间使用情况。
#		"人事" ) map manager $global_tmpbox/body.txt;;
	esac
}

#***************************************************
#*MAIN函数*
#***************************************************
#为了程序可读性，统一在主函数调用该脚本里其他函数
MAIN (){
	mail -e || exit

	include

	del_ad_mail blacklist 

	email_num=`get_manager_mailnum`

	if [ -z $email_num ];then 
		exit
	fi

	if is_mail_on ; then
		set_manager $email_num
	fi

	subj_cmd=`get_mail_subj $email_num`

	run_cmd $subj_cmd $email_num

	if ! is_dir_empty? $global_tmpbox; then
		rm $global_tmpbox/*
	fi
	del_mail $email_num
}

#***************************************************
#***************************************************
#DO NOT CHANGE ANYTHING HERE ***********************
MAIN #**********************************************
#***************************************************
#***************************************************
#include
