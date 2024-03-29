

# 启动流程Init篇

## 一.概述

### 启动描述

长按电源启动机器手机CPU第一条指令会指向操作系统所在位置，BootLoader (系统启动加载器)，用以初始化硬件设备，建立内存空间的映像图，为最终调用系统内核准备好环境。 在 Android 里没有硬盘，而是 ROM，它类似于硬盘存放操作系统，用户程序等。 ROM 跟硬盘一样也会划分为不同的区域，用于放置不同的程序。当 Linux 内核启动后会初始化各种软硬件环境，加载驱动程序，挂载根文件系统，Linux 内核加载的准备完毕后就开始加载一些特定的程序(进程)了。第一个加载的就是 init 进程。


## 二.启动源码流程 init.cpp main函数

```
int main(int argc, char** argv) {
    //umask是确定掩码设置的命令，该掩码控制如何为新创建的文件设置文件权限 umask(0)取反=0777=rwx_rwx_rwx
      umask(0);

    //设置Path环境变量 _PATH_DEFPATH	"/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin"添加到ENV数组中
    add_environment("PATH", _PATH_DEFPATH);

    bool is_first_stage = (argc == 1) || (strcmp(argv[1], "--second-stage") != 0);
    if (is_first_stage) {
      //创建文件夹和挂载文件
      mount("tmpfs", "/dev", "tmpfs", MS_NOSUID, "mode=0755");
      mkdir("/dev/pts", 0755);
      mkdir("/dev/socket", 0755);
      mount("devpts", "/dev/pts", "devpts", 0, NULL);
      mount("proc", "/proc", "proc", 0, NULL);
      mount("sysfs", "/sys", "sysfs", 0, NULL);
    }
    // 初始化日志和输出日志的级别(解析init.rc文件)
    klog_init();
    klog_set_level(KLOG_NOTICE_LEVEL);
    //2.1 开启属性服务,通过mmap开启共享内存位置/dev/properties 大小(128 * 1024)
    property_init();

    //创建epoll句柄 I/O多路复用 容量 EPOLL_CLOEXEC=02000000
    epoll_fd = epoll_create1(EPOLL_CLOEXEC);
    //2.2 初始化信号
    signal_handler_init();
    //2.3 启动属性服务
    start_property_service();
    //解析init.rc
    init_parse_config_file("/init.rc");
    //添加一些额外的执行任务
    action_for_each_trigger("early-init", action_add_queue_tail);
    queue_builtin_action(wait_for_coldboot_done_action, "wait_for_coldboot_done");
    queue_builtin_action(mix_hwrng_into_linux_rng_action, "mix_hwrng_into_linux_rng");
    queue_builtin_action(keychord_init_action, "keychord_init");
    queue_builtin_action(console_init_action, "console_init");
    action_for_each_trigger("init", action_add_queue_tail);
    queue_builtin_action(mix_hwrng_into_linux_rng_action, "mix_hwrng_into_linux_rng");
    queue_builtin_action(queue_property_triggers_action, "queue_property_triggers");

    while (true) {
        if (!waiting_for_exec) {
            //执行init.rc封装的命令
            execute_one_command();
            restart_processes();
        }

        int timeout = -1;
        if (process_needs_restart) {
            timeout = (process_needs_restart - gettime()) * 1000;
            if (timeout < 0)
                timeout = 0;
        }

        if (!action_queue_empty() || cur_action) {
            timeout = 0;
        }

        bootchart_sample(&timeout);

        epoll_event ev;
        int nr = TEMP_FAILURE_RETRY(epoll_wait(epoll_fd, &ev, 1, timeout));
        if (nr == -1) {
            ERROR("epoll_wait failed: %s\n", strerror(errno));
        } else if (nr == 1) {
            ((void (*)()) ev.data.ptr)();
        }
    }

    return 0;
}
```

### 2.1 property_init

