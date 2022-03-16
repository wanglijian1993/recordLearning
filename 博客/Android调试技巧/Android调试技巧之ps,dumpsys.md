# Android调试技巧之ps,dumpsys

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

可通过dumpsys命令查询系统服务的运行状态(对象的成员变量属性值)

**dumpsys activity** 查询AMS服务相关信息

**dumpsys window** //查询WMS服务相关信息 

**dumpsys cpuinfo** //查询CPU情况 

**dumpsys meminfo** //查询内存情况

