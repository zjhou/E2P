# E2P
Email 2 Post: 监测并解析博客管理员邮件，自动部署博文，更新博客。
通过发送管理邮件给服务器来控制hexo的行为。

### 环境

操作系统：ubuntu server 12.02
邮件系统：postfix + mail
博客系统：hexo + apache2.0

### 配置
VARS_CONF

### 运行
$ crontab -e
加入一行
```
* * * * * cd path/to/E2P/ && e2p.sh
```

### 主要功能

在白名单中的管理员邮件地址才会生效。可在VARS_CONF中配置。

1. 添加博文
邮件格式：
收件人：exmple@yourserver.com
主题：发布
正文：
（第一行为标题，其余行为正文）
（关键字格式如“图1%89”，将被解析成图片标签<img src='/blog/imgs/imgname' width='89%' /> 其中imgname是附件中第一张图片的名字含后缀）

2. 批量删除博文
邮件格式：
收件人：exmple@yourserver.com
主题：删除
正文：
（博文标题，用空格隔开，或一行一个博文标题）

3. 查询博文目录
邮件格式：
收件人：exmple@yourserver.com
主题：目录
正文：（留空即可）

4. 隐藏 - 隐藏所有博文
邮件格式：
收件人：exmple@yourserver.com
主题：隐藏
正文：（留空即可）

5. 恢复 - 恢复4隐藏的博文
邮件格式：
收件人：exmple@yourserver.com
主题：恢复
正文：（留空即可）

6. 帮助 - 返回帮助文档
邮件格式：
收件人：exmple@yourserver.com
主题：帮助
正文：（留空即可）

