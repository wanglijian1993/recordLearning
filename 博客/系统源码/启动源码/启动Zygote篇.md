# 启动Zygote篇

## 1.入口

app_main.cpp,通过init.${ro.zygote}.rc文件去启动app_process/app_main.cpp的main方法

```
//argv=-Xzygote /system/bin --zygote --start-system-server
int main(int argc, char* const argv[])
{
    AppRuntime runtime(argv[0], computeArgBlockSize(argc, argv));
    //忽略第一个参数
    argc--;
    argv++;
    bool zygote = false;
    bool startSystemServer = false;
    bool application = false;
    String8 niceName;
    String8 className;

   //通过argv去给上面参数赋值
    while (i < argc) {
        const char* arg = argv[i++];
        if (strcmp(arg, "--zygote") == 0) {
            zygote = true;
            niceName = ZYGOTE_NICE_NAME;
        } else if (strcmp(arg, "--start-system-server") == 0) {
            startSystemServer = true;
        } else if (strcmp(arg, "--application") == 0) {
            application = true;
        } else if (strncmp(arg, "--nice-name=", 12) == 0) {
            niceName.setTo(arg + 12);
        } else if (strncmp(arg, "--", 2) != 0) {
            className.setTo(arg);
            break;
        } else {
            --i;
            break;
        }
    }

    Vector<String8> args;

        //初始化虚拟机参数 
        maybeCreateDalvikCache();
        //startSystemServer=true 
        if (startSystemServer) {
            args.add(String8("start-system-server"));
        }

        char prop[PROP_VALUE_MAX];
        String8 abiFlag("--abi-list=");
        abiFlag.append(prop);
        args.add(abiFlag);
        for (; i < argc; ++i) {
            args.add(String8(argv[i]));
        }
    if (zygote) {
      //2.AndroidRunTime->start
      runtime.start("com.android.internal.os.ZygoteInit", args, zygote);
    } else if (className) {
        runtime.start("com.android.internal.os.RuntimeInit", args, zygote);
    } else {
        fprintf(stderr, "Error: no class name or --zygote supplied.\n");
        app_usage();
        LOG_ALWAYS_FATAL("app_process: no class name or --zygote supplied.");
        return 10;
    }
}
```

通过argcs传递过来的参数进行一些行为操作，然后调用AndroidRuntime.start函数。

## 2.runtime.start

```
void AndroidRuntime::start(const char* className, const Vector<String8>& options, bool zygote)
{
    static const String8 startSystemServer("start-system-server");
    
    const char* rootDir = getenv("ANDROID_ROOT");

    //创建虚拟机对象
    JniInvocation jni_invocation;
    jni_invocation.Init(NULL);
    JNIEnv* env;
    //启动虚拟机
    if (startVm(&mJavaVM, &env, zygote) != 0) {
        return;
    }
    onVmCreated(env);

    //注册Android方法jni
    if (startReg(env) < 0) {
        ALOGE("Unable to register all android natives\n");
        return;
    }

   
    jclass stringClass;
    jobjectArray strArray;
    jstring classNameStr;
    //通过jni去初始化参数
    stringClass = env->FindClass("java/lang/String");
    assert(stringClass != NULL);
    strArray = env->NewObjectArray(options.size() + 1, stringClass, NULL);
    assert(strArray != NULL);
    classNameStr = env->NewStringUTF(className);
    assert(classNameStr != NULL);
    env->SetObjectArrayElement(strArray, 0, classNameStr);
    for (size_t i = 0; i < options.size(); ++i) {
        jstring optionsStr = env->NewStringUTF(options.itemAt(i).string());
        assert(optionsStr != NULL);
        env->SetObjectArrayElement(strArray, i + 1, optionsStr);
    }
    
    char* slashClassName = toSlashClassName(className);
    //com.android.internal.os.ZygoteInit
    jclass startClass = env->FindClass(slashClassName);
    if (startClass == NULL) {
    } else {
        jmethodID startMeth = env->GetStaticMethodID(startClass, "main",
            "([Ljava/lang/String;)V");
        if (startMeth == NULL) {
        
        } else {
           //3.已经创建了虚拟机就可以执行java代码，jni调用ZygoteInit正式进入java的世界
            env->CallStaticVoidMethod(startClass, startMeth, strArray);

#if 0
            if (env->ExceptionCheck())
                threadExitUncaughtException(env);
#endif
        }
    }
    free(slashClassName);

}
```

创建虚拟机和注册jni，进入ZygoteInit.java类中的main方法

## 3env->CallStaticVoidMethod

```
 public static void main(String argv[]) {
        try {
            RuntimeInit.enableDdms();
            SamplingProfilerIntegration.start();

            boolean startSystemServer = false;
            String socketName = "zygote";
            String abiList = null;
            for (int i = 1; i < argv.length; i++) {
                if ("start-system-server".equals(argv[i])) {
                    startSystemServer = true;
                } else if (argv[i].startsWith(ABI_LIST_ARG)) {
                    abiList = argv[i].substring(ABI_LIST_ARG.length());
                } else if (argv[i].startsWith(SOCKET_NAME_ARG)) {
                    socketName = argv[i].substring(SOCKET_NAME_ARG.length());
                } else {
                    throw new RuntimeException("Unknown command line argument: " + argv[i]);
                }
            }
            //注册socket，进行通知，常见用途zygote孵化进程  
            registerZygoteSocket(socketName);
            //3.1预加载    
            preload();
            //启动service_manager
            if (startSystemServer) {
                startSystemServer(abiList, socketName);
            }

            //3.2轮训等待其他进程的消息通过socket通信 io多路复用技术降低cpu消耗
            runSelectLoop(abiList);
            //退出循环关闭socket
            closeServerSocket();
        } catch (MethodAndArgsCaller caller) {
            caller.run();
        } catch (RuntimeException ex) {
            Log.e(TAG, "Zygote died with exception", ex);
            closeServerSocket();
            throw ex;
        }
    }
```

