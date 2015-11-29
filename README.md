# E2P
Email 2 Post: 监测并解析博客管理员邮件，自动部署博文，更新博客。

### 环境

- 操作系统：ubuntu server 12.02
- 邮件系统：postfix + mail
- 博客系统：hexo + apache2.0

### 配置
- mail client: /etc/nail.rc
```
set headhine="%m %30f %s"
#set showname
```
- bash environment: ~/.profile
```
export LANG=en_US.UTF-8
MAIL=path/to/Maildir
```
- crontab -e
```
export LANG=en_US.UTF-8
export PATH=path/to/E2P:$PATH
cd path/to/E2P && e2p.sh &> /dev/null
```
- config HEXO_SYS

### 运行
$ crontab -e
```
* * * * * cd path/to/E2P/ && e2p.sh
```

### 结构
```
E2P
 |
 |-- HEXO_SYS (functions wrap hexo cmds)
 |-- MAIL_SYS (functions wrap mail cmds)
 |-- UTIL_SYS (utils functions)
 `-- e2p.sh (switcher)
                                           
                                       |--> mail_subj-->|            
+---------+   +------+   +----------+  |                |   +--------+
| Maildir |-->| mail |-->| MAIL_SYS |--|--> mail_atta-->|-->| e2p.sh |
+---------+   +------+   +----------+  |                |   +--------+
                                       |--> mail_text-->|       |
                                                                |    
                                         |<--publish <--|       v
+----------+     +--------+   +------+   |<--   list <--|  +----------+
| site_dir |<----| public |<--| hexo |---|<--    del <--|--| HEXO_SYS |
+----------+     +--------+   +----- +   |<--    doc <--|  +----------+
                                         |<--refresh <--|

```

### 主要功能

1. 添加博文
2. 批量删除博文
3. 列出所有博文目录
4. 帮助文档


