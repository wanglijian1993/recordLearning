# AMS启动

## 1.入口

SystemServer.java->startBootstrapServices()



```
 private void startBootstrapServices() {
         //1.1创建AMS 
        mActivityManagerService = mSystemServiceManager.startService(
                ActivityManagerService.Lifecycle.class).getService();
        mActivityManagerService.setSystemServiceManager(mSystemServiceManager);
        mActivityManagerService.setInstaller(installer);
        //2.0 注册服务
        mActivityManagerService.setSystemProcess();
    }
    
    private void startOtherServices() {
       //3.0 AMS调用systemReady
      mActivityManagerService.systemReady(new Runnable() {
            @Override
            public void run() {
                Slog.i(TAG, "Making services ready");
                mSystemServiceManager.startBootPhase(
                        SystemService.PHASE_ACTIVITY_MANAGER_READY);

                try {
                    mActivityManagerService.startObservingNativeCrashes();
                } catch (Throwable e) {
                    reportWtf("observing native crashes", e);
                }
                //启动WebView
                WebViewFactory.prepareWebViewInSystemServer();

                try {
                    //4.0启动SystemUi 服务
                    startSystemUi(context);
                } catch (Throwable e) {
                    reportWtf("starting System UI", e);
                }
               / 调用服务的 systemReady 方法
                  ...
             
        });
    }
    
```

## 1.1mSystemServiceManager.startService

```
   public <T extends SystemService> T startService(Class<T> serviceClass) {
        final String name = serviceClass.getName();
        final T service;
        try {
            //通过类加载去创建ActivityManagerService.Lifecycle.class构造方法并实例化
            Constructor<T> constructor = serviceClass.getConstructor(Context.class);
            service = constructor.newInstance(mContext);
        } catch (InstantiationException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service could not be instantiated", ex);
        } catch (IllegalAccessException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service must have a public constructor with a Context argument", ex);
        } catch (NoSuchMethodException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service must have a public constructor with a Context argument", ex);
        } catch (InvocationTargetException ex) {
            throw new RuntimeException("Failed to create service " + name
                    + ": service constructor threw an exception", ex);
        }

        // 添加到SystemService数组集合中
        mServices.add(service);

         
        try {
            // 1.2 Lifecycle.onstart()
            service.onStart();
        } catch (RuntimeException ex) {
            throw new RuntimeException("Failed to start service " + name
                    + ": onStart threw an exception", ex);
        }
        return service;
    }
```

## 1.2 service.onStart()

```
    public static final class Lifecycle extends SystemService {
        private final ActivityManagerService mService;

        public Lifecycle(Context context) {
            super(context);
            //1.3 实例化AMS
            mService = new ActivityManagerService(context);
        }

        @Override
        public void onStart() {
            //1.4 ActivityManagerService.start()
            mService.start();
        }

        public ActivityManagerService getService() {
            return mService;
        }
    }
```

```
   public ActivityManagerService(Context systemContext) {
        mContext = systemContext;
        mFactoryTest = FactoryTest.getMode();
        //主线程
        mSystemThread = ActivityThread.currentActivityThread();
         //ServiceThread 其实是HandlerThread
        mHandlerThread = new ServiceThread(TAG,
                android.os.Process.THREAD_PRIORITY_FOREGROUND, false /*allowIo*/);
        mHandlerThread.start();
        //获取主线程Handler
        mHandler = new MainHandler(mHandlerThread.getLooper());
        /创建名为"android.ui"的线程
        mUiHandler = new UiHandler();
        
        mFgBroadcastQueue = new BroadcastQueue(this, mHandler,
                "foreground", BROADCAST_FG_TIMEOUT, false);
        mBgBroadcastQueue = new BroadcastQueue(this, mHandler,
                "background", BROADCAST_BG_TIMEOUT, true);
        mBroadcastQueues[0] = mFgBroadcastQueue;
        mBroadcastQueues[1] = mBgBroadcastQueue;

        mServices = new ActiveServices(this);
        mProviderMap = new ProviderMap(this);

        
        File dataDir = Environment.getDataDirectory();
        File systemDir = new File(dataDir, "system");
        systemDir.mkdirs();
        mBatteryStatsService = new BatteryStatsService(systemDir, mHandler);
        mBatteryStatsService.getActiveStatistics().readLocked();
        mBatteryStatsService.scheduleWriteToDisk();
        mOnBattery = DEBUG_POWER ? true
                : mBatteryStatsService.getActiveStatistics().getIsOnBattery();
        mBatteryStatsService.getActiveStatistics().setCallback(this);

        mProcessStats = new ProcessStatsService(this, new File(systemDir, "procstats"));

        mAppOpsService = new AppOpsService(new File(systemDir, "appops.xml"), mHandler);

        mGrantFile = new AtomicFile(new File(systemDir, "urigrants.xml"));

        
        mStartedUsers.put(UserHandle.USER_OWNER, new UserState(UserHandle.OWNER, true));
        mUserLru.add(UserHandle.USER_OWNER);
        updateStartedUserArrayLocked();

        GL_ES_VERSION = SystemProperties.getInt("ro.opengles.version",
            ConfigurationInfo.GL_ES_VERSION_UNDEFINED);

        mTrackingAssociations = "1".equals(SystemProperties.get("debug.track-associations"));

        mConfiguration.setToDefaults();
        mConfiguration.setLocale(Locale.getDefault());

        mConfigurationSeq = mConfiguration.seq = 1;
        //CPU使用情况的追踪器执行初始化
        mProcessCpuTracker.init();

        mCompatModePackages = new CompatModePackages(this, systemDir, mHandler);
        mIntentFirewall = new IntentFirewall(new IntentFirewallInterface(), mHandler);
        mRecentTasks = new RecentTasks(this);
           // 创建ActivityStackSupervisor对象
        mStackSupervisor = new ActivityStackSupervisor(this, mRecentTasks);
        mTaskPersister = new TaskPersister(systemDir, mStackSupervisor, mRecentTasks);
        //创建名为"CpuTracker"的线程
        mProcessCpuThread = new Thread("CpuTracker") {
            @Override
            public void run() {
                while (true) {
                    try {
                        try {
                            synchronized(this) {
                                final long now = SystemClock.uptimeMillis();
                                long nextCpuDelay = (mLastCpuTime.get()+MONITOR_CPU_MAX_TIME)-now;
                                long nextWriteDelay = (mLastWriteTime+BATTERY_STATS_TIME)-now;
                                //Slog.i(TAG, "Cpu delay=" + nextCpuDelay
                                //        + ", write delay=" + nextWriteDelay);
                                if (nextWriteDelay < nextCpuDelay) {
                                    nextCpuDelay = nextWriteDelay;
                                }
                                if (nextCpuDelay > 0) {
                                    mProcessCpuMutexFree.set(true);
                                    this.wait(nextCpuDelay);
                                }
                            }
                        } catch (InterruptedException e) {
                        }
                        updateCpuStatsNow();
                    } catch (Exception e) {
                        Slog.e(TAG, "Unexpected exception collecting process stats", e);
                    }
                }
            }
        };

        Watchdog.getInstance().addMonitor(this);
        Watchdog.getInstance().addThread(mHandler);
    }
```

