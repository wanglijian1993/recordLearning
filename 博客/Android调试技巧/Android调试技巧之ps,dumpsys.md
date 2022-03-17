# Android调试技巧之adb,ps,dumpsys

## adb



## ps进程命令

**ps(Process status)**：查看手机全部进程,虚拟和物理内存空间和进程数据

**adb shell ps**

| 字段      | 含义                     |
| :-------- | :----------------------- |
| USER      | 进程的当前用户           |
| PID       | 进程ID                   |
| PPID      | 父进程ID                 |
| VSIZE     | 进程虚拟地址空间大小     |
| RSS       | 进程正在使用物理内存大小 |
| **WCHAN** | 内核地址                 |
| Name      | 进程名                   |

#### 命令参数

- -t 显示进程里的所有子线程
- -p 显示进程优先级、nice值、调度策略
- -P 显示进程，通常是bg(后台进程)或fg(前台进程)

## dumpsys命令用法

**`dumpsy`**命令是`Android`设备上运行的工具，可提供有关系服务的信息。可以通过**adb shell dumpsys**命令调用`dumpsys`,获取在连接的设备上运行的所有系统服务的诊断输出。

### 语法

```
 adb shell dumpsys [-t timeout] [--help | -l | --skip services | service [arguments] | -c | -h]
```

| 选项                  | 说明                                                         |
| :-------------------- | :----------------------------------------------------------- |
| `-t timeout`          | 指定超时期限（秒）。如果未指定，默认值为 10 秒。             |
| `--help`              | 输出 `dumpsys` 工具的帮助文本。                              |
| `-l`                  | 输出可与 `dumpsys` 配合使用的系统服务的完整列表。            |
| `--skip services`     | 指定您不希望包含在输出中的 services。                        |
| `service [arguments]` | 指定您希望输出的 service。某些服务可能允许您传递可选 arguments。您可以通过将 `-h` 选项与服务名称一起传递来了解这些可选参数，如下所示：`adb shell dumpsys procstats -h    ` |
| `-c`                  | 指定某些服务时，附加此选项能以计算机可读的格式输出数据。     |
| `-h`                  | 对于某些服务，附加此选项可查看该服务的帮助文本和其他选项。   |

### 系统服务

**表一：**

| 服务名       | 类名                   | 功能         |
| :----------- | :--------------------- | :----------- |
| activity     | ActivityManagerService | AMS相关信息  |
| package      | PackageManagerService  | PMS相关信息  |
| window       | WindowManagerService   | WMS相关信息  |
| input        | InputManagerService    | IMS相关信息  |
| power        | PowerManagerService    | PMS相关信息  |
| batterystats | BatterystatsService    | 电池统计信息 |
| battery      | BatteryService         | 电池信息     |
| alarm        | AlarmManagerService    | 闹钟信息     |
| dropbox      | DropboxManagerService  | 调试相关     |
| procstats    | ProcessStatsService    | 进程统计     |
| cpuinfo      | CpuBinder              | CPU          |
| meminfo      | MemBinder              | 内存         |
| gfxinfo      | GraphicsBinder         | 图像         |
| dbinfo       | DbBinder               | 数据库       |

**表二：**

| 服务名               | 功能             |
| :------------------- | :--------------- |
| SurfaceFlinger       | 图像相关         |
| appops               | app使用情况      |
| permission           | 权限             |
| processinfo          | 进程服务         |
| batteryproperties    | 电池相关         |
| audio                | 查看声音信息     |
| netstats             | 查看网络统计信息 |
| diskstats            | 查看空间free状态 |
| jobscheduler         | 查看任务计划     |
| wifi                 | wifi信息         |
| diskstats            | 磁盘情况         |
| usagestats           | 用户使用情况     |
| devicestoragemonitor | 设备信息         |
| …                    | …                |

