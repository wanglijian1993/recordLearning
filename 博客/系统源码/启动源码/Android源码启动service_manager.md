# 启动service_manager

## 1.入口

ZygoteInit.java->startSystemServer

```
 private static boolean startSystemServer(String abiList, String socketName)
            throws MethodAndArgsCaller, RuntimeException {
        long capabilities = posixCapabilitiesAsBits(
            OsConstants.CAP_BLOCK_SUSPEND,
            OsConstants.CAP_KILL,
            OsConstants.CAP_NET_ADMIN,
            OsConstants.CAP_NET_BIND_SERVICE,
            OsConstants.CAP_NET_BROADCAST,
            OsConstants.CAP_NET_RAW,
            OsConstants.CAP_SYS_MODULE,
            OsConstants.CAP_SYS_NICE,
            OsConstants.CAP_SYS_RESOURCE,
            OsConstants.CAP_SYS_TIME,
            OsConstants.CAP_SYS_TTY_CONFIG
        );
        /* Hardcoded command line to start the system server */
        String args[] = {
            "--setuid=1000",
            "--setgid=1000",
            "--setgroups=1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1018,1021,1032,3001,3002,3003,3006,3007",
            "--capabilities=" + capabilities + "," + capabilities,
            "--nice-name=system_server",
            "--runtime-args",
            "com.android.server.SystemServer",
        };
        ZygoteConnection.Arguments parsedArgs = null;

        int pid;

        try {
            parsedArgs = new ZygoteConnection.Arguments(args);
            ZygoteConnection.applyDebuggerSystemProperty(parsedArgs);
            ZygoteConnection.applyInvokeWithSystemProperty(parsedArgs);

            //2.1 fork system_server进程
            pid = Zygote.forkSystemServer(
                    parsedArgs.uid, parsedArgs.gid,
                    parsedArgs.gids,
                    parsedArgs.debugFlags,
                    null,
                    parsedArgs.permittedCapabilities,
                    parsedArgs.effectiveCapabilities);
        } catch (IllegalArgumentException ex) {
            throw new RuntimeException(ex);
        }

        
        if (pid == 0) {
        //处理service_manager进程
            if (hasSecondZygote(abiList)) {
                waitForSecondaryZygote(socketName);
            }
            //3处理service_manager剩余的工作
            handleSystemServerProcess(parsedArgs);
        }

        return true;
    }
```

### 2.1 forkSystemServer

```
  public static int forkSystemServer(int uid, int gid, int[] gids, int debugFlags,
            int[][] rlimits, long permittedCapabilities, long effectiveCapabilities) {
        int pid = nativeForkSystemServer(
                uid, gid, gids, debugFlags, rlimits, permittedCapabilities, effectiveCapabilities);
    、
        return pid;
    }
     //2.2通过jni调用native层代码
     native private static int nativeForkSystemServer(int uid, int gid, int[] gids, int debugFlags,
            int[][] rlimits, long permittedCapabilities, long effectiveCapabilities);
```

调用的 native 方法去创建的，nativeForkSystemServer() 方法在 AndroidRuntime.cpp 中注册的，调用 com_android_internal_os_Zygote.cpp 中的 com_android_internal_os_Zygote_nativeForkSystemServer() 方法

### 2.2nativeForkSystemServer

```
static jint com_android_internal_os_Zygote_nativeForkSystemServer(
        JNIEnv* env, jclass, uid_t uid, gid_t gid, jintArray gids,
        jint debug_flags, jobjectArray rlimits, jlong permittedCapabilities,
        jlong effectiveCapabilities) {
  //2.3 fork进程     
  pid_t pid = ForkAndSpecializeCommon(env, uid, gid, gids,
                                      debug_flags, rlimits,
                                      permittedCapabilities, effectiveCapabilities,
                                      MOUNT_EXTERNAL_DEFAULT, NULL, NULL, true, NULL,
                                      NULL, NULL);
  
  if (pid > 0) {
       //执行父进程的逻辑
      gSystemServerPid = pid;
      int status;
      //waitpid等待SystemServer进程死亡
      if (waitpid(pid, &status, WNOHANG) == pid) {
          //重新启动zygote进程
          RuntimeAbort(env);
      }
  }
  return pid;
}
```

### 2.3 ForkAndSpecializeCommon

```
static pid_t ForkAndSpecializeCommon(JNIEnv* env, uid_t uid, gid_t gid, jintArray javaGids,
                                     jint debug_flags, jobjectArray javaRlimits,
                                     jlong permittedCapabilities, jlong effectiveCapabilities,
                                     jint mount_external,
                                     jstring java_se_info, jstring java_se_name,
                                     bool is_system_server, jintArray fdsToClose,
                                     jstring instructionSet, jstring dataDir) {
 //注册信号
 SetSigChldHandler();
  //孵化进程
  pid_t pid = fork();

  if (pid == 0) {
     // 子进程逻辑 对于非system_server子进程，则创建进程组
    if (!is_system_server) {
        int rc = createProcessGroup(uid, getpid());
        if (rc != 0) {
            if (rc == -EROFS) {
                ALOGW("createProcessGroup failed, kernel missing CONFIG_CGROUP_CPUACCT?");
            } else {
                ALOGE("createProcessGroup(%d, %d) failed: %s", uid, pid, strerror(-rc));
            }
        }
    }
    //调用zygote.callPostForkChildHooks()
    env->CallStaticVoidMethod(gZygoteClass, gCallPostForkChildHooks, debug_flags,
                              is_system_server ? NULL : instructionSet);
  return pid;
}  
```