## 1.4 mService.start()

```
    private void start() {
        //移除进程组
        Process.removeAllProcessGroups();
         //启动CpuTracker线程
        mProcessCpuThread.start();
        //启动电池统计服务
        mBatteryStatsService.publish(mContext);
        mAppOpsService.publish(mContext);
         //添加到LocalServices中
        LocalServices.addService(ActivityManagerInternal.class, new LocalService());
    }
```

## 2.0 setSystemProcess()

```
public void setSystemProcess() {
    try {
        ServiceManager.addService(Context.ACTIVITY_SERVICE, this, true);
        ServiceManager.addService(ProcessStats.SERVICE_NAME, mProcessStats);
        ServiceManager.addService("meminfo", new MemBinder(this));
        ServiceManager.addService("gfxinfo", new GraphicsBinder(this));
        ServiceManager.addService("dbinfo", new DbBinder(this));
        if (MONITOR_CPU_USAGE) {
            ServiceManager.addService("cpuinfo", new CpuBinder(this));
        }
        ServiceManager.addService("permission", new PermissionController(this));
        ServiceManager.addService("processinfo", new ProcessInfoService(this));
        ApplicationInfo info = mContext.getPackageManager().getApplicationInfo(
                "android", STOCK_PM_FLAGS);
         //2.1
        mSystemThread.installSystemApplicationInfo(info, getClass().getClassLoader());
        synchronized (this) {
            //创建ProcessRecord对象
            ProcessRecord app = newProcessRecordLocked(info, info.processName, false, 0);
            app.persistent = true; //设置为persistent进程
            app.pid = MY_PID;
            app.maxAdj = ProcessList.SYSTEM_ADJ;
            app.makeActive(mSystemThread.getApplicationThread(), mProcessStats);
            synchronized (mPidsSelfLocked) {
                mPidsSelfLocked.put(app.pid, app);
            }
            updateLruProcessLocked(app, false, null);//维护进程lru
            updateOomAdjLocked(); //更新adj
        }
    } catch (PackageManager.NameNotFoundException e) {
        throw new RuntimeException("", e);
    }
}
```

## 2.1 installSystemApplicationInfo

```
public void installSystemApplicationInfo(ApplicationInfo info, ClassLoader classLoader) {
    synchronized (this) {
        getSystemContext().installSystemApplicationInfo(info, classLoader);
        mProfiler = new Profiler();    //创建用于性能统计的Profiler对象
    }
}
```

## 3.0 systemReady


        public void systemReady(final Runnable goingCallback) {
            ...
            // 执行 Callback 的 run 方法
            if (goingCallback != null) goingCallback.run();
            // Start up initial activity.
            mBooting = true;
            // 启动桌面 Activity 进程
            startHomeActivityLocked(mCurrentUserId, "systemReady");
    }

## 4.0 startSystemUi

```
static final void startSystemUi(Context context) {
    Intent intent = new Intent();
    intent.setComponent(new ComponentName("com.android.systemui",
                "com.android.systemui.SystemUIService"));
    context.startServiceAsUser(intent, UserHandle.OWNER);
}
```

AMS负责启动启动四大组件，用 setSystemProcess 方法中会向 ServcieManager 进程额外发布一些服务：procstats(进程信息)、meminfo(内存信息)、gfxinfo(图形信息)、cpuinfo(cpu信息)、permission(权限)、processinfo(应用使用情况)等；调用 systemReady 方法首先会启动 SystemUIService，然后执行一系列服务的 systemReady 和 systemRunning 方法，最后启动桌面 Activity 进程。