```
static workspace pa_workspace;
void property_init() {

    //只初始化一次
    if (property_area_initialized) {
        return;
    }
    property_area_initialized = true;

     // 2.1.1 通过mmap开启共享内存位置/dev/properties 大小(128 * 1024)
    if (__system_property_area_init()) {
        return;
    }
    //初始化workspace
    pa_workspace.size = 0;
    //创建文件"/dev/__properties__"
    pa_workspace.fd = open(PROP_FILENAME, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (pa_workspace.fd == -1) {
        ERROR("Failed to open %s: %s\n", PROP_FILENAME, strerror(errno));
        return;
    }
}
```

### 2.1.1 __system_property_area_init

```
static int map_prop_area_rw()
{

     //property_filename=/dev/properties
    const int fd = open(property_filename,
                        O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_EXCL, 0444);
    //PA_SIZE (128 * 1024)
    pa_size = PA_SIZE;
    pa_data_size = pa_size - sizeof(prop_area);
    compat_mode = false;
    //mmap开启虚拟内存地址
    void *const memory_area = mmap(NULL, pa_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (memory_area == MAP_FAILED) {
        close(fd);
        return -1;
    }

    //内存的首地址保存在__system_property_area__
    prop_area *pa = new(memory_area) prop_area(PROP_AREA_MAGIC, PROP_AREA_VERSION);
    __system_property_area__ = pa;

    close(fd);
    return 0;
}
```
初始化属性，通过mmap创建init进程内部创建一个共享内存，然后初始化一个静态workspace结构

### 2.2 signal_handler_init
```
void signal_handler_init() {
        int s[2];
    //socketpair()函数用于创建一对无名的、相互连接的套接子。
    if (socketpair(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0, s) == -1) {
        ERROR("socketpair failed: %s\n", strerror(errno));
        exit(1);
    }
    //存储读和写的句柄
    signal_write_fd = s[0];
    signal_read_fd = s[1];
    // 创建一个sigaction信号量对象
    struct sigaction act;
    memset(&act, 0, sizeof(act));
    // 2.2.1 信号回调
    act.sa_handler = SIGCHLD_handler;
    //监听信号类型
    act.sa_flags = SA_NOCLDSTOP;
    //设置SIGCHLD信号处理的方法
    sigaction(SIGCHLD, &act, 0);
    //2.2.2 处理子进程退出的时候对服务的资源释放
    reap_any_outstanding_children();
    2.2.3注册
    register_epoll_handler(signal_read_fd, handle_signal);
    }
```
### 2.2.1 SIGCHLD_handler
```
static void SIGCHLD_handler(int) {
     //监听到信号往signal_write_fd写数据
    if (TEMP_FAILURE_RETRY(write(signal_write_fd, "1", 1)) == -1) {
        ERROR("write(signal_write_fd) failed: %s\n", strerror(errno));
    }
}
```
### 2.2.2 reap_any_outstanding_children()