fork service_manager进程，清理一些不用的数据。

### 3 handleSystemServerProcess

```
 private static void handleSystemServerProcess(
            ZygoteConnection.Arguments parsedArgs)
            throws ZygoteInit.MethodAndArgsCaller {
       //清空socket
        closeServerSocket();

        //设置权限
        Os.umask(S_IRWXG | S_IRWXO);

        //进程名
        if (parsedArgs.niceName != null) {
            Process.setArgV0(parsedArgs.niceName);
        }

      final String systemServerClasspath = Os.getenv("SYSTEMSERVERCLASSPATH");
      if (systemServerClasspath != null) {
        //执行dex优化操作
        performSystemServerDexOpt(systemServerClasspath);
       }
        if (parsedArgs.invokeWith != null) {
            String[] args = parsedArgs.remainingArgs;
            if (systemServerClasspath != null) {
                String[] amendedArgs = new String[args.length + 2];
                amendedArgs[0] = "-cp";
                amendedArgs[1] = systemServerClasspath;
                System.arraycopy(parsedArgs.remainingArgs, 0, amendedArgs, 2, parsedArgs.remainingArgs.length);
            }
            //通过Zygeote.execshell执行命令清理service_manager进程一些数据
            WrapperInit.execApplication(parsedArgs.invokeWith,
                    parsedArgs.niceName, parsedArgs.targetSdkVersion,
                    VMRuntime.getCurrentInstructionSet(), null, args);
        } else {
            ClassLoader cl = null;
            if (systemServerClasspath != null) {
                cl = new PathClassLoader(systemServerClasspath, ClassLoader.getSystemClassLoader());
                Thread.currentThread().setContextClassLoader(cl);
            }
           //4.service_manager进程进行一些操作
            RuntimeInit.zygoteInit(parsedArgs.targetSdkVersion, parsedArgs.remainingArgs, cl);
        }

        /* should never reach here */
    }
```

### 4. zygoteInit

```
  public static final void zygoteInit(int targetSdkVersion, String[] argv, ClassLoader classLoader)
            throws ZygoteInit.MethodAndArgsCaller {
        //启动binder进程 
        nativeZygoteInit();
        //4.1 启动service_manager一些服务
        applicationInit(targetSdkVersion, argv, classLoader);
    }
    
      private static void invokeStaticMain(String className, String[] argv, ClassLoader classLoader)
            throws ZygoteInit.MethodAndArgsCaller {
        Class<?> cl;

        try {
            cl = Class.forName(className, true, classLoader);
        } catch (ClassNotFoundException ex) {
            throw new RuntimeException(
                    "Missing class when invoking static main " + className,
                    ex);
        }

        Method m;
        try {
            m = cl.getMethod("main", new Class[] { String[].class });
        } catch (NoSuchMethodException ex) {
            throw new RuntimeException(
                    "Missing static main on " + className, ex);
        } catch (SecurityException ex) {
            throw new RuntimeException(
                    "Problem getting static main on " + className, ex);
        }

        int modifiers = m.getModifiers();

         //4.1通过抛出异常，回到了 ZygoteInit.main() 
        throw new ZygoteInit.MethodAndArgsCaller(m, argv);
    }

```

### 4.1 ZygoteInit.MethodAndArgsCaller

```
 public static class MethodAndArgsCaller extends Exception
            implements Runnable {
        private final Method mMethod;

        private final String[] mArgs;

        public MethodAndArgsCaller(Method method, String[] args) {
            mMethod = method;
            mArgs = args;
        }

        public void run() {
            try {
                //4.2 根据传递过来的参数可知，此处通过反射机制调用的是 SystemServer.main() 方法
                mMethod.invoke(null, new Object[] { mArgs });
            } catch (IllegalAccessException ex) {
                throw new RuntimeException(ex);
            } catch (InvocationTargetException ex) {
                Throwable cause = ex.getCause();
                if (cause instanceof RuntimeException) {
                    throw (RuntimeException) cause;
                } else if (cause instanceof Error) {
                    throw (Error) cause;
                }
                throw new RuntimeException(ex);
            }
        }
    }
}
```

### 4.2 mMethod.invoke

```
    public static void main(String[] args) {
        new SystemServer().run();
    }
    
     private void run() {
        //主线程loopper
        Looper.prepareMainLooper();


        //初始化上下文
        createSystemContext();

        // 创建系统服务管理
        mSystemServiceManager = new SystemServiceManager(mSystemContext);
        LocalServices.addService(SystemServiceManager.class, mSystemServiceManager);

        // 开启一系列服务，ams，pms，wms等等。
        try {
            startBootstrapServices();
            startCoreServices();
            startOtherServices();
        } catch (Throwable ex) {
            throw ex;
        }
        // 一直循环执行
        Looper.loop();
        throw new RuntimeException("Main thread loop unexpectedly exited");
    }
```