##  3.1preload()

```
    static void preload() {
        Log.d(TAG, "begin preload");
        //预加载/system/etc/preloaded-classes里面文件
        preloadClasses();
        //创建Resources对象
        preloadResources();
        //预加载openGl
        preloadOpenGL();
        //预加载android，compoler_rt,jnigraphic jar包
        preloadSharedLibraries();
        preloadTextResources();
        // Ask the WebViewFactory to do any initialization that must run in the zygote process,
        // for memory sharing purposes.
        WebViewFactory.prepareWebViewInZygote();
        Log.d(TAG, "end preload");
    }
```

## 3.2runSelectLoop

```
   private static void runSelectLoop(String abiList) throws MethodAndArgsCaller {
        ArrayList<FileDescriptor> fds = new ArrayList<FileDescriptor>();
        ArrayList<ZygoteConnection> peers = new ArrayList<ZygoteConnection>();
        //sServerSocket把zygeote服务端存到fds[0]数组下标1的位置
        fds.add(sServerSocket.getFileDescriptor());
        peers.add(null);

        while (true) {
            StructPollfd[] pollFds = new StructPollfd[fds.size()];
            for (int i = 0; i < pollFds.length; ++i) {
                pollFds[i] = new StructPollfd();
                pollFds[i].fd = fds.get(i);
                pollFds[i].events = (short) POLLIN;
            }
            try {
                //阻塞,等待pollFds事件，
                Os.poll(pollFds, -1);
            } catch (ErrnoException ex) {
                throw new RuntimeException("poll failed", ex);
            }
            for (int i = pollFds.length - 1; i >= 0; --i) {
           			 //采用I/O多路复用机制，当接收到客户端发出连接请求 或者数据处理请求到来，则往下执行；
           			 // 否则进入continue，跳出本次循环。
                if ((pollFds[i].revents & POLLIN) == 0) {
                    continue;
                }
                if (i == 0) {
                   //即fds[0]，代表的是sServerSocket，则意味着有客户端连接请求；
                  // 则创建ZygoteConnection对象,并添加到fds。
                    ZygoteConnection newPeer = acceptCommandPeer(abiList);
                    peers.add(newPeer);
                    fds.add(newPeer.getFileDesciptor());
                } else {
                   //3.3 i>0，则代表通过socket接收来自对端的数据，并执行相应操作
                    boolean done = peers.get(i).runOnce();
                    //处理完移除信息
                    if (done) {
                        peers.remove(i);
                        fds.remove(i);
                    }
                }
            }
        }
    }
```

Zygote采用高效的I/O多路复用机制，保证在没有客户端连接请求或数据处理时休眠，否则响应客户端的请求

## 3.3runOnce()

```
 boolean runOnce() throws ZygoteInit.MethodAndArgsCaller {

        String args[];
        Arguments parsedArgs = null;
        FileDescriptor[] descriptors;
        try {
            //通过socket读取客户度发过来的参数列表
            args = readArgumentList();
            descriptors = mSocket.getAncillaryFileDescriptors();
        } catch (IOException ex) {
            closeSocket();
            return true;
        }


        PrintStream newStderr = null;

        if (descriptors != null && descriptors.length >= 3) {
            newStderr = new PrintStream(
                    new FileOutputStream(descriptors[2]));
        }

        int pid = -1;
        //客户度和服务端的FD
        FileDescriptor childPipeFd = null;
        FileDescriptor serverPipeFd = null;

        try {
            //参数转换对象
            parsedArgs = new Arguments(args);
            int [] fdsToClose = { -1, -1 };

            FileDescriptor fd = mSocket.getFileDescriptor();

            if (fd != null) {
                fdsToClose[0] = fd.getInt$();
            }

            fd = ZygoteInit.getServerSocketFileDescriptor();

            if (fd != null) {
                fdsToClose[1] = fd.getInt$();
            }

            fd = null;
            //通过jni进入native层fork子进程
            pid = Zygote.forkAndSpecialize(parsedArgs.uid, parsedArgs.gid, parsedArgs.gids,
                    parsedArgs.debugFlags, rlimits, parsedArgs.mountExternal, parsedArgs.seInfo,
                    parsedArgs.niceName, fdsToClose, parsedArgs.instructionSet,
                    parsedArgs.appDataDir);
        } catch (ErrnoException ex) {
            logAndPrintError(newStderr, "Exception creating pipe", ex);
        } catch (IllegalArgumentException ex) {
            logAndPrintError(newStderr, "Invalid zygote arguments", ex);
        } catch (ZygoteSecurityException ex) {
            logAndPrintError(newStderr,
                    "Zygote security policy prevents request: ", ex);
        }

        try {
            
            if (pid == 0) {
               //处理子进程逻辑
                IoUtils.closeQuietly(serverPipeFd);
                serverPipeFd = null;
                handleChildProc(parsedArgs, descriptors, childPipeFd, newStderr);
                return true;
            } else {
                //父进程逻辑
                IoUtils.closeQuietly(childPipeFd);
                childPipeFd = null;
                return handleParentProc(pid, descriptors, serverPipeFd, parsedArgs);
            }
        } finally {
            IoUtils.closeQuietly(childPipeFd);
            IoUtils.closeQuietly(serverPipeFd);
        }
    }
```

zygote主要处理的时间

1.创建虚拟机

2.注册jni函数

3.预加载代码，资源，OpenGl

4.fork service_manager进程