```
static void reap_any_outstanding_children() {
    //等待
    while (wait_for_one_process()) {

    }

}

static bool wait_for_one_process() {
    int status;
    //当waitpid>0的时候会返回退出的pid
    pid_t pid = TEMP_FAILURE_RETRY(waitpid(-1, &status, WNOHANG));
    if (pid == 0) {
        return false;
    } else if (pid == -1) {
        ERROR("waitpid failed: %s\n", strerror(errno));
        return false;
    }

    //获取进程的服务(解析init.rc文件创建的service文件)
    service* svc = service_find_by_pid(pid);

    std::string name;
    if (svc) {
        name = android::base::StringPrintf("Service '%s' (pid %d)", svc->name, pid);
    } else {
        name = android::base::StringPrintf("Untracked pid %d", pid);
    }
    //过滤不识别的进程
    if (!svc) {
        return true;
    }

    //服务的标识不为SVC_ONESHOT或者为SVC_RESTART 杀死进程组
    if (!(svc->flags & SVC_ONESHOT) || (svc->flags & SVC_RESTART)) {
        NOTICE("Service '%s' (pid %d) killing any children in process group\n", svc->name, pid);
        kill(-pid, SIGKILL);
    }

    //清空进程socket列表
    for (socketinfo* si = svc->sockets; si; si = si->next) {
        char tmp[128];
        snprintf(tmp, sizeof(tmp), ANDROID_SOCKET_DIR"/%s", si->name);
        unlink(tmp);
    }

    //服务标识SVC_EXEC释放内存
    if (svc->flags & SVC_EXEC) {
        INFO("SVC_EXEC pid %d finished...\n", svc->pid);
        waiting_for_exec = false;
        list_remove(&svc->slist);
        free(svc->name);
        free(svc);
        return true;
    }

    svc->pid = 0;
    svc->flags &= (~SVC_RUNNING);

     //flags标识SVC_ONESHOT并且不是SVC_RESTART 设置为SVC_DISABLED
    if ((svc->flags & SVC_ONESHOT) && !(svc->flags & SVC_RESTART)) {
        svc->flags |= SVC_DISABLED;
    }

    //禁用和重置的服务，都不再自动重启
    if (svc->flags & (SVC_DISABLED | SVC_RESET))  {
        svc->NotifyStateChange("stopped");
        return true;
    }

    time_t now = gettime();
    //进程在4分钟内重启次数超过4次，则重启手机进入recovery模式
    if ((svc->flags & SVC_CRITICAL) && !(svc->flags & SVC_RESTART)) {
        if (svc->time_crashed + CRITICAL_CRASH_WINDOW >= now) {
            if (++svc->nr_crashed > CRITICAL_CRASH_THRESHOLD) {
                android_reboot(ANDROID_RB_RESTART2, 0, "recovery");
                return true;
            }
        } else {
            svc->time_crashed = now;
            svc->nr_crashed = 1;
        }
    }

    svc->flags &= (~SVC_RESTART);
    svc->flags |= SVC_RESTARTING;

    //执行service中所有onrestart命令
    struct listnode* node;
    list_for_each(node, &svc->onrestart.commands) {
        command* cmd = node_to_item(node, struct command, clist);
        cmd->func(cmd->nargs, cmd->args);
    }
    //设置相应的service状态为restarting
    svc->NotifyStateChange("restarting");
    return true;
}
```

### 2.2.3 register_epoll_handler(signal_read_fd, handle_signal);

```
void register_epoll_handler(int fd, void (*fn)()) {
    epoll_event ev;
    ev.events = EPOLLIN;
    ev.data.ptr = reinterpret_cast<void*>(fn);
    //将fd的可读事件加入到epoll_fd的监听队列中
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) == -1) {
        ERROR("epoll_ctl failed: %s\n", strerror(errno));
    }
}

```

### 3.4 handle_signal和SIGCHLD_handler

```
//读取数据
static void handle_signal() {
    // Clear outstanding requests.
    char buf[32];
    read(signal_read_fd, buf, sizeof(buf));

    reap_any_outstanding_children();
}
//写入数据
static void SIGCHLD_handler(int) {
     //向signal_write_fd写入1，直到成功为止
    if (TEMP_FAILURE_RETRY(write(signal_write_fd, "1", 1)) == -1) {
        ERROR("write(signal_write_fd) failed: %s\n", strerror(errno));
    }
}
```

### 2.3  start_property_service

```
  start_property_service();
  void start_property_service() {
    //PROP_SERVICE_NAME property_service
    property_set_fd = create_socket(PROP_SERVICE_NAME, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK,
                                    0666, 0, 0, NULL);
    if (property_set_fd == -1) {
        ERROR("start_property_service socket creation failed: %s\n", strerror(errno));
        exit(1);
    }

    listen(property_set_fd, 8);
    //2.3.1 监听
    register_epoll_handler(property_set_fd, handle_property_set_fd);
}

```

### 2.3.1 register_epoll_handler

