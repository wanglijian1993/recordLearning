# Linux基础
111
## 基础知识

linux常用的系统CentOs：1.centOS  2. ubuntu

CentOs；下载rpm

ubuntu: 下载deb

**安装下载的包**

CentOS下面使用rpm -i jdk-XXX_linux-x64_bin.rpm

ubuntu下面使用dpkg -i jdk-XXX_linux-x64_bin.deb

**卸载包**

CentOS: yum -e

Ubuntu: dpkg -r

查询安装的包

rpm -qa | grep jdk

dpkg -l | grep jdk

可以通过more和less进行前翻页和后翻页

rpm -qa | more和rpm -qa | less

｜管道  grep 筛选过滤

**linux查询可以按照软件的版本**

CentOS 通过yum

Ubuntu通过apt-get

安装 :yum install java-11-openjdk.x86_64和apt-get install openjdk-9-jdk来进行安装。

卸载:yum erase java-11-openjdk.x86_64和apt-get purge openjdk-9-jdk。

下载的主要文件一般会放在 usr/bin或usr/sbin目录下，其他的库文件会放在/var下面配置文件放在/etc下面。

**解压**

tar xvzf jdk-XXX_linux-x64_bin.tar.gz。

**linux环境配置环境变量**

export进行配置，export弊端，退出账号就不管用了。

export JAVA_HOME=/root/jdk-XXX_linux-x64 export PATH=$JAVA_HOME/bin:$PATH

永久保留的环境变量配置方法:

例如/root或者/home/cliu8下面，有一个.bashrc文

### linux运行程序

第一种通过shell在交互命令后里运行，但是退出程序就关闭了。

第二种通过nohup：nohup command>out.file 2 >&1 &，

“1”表示文件描述符1，表示标准输出，

“2” 表示文件描述符2，意思是标准错误输出，“2>&1”表示标准输出和错误输出合并了，合并到out.file里

**进程关闭：** ps -ef |grep 关键字  |awk '{print $2}'|xargs kill -9
