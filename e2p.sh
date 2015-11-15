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
#*引用外部文件*
#***************************************************
. UTILS_LIB

#***************************************************
#*全局变量*
#***************************************************

global_vars() {
	#管理员白名单	
	global_white_list=("wintrace@outlook.com" "313721293@qq.com")		

	#默认管理员
	global_default_manager=${global_white_list[0]}

	#支持的命令集，如果邮件主题不在命令集中，脚本将不做处理。
	global_cmd_set=("发布" "删除" "目录")

	#临时文件存放路径，不能为空
	global_tmpbox="$HOME/tmpbox"

	#博客备份目录。
	global_blog_bkp="$HOME/blogbkp"

	#博客网址
	global_blog_url="zjhou.com/blog"

	#本地静态博客根目录
	global_local_blog="$HOME/local/blog"

	#本地静态博客的文本目录
	global_local_posts="$global_local_blog/source/_posts"

	#本地静态博客的图片目录
	global_local_imgs="$global_local_blog/source/imgs"

	#本地存放静态博客渲染成网页文件的目录
	global_local_htmls="$global_local_blog/public"

	#服务器网站文档根目录
	global_site_blog="$HOME/site/blog"
		
		
}

#***************************************************
#*工具函数*
#***************************************************

# 1. 检查邮件发送者是否在白名单中，
# 2. 检查发送者是否发来了管理邮件。
#
#如果不在返回假。
#--------------------------------------
#    返回值   描述
#      1       检测失败，无管理员邮件
#      0       检测成功，有管理员邮件
#  $(($i+1))   管理员邮件的序号
#--------------------------------------
check_sender() {
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
		is_in ${user[$i]} ${global_white_list[@]} && \
		is_in ${subj[$i]} ${global_cmd_set[@]} && \
		echo $(($i+1)) && return 0
	done
	return 1
}

#提取邮件正文（纯文本）
#*工具函数*
#-------------------------
# 参数   描述
#  $1     邮件序号
#-------------------------

extract_mail() {
	#邮件正文终止分割线。
	local cutline="-end-"
	local hasAtta=0

	#保存一份副本。提取附件。
	mail << EOF
		copy $1 $global_tmpbox/MIME.txt
		q
EOF

	#处理附件部分
	#判断是否有附件啊，有则解压，并移到相应目录下。
	#如果有附件，邮件正文终止分割线会变化。因为多了附件部分。
	#当前只考虑了图片附件。
	munpack -C $global_tmpbox MIME.txt | grep "Did not find anything" || \
	hasAtta=1 # 1 表示有附件。
	if [ "$hasAtta" == "1" ] 
	then
		cutline="Part 2:" 
		mv $global_tmpbox/*.jpg $global_local_imgs
		mv $global_tmpbox/*.png $global_local_imgs 
	fi


	#提取正文部分。
	{
		mail << EOF
		p $1
		echo " "
		echo $cutline
		q
EOF
		#AWK根据邮件格式，提取正文内容。将其保存在$global_tmpbox/body.txt中。
		#SED删除第一行空行。
	} | awk '/Content-Type: text\/plain/, /'"$cutline"'/{if(i>1) print x; x=$0; i++}'\
	  | sed '1d' \
	  > $global_tmpbox/body.txt  	
}

#删除邮件
#-------------------------
# 参数   描述
#  $1     邮件序号
#-------------------------
del_mail() {
	mail << EOF
	d $1
EOF
}

#提取邮件主题（不支持空格）
#-------------------------
# 参数   描述
#  $1     邮件序号
#-------------------------
get_subject() {
	local subj=`mail -H | awk '{if($1 == "'$1'") print $3}'`
	echo $subj
}

#设置当前管理员
#-------------------------
# 参数   描述
#  $1     邮件序号
#-------------------------
set_manager() {
	global_default_manager=`mail -H | awk '{if($1 == "'$1'") print $2}'`
}


#***************************************************
#*API函数*
#***************************************************



#重新从markdown生成html文件
update() {
	cd $global_local_blog && hexo clean --silent && hexo g --silent
	#参数-u表示只拷贝更新的文件。
	cp -uR $global_local_htmls/* $global_site_blog/
}

#把邮件内容作为博文。发布到博客。
# * 此时邮件内容必须为准备发布的博文。
# * 格式：第一行为博文的名字，不能为空行。
add() {
	#注意！提取第一行为标题。所有邮件正文第一行不能为空。
	local title=`cat $global_tmpbox/body.txt | awk 'NR == 1 {print}'`

	#根据hexo博文语法的要求。加入如下一行，否则不能正常显示标题。
	echo -e "title: $title\n---\n" > $global_local_posts/$title.md

	#邮件除第一行，都将作为正文。
	cat $global_tmpbox/body.txt | awk 'NR != 1 {print}' >> $global_local_posts/$title.md

	update

	echo "博文《$title》部署成功，您可以点击查看：http://$global_blog_url" \
	| mail -s "部署成功" $global_default_manager
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


#批量删除博文
# * 邮件正文内容必须为准备删除的博文名字。
# * 格式必须为一行一个条目。
del() {
	#获取要删除的目标博文并初始化操作标识
	local target=(`cat $global_tmpbox/body.txt | awk '{print}'`)
	local error=0
	local norm=0

	#静默创建日志文件
	{ 
		echo -e "---操作日志---" > $global_tmpbox/del.log
		echo -e "成功删除的博文：" > $global_tmpbox/del_norm.log
		echo -e "无法删除的博文（请检查文件名是否正确）：" > $global_tmpbox/del_err.log
	} &> /dev/null

	#遍历博文
	for file in ${target[@]}; do
		if [ -e $global_local_posts/$file.md ]; then
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

	cat $global_tmpbox/del.log \
	| mail -s "操作日志" $global_default_manager #将结果通过邮件回传给管理员
}

#***************************************************
#*MAIN函数*
#***************************************************


#为了提高程序可读性，统一在主函数调用该脚本里其他函数
MAIN (){
	#检测邮箱里是否有邮件。
	mail -e || exit

	#设置编码，否则Crontab调用的时候会乱码。
	export LANG="en_US.UTF-8"

	#激活全局变量。
	global_vars

	#获取管理员邮件序号。
	email_num=`check_sender`

	#检测是否有管理员邮件。
	[[ -z $email_num ]] && exit

	#设置当前管理员。
	set_manager $email_num

	#提取邮件正文。
	extract_mail $email_num

	email_subj=`get_subject $email_num`

	case "$email_subj" in
		"发布" ) add ;;
		"删除" ) del ;;
		"目录" ) list ;;
	esac

	#清理临时文件，以及移除已经处理过的管理邮件
	rm $global_tmpbox/*
	del_mail $email_num
}

#***************************************************
#***************************************************
#DO NOT CHANGE ANYTHING HERE ***********************
MAIN #**********************************************
#***************************************************
#***************************************************