```
可通过dumpsys命令查询系统服务的运行状态(对象的成员变量属性值)

dumpsys activity top //当前界面app状态

dumpsys activity oom //查看进程状态

dumpsys activity //查询AMS服务相关信息

dumpsys window //查询WMS服务相关信息 

dumpsys cpuinfo //查询CPU情况 

dumpsys meminfo //查询内存情况

可查询的服务有很多，可通过下面任一命令查看当前系统所支持的dump服务：

adb shell dumpsys -l adb shell service list
```



### Activity场景

**查询某个APP所有Service状态**

adb shell dumpsys s 包名

**场景1：查询某个App所有的Service状态**

**搜索关键字ServiceRecord**

```
ServiceRecord{c1eb729 u0 com.jinher.commonlib/com.jh.precisecontrolcom.patrolnew.receiver.FootPrintService}
intent={cmp=com.jinher.commonlib/com.jh.precisecontrolcom.patrolnew.receiver.FootPrintService}
packageName=com.jinher.commonlib
app=ProcessRecord{c2ca1ad 4082:com.jinher.commonlib/u0a749}
createTime=-1h8m48s747ms startingBgTimeout=--
lastActivity=-1h8m48s747ms restartTime=-1h8m48s747ms createdFromFg=true
startRequested=true delayedStop=false stopIfKilled=false callStart=true lastStartId=1
```

Service类名为`com.jh.precisecontrolcom.patrolnew.receiver.FootPrintService`；

运行在进程pid=`4082`，进程名为`com.jinher.commonlib`，uid=`u0a749`；

**场景2：查询某个App所有的广播状态**

![dumpsys_broadcast](http://gityuan.com/images/tools/dumpsys_broadcast.png)

**场景3：查询某个App所有的Activity状态**

* ```
    TaskRecord{c21e27b #936 A=10749:com.jinher.commonlib U=0 StackId=3 sz=1}
    mCallingPackage=com.jinher.commonlib
    affinity=10749:com.jinher.commonlib
    intent={act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10200000 cmp=com.jinher.commonlib/com.jh.startpage.activity.InitAcitivity$}
    mActivityComponent=com.jinher.commonlib/com.jh.startpage.activity.InitAcitivity$
    autoRemoveRecents=false isPersistable=true numFullscreen=1 activityType=1
    rootWasReset=true mNeverRelinquishIdentity=true mReuseTask=false mLockTaskAuth=LOCK_TASK_AUTH_PINNABLE
    Activities=[ActivityRecord{c0c0105 u0 com.jinher.commonlib/com.jh.placerTemplate.activity.MainActivity t936}]
    
    * Hist #0: ActivityRecord{c0c0105 u0 com.jinher.commonlib/com.jh.placerTemplate.activity.MainActivity t936}
      packageName=com.jinher.commonlib processName=com.jinher.commonlib
    ```
    
    

- 格式：TaskRecord{Hashcode #TaskId Affinity UserId=0 Activity个数=1}；所以上图信息解析后就是TaskId=`936`，Affinity=`com.jinher.commonlib`，当前Task中Activity个数为1。
- android.intent.category.LAUNCHER 启动的Activity
- Hist #0 Activity栈

**场景4：查询某个App的进程状态**

adb shell dumpsys activity p com.sina.weibo

- 包含进程名,进程pid,uid

- 该进程中还有Services，Connections, Providers, Receivers，可以看出该进程是没有Activity的进程。

**场景4:查询某个app的内存使用情况**

adb shell dumpsys meminfo 应用包名

## bugreport

对于Android系统调试分析，bugreport信息量非常之大，几乎涵盖整个系统各个层面内容，对于分析BUG是一大利器，本文先从从源码角度来分析一下Bugreport的实现原理。

通过adb命令可获取bugrepport信息，并输出到文件当前路径的bugreport.txt文件：

adb bugreport > bugreport.txt

# gdb调试工具

http://gityuan.com/2017/09/09/gdb/

# 介绍addr2line调试命令

用addr2line可以将函数地址解析为函数名，在抓取调堆栈时Java层的堆栈本身就是显示函数名与行数，这个不需要转换，但对于native和kernel层的则是函数地址，需要借助addr2line来进行转换。 接下来分析介绍一下这个地址转换方法

http://gityuan.com/2017/09/02/addr2line/

