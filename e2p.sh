#!/bin/bash
#***************************************************
#脚本：E2P(Email 2 Post)
#编写：zjhou
#日期：2015-11-12
#更新：2015-11-12
#描述：解析博客管理员的邮件，自动部署，或删除，更改
#      博客系统完成博客管理更新工作。
#
#功能：1. 部署文章
#      2. 删除文章
#      3. 更改文章
#      4. 查询博博客信息
#
#备注：该脚本作为Crontab的例行脚本,将被自动调用。
#***************************************************



#***************************************************

global_vars() {
	#管理员白名单	
	global_white_list=("wintrace@outlook.com" "313721293@qq.com")		

	#临时文件存放路径，不能为空
	global_tmpbox="$HOME/tmpbox"

	#本地静态博客根目录
	global_local_blog="$HOME/local/blog"

	#本地静态博客的文本目录
	global_local_posts="$global_local_blog/source/_posts"

	#本地存放静态博客渲染成网页文件的目录
	global_local_htmls="$global_local_blog/public"

	#服务器网站文档根目录
	global_site_blog="$HOME/site/blog"
		
		
}

#如果待匹配的用户在白名单中则返回真，否则返回假
#*工具函数*
#------+------------------
# 参数 | 描述
#------+------------------
# $1   | 待匹配的用户
#------+------------------
match_white_list() {
	for user in ${global_white_list[@]}; do
		if [ "$1" == "$user" ]
		then 
			#注意！0表示匹配成功。
			return 0
		fi
	done
	return 1
}

#检查邮件发送者是否在白名单中，如果在，返回其邮件编号。为真。
#*工具函数*
#如果不在返回假。
#-----------+--------------------------
#    返回值 | 描述
#-----------+--------------------------
#     1     | 检测失败，无管理员邮件
#-----------+--------------------------
#     0     | 检测成功，有管理员邮件
#-----------+--------------------------
# $(($i+1)) | 管理员邮件的序号
#-----------+--------------------------
check_sender() {
	#通过在配置文件~/.mailrc或/etc/nail.rc中设置headline的值
	#可以控制mail -H的输出字段。
	#这里headline的值为"%m %30s %s"
	#第一个字段的值是邮件序号。
	#第二个字段的值是发件人的地址。
	#第三个字段的值是邮件主题。
	local user=(`mail -H | awk '{print $2}'`)
	local len=${#user[@]}
	for ((i = 0; i < $len; i++)); do
		match_white_list ${user[$i]} && echo $(($i+1)) && return 0
	done
	return 1
}

#提取邮件正文（纯文本）
#*工具函数*
#------+------------------
# 参数 | 描述
#------+------------------
# $1   | 邮件序号
#------+------------------

extract_mail() {
	{
		mail << EOF
		p $1
		echo " "
		echo "-end-"
		q
EOF
		#AWK根据邮件格式，提取正文内容。无附件。将其保存在$global_tmpbox/body.txt中。
		#SED删除第一行空行。
	} | awk '/Content-Type: text\/plain/, /-end-/{if(i>1) print x; x=$0; i++}'\
	  | sed '1d' \
	  > $global_tmpbox/body.txt  	

	#保存一份副本。可以提取附件，同时将邮件移出了邮箱防止重复解析。
}

#删除邮件
#*工具函数*
#------+------------------
# 参数 | 描述
#------+------------------
# $1   | 邮件序号
#------+------------------
del_mail() {
	mail << EOF
	d $1
EOF
}

#提取邮件主题（不支持空格）
#*工具函数*
#------+------------------
# 参数 | 描述
#------+------------------
# $1   | 邮件序号
#------+------------------
get_subject() {
	local subj=`mail -H | awk '{if($1 == "'$1'") print $3}'`
	echo $subj
}

#重新从markdown生成html文件
#*API函数*
update() {
	cd $global_local_blog && hexo clean --silent && hexo g --silent
}

#把邮件内容作为博文。发布到博客。
#*API函数*
add() {
	#注意！提取第一行为标题。所有邮件正文第一行不能为空。
	local title=`cat $global_tmpbox/body.txt | awk 'NR == 1 {print}'`
	echo -e "title: $title\n---\n" > $global_local_posts/$title.md

	#邮件除第一行，都将作为正文。
	cat $global_tmpbox/body.txt | awk 'NR != 1 {print}' >> $global_local_posts/$title.md

	update
	rm -r $global_site_blog/*
	cp -R $global_local_htmls/* $global_site_blog/

	echo "博文《$title》部署成功，您可以刷新网页查看。" \
	| mail -s "部署成功" ${global_white_list[0]}
}


#列出所有博文的目录
#*API函数*
list() {
	#设置ls输出的时间格式，并按时间排序，最近的在前。
	ls -lt --time-style=+"%Y/%m/%d" $global_local_posts \
	| awk 'NR!=1 {gsub(/\.md/,"",$0);printf("%10s 《%s》\n",$6, $7)}' \
	| mail -s "博文列表" ${global_white_list[0]} #将结果通过邮件回传给管理员
}
#****主函数****
#为了提高程序可读性，统一在主函数调用该脚本里其他函数
MAIN (){
	mail -e || exit

	#激活全局变量
	global_vars

	#
	email_num=`check_sender`
	[[ -z $email_num ]] && exit

	#设置编码，否则Crontab调用的时候会乱码。
	export LANG="en_US.UTF-8"


	extract_mail $email_num

	email_subj=`get_subject $email_num`

	if [ "$email_subj" == "post" ]
	then
		add
	elif [ "$email_subj" == "list" ]
	then 
		list
	fi

	del_mail $email_num
}

#***************************************************
#请勿改动此部分内容。*******************************
#如果要修改，修改MAIN()函数。***********************
MAIN #**********************************************
#***************************************************
#******************************************TEST AREA