```
void register_epoll_handler(int fd, void (*fn)()) {
    epoll_event ev;
    ev.events = EPOLLIN;
    //函数转换成void*
    ev.data.ptr = reinterpret_cast<void*>(fn);
    //fd的事件添加到epoll_fd队列中
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &ev) == -1) {
        ERROR("epoll_ctl failed: %s\n", strerror(errno));
    }
}

//回调方法
static void handle_property_set_fd()
{
    prop_msg msg;
    int s;
    int r;
    struct ucred cr;
    struct sockaddr_un addr;
    socklen_t addr_size = sizeof(addr);
    socklen_t cr_size = sizeof(cr);
    char * source_ctx = NULL;
    struct pollfd ufds[1];
    const int timeout_ms = 2 * 1000;  /* Default 2 sec timeout for caller to send property. */
    int nr;

    if ((s = accept(property_set_fd, (struct sockaddr *) &addr, &addr_size)) < 0) {
        return;
    }

    /* Check socket options here */
    if (getsockopt(s, SOL_SOCKET, SO_PEERCRED, &cr, &cr_size) < 0) {
        close(s);
        ERROR("Unable to receive socket options\n");
        return;
    }

    ufds[0].fd = s;
    ufds[0].events = POLLIN;
    ufds[0].revents = 0;
    nr = TEMP_FAILURE_RETRY(poll(ufds, 1, timeout_ms));
    if (nr == 0) {
        ERROR("sys_prop: timeout waiting for uid=%d to send property message.\n", cr.uid);
        close(s);
        return;
    } else if (nr < 0) {
        ERROR("sys_prop: error waiting for uid=%d to send property message: %s\n", cr.uid, strerror(errno));
        close(s);
        return;
    }

    r = TEMP_FAILURE_RETRY(recv(s, &msg, sizeof(msg), MSG_DONTWAIT));
    if(r != sizeof(prop_msg)) {
        ERROR("sys_prop: mis-match msg size received: %d expected: %zu: %s\n",
              r, sizeof(prop_msg), strerror(errno));
        close(s);
        return;
    }
    //处理消息命令  
    switch(msg.cmd) {
    case PROP_MSG_SETPROP:
        msg.name[PROP_NAME_MAX-1] = 0;
        msg.value[PROP_VALUE_MAX-1] = 0;

        if (!is_legal_property_name(msg.name, strlen(msg.name))) {
            ERROR("sys_prop: illegal property name. Got: \"%s\"\n", msg.name);
            close(s);
            return;
        }

        getpeercon(s, &source_ctx);
         //msg.name匹配上ctl.开头
        if(memcmp(msg.name,"ctl.",4) == 0) {
            close(s);
            if (check_control_mac_perms(msg.value, source_ctx)) {
                //4.3
                handle_control_message((char*) msg.name + 4, (char*) msg.value);
            } else {
                ERROR("sys_prop: Unable to %s service ctl [%s] uid:%d gid:%d pid:%d\n",
                        msg.name + 4, msg.value, cr.uid, cr.gid, cr.pid);
            }
        } else {
            if (check_perms(msg.name, source_ctx)) {
                property_set((char*) msg.name, (char*) msg.value);
            } else {
                ERROR("sys_prop: permission denied uid:%d  name:%s\n",
                      cr.uid, msg.name);
            }

            // Note: bionic's property client code assumes that the
            // property server will not close the socket until *AFTER*
            // the property is written to memory.
            close(s);
        }
        freecon(source_ctx);
        break;

    default:
        close(s);
        break;
    }
}
```

4.3handle_control_message

```
void handle_control_message(const char *msg, const char *arg)
{
    if (!strcmp(msg,"start")) {
        //启动服务
        msg_start(arg);
    } else if (!strcmp(msg,"stop")) {
        //关闭服务
        msg_stop(arg);
    } else if (!strcmp(msg,"restart")) {
        //重启服务
        msg_restart(arg);
    } else {
        ERROR("unknown control msg '%s'\n", msg);
    }
}
```

init进程核心

1. 创建目录,挂载分区

2. 解析启动脚本，

3. 启动解析的服务

4. 守护解析的服务
