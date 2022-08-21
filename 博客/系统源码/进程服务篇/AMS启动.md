# AMS启动

## 1.AMS入口

SystemServer.java->startBootstrapServices()

```
 private void startBootstrapServices() {
      
        Installer installer = mSystemServiceManager.startService(Installer.class);

       //2创建一个AMS对象
        mActivityManagerService = mSystemServiceManager.startService(
                ActivityManagerService.Lifecycle.class).getService();
        //设置AMS的系统服务管理管理器      
        mActivityManagerService.setSystemServiceManager(mSystemServiceManager);
        //设置AMS的APP安装器
        mActivityManagerService.setInstaller(installer);

        mPowerManagerService = mSystemServiceManager.startService(PowerManagerService.class);
        //初始化AMS相关的PMS 
        mActivityManagerService.initPowerManagement();

        ....
        //3 setSystemProcess
        mActivityManagerService.setSystemProcess();

    }

    public void startOtherServices(){
       //4 AMS.调用systemReady
       mActivityManagerService.systemReady(new Runnable() {
            @Override
            public void run() {
             //启动WebView
             WebViewFactory.prepareWebViewInSystemServer();
             //启动系统ui
             startSystemUi(context);          
             Watchdog.getInstance().start();
             // 执行一系列服务的systemReady方法
            networkScoreF.systemReady();
            networkManagementF.systemReady();
            networkStatsF.systemReady();
            networkPolicyF.systemReady();
            connectivityF.systemReady();
            audioServiceF.systemReady();
            Watchdog.getInstance().start(); //Watchdog开始工作
            //执行一系列服务的systemRunning方法
            wallpaper.systemRunning();
            inputMethodManager.systemRunning(statusBarF);
            location.systemRunning();
            countryDetector.systemRunning();
            networkTimeUpdater.systemRunning();
            commonTimeMgmtService.systemRunning();
            textServiceManagerService.systemRunning();
            assetAtlasService.systemRunning();
            inputManager.systemRunning();
            telephonyRegistry.systemRunning();
            mediaRouter.systemRunning();
            mmsService.systemRunning();
    }
                
                
```

## 2.mSystemServiceManager.startService

```
 public <T extends SystemService> T startService(Class<T> serviceClass) {
        final String name = serviceClass.getName();

        final T service;
        try {
            Constructor<T> constructor = serviceClass.getConstructor(Context.class);
            //2.1反射调用lifeCycle构造函数
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

        //注册到SSM中
        mServices.add(service);

   
        try {
            //2.2LifeCycle start方法
            service.onStart();
        } catch (RuntimeException ex) {
            throw new RuntimeException("Failed to start service " + name
                    + ": onStart threw an exception", ex);
        }
        return service;
    }
```

### 2.1 constructor.newInstance(mContext)

```
        public Lifecycle(Context context) {
            super(context);
            mService = new ActivityManagerService(context);
        }
        
     //实力话AMS   
     public ActivityManagerService(Context systemContext) {
        mContext = systemContext;
        mFactoryTest = FactoryTest.getMode();
        //获取ActivityThread对象
        mSystemThread = ActivityThread.currentActivityThread();
        //创建名ActivityManager的前台线程，并获取mHandler
        mHandlerThread = new ServiceThread(TAG,
                android.os.Process.THREAD_PRIORITY_FOREGROUND, false /*allowIo*/);
        mHandlerThread.start();
        //创建MainHandler线程并且传递mHandlerThread的Looper
        mHandler = new MainHandler(mHandlerThread.getLooper());
        //创建UIHandler
        mUiHandler = new UiHandler();
        //创建前台广播 在运行超过10s将放弃执行
        mFgBroadcastQueue = new BroadcastQueue(this, mHandler,
                "foreground", BROADCAST_FG_TIMEOUT, false);
        //创建后台广播  在运行超过60s将放弃执行       
        mBgBroadcastQueue = new BroadcastQueue(this, mHandler,
                "background", BROADCAST_BG_TIMEOUT, true);
        mBroadcastQueues[0] = mFgBroadcastQueue;
        mBroadcastQueues[1] = mBgBroadcastQueue;
        //创建ActivityServices服务对象 其中非低内存手机mMaxStartingBackground为8
        mServices = new ActiveServices(this);
        mProviderMap = new ProviderMap(this);

        //创建app/system文件
        File dataDir = Environment.getDataDirectory();
        File systemDir = new File(dataDir, "system");
        systemDir.mkdirs();
        //电量服务
        mBatteryStatsService = new BatteryStatsService(systemDir, mHandler);
        mBatteryStatsService.getActiveStatistics().readLocked();
        mBatteryStatsService.scheduleWriteToDisk();
        mOnBattery = DEBUG_POWER ? true
                : mBatteryStatsService.getActiveStatistics().getIsOnBattery();
        mBatteryStatsService.getActiveStatistics().setCallback(this);
        //创建进程统计服务，信息保存在目录/data/system/procstats，
        mProcessStats = new ProcessStatsService(this, new File(systemDir, "procstats"));
        
        mAppOpsService = new AppOpsService(new File(systemDir, "appops.xml"), mHandler);

        mGrantFile = new AtomicFile(new File(systemDir, "urigrants.xml"));
  			// User 0是第一个，也是唯一的一个开机过程中运行的用户
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
        mStackSupervisor = new ActivityStackSupervisor(this, mRecentTasks);
        mTaskPersister = new TaskPersister(systemDir, mStackSupervisor, mRecentTasks);
        //创建CPU监控线程
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
        //Watchdog监控 
        Watchdog.getInstance().addMonitor(this);
        Watchdog.getInstance().addThread(mHandler);
    }
    
```

 AMS启动共创建了三个线程”ActivityManager”，”android.ui”，”CpuTracker”。

### 2.2service.onStart()

```
    private void start() {
        //移除全部进程组
        Process.removeAllProcessGroups();
        //启动CpuTracker监控线程
        mProcessCpuThread.start();
        //启动电量服务
        mBatteryStatsService.publish(mContext);
        mAppOpsService.publish(mContext);
        //创建LocalService，并添加到LocalServices 
        LocalServices.addService(ActivityManagerInternal.class, new LocalService());
    }
```

AMS对象创建的时候启动了二个ActivityManager”,”CpuTracker”线程并启动的电量监控服务

## 3.mActivityManagerService.setSystemProcess()

```
    public void setSystemProcess() {
        try {
            //通过binder添加一系列服务         
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
            //3.1installSystemApplicationInfo       
            mSystemThread.installSystemApplicationInfo(info, getClass().getClassLoader());

            synchronized (this) {
                //创建ProcessRecord对象
                ProcessRecord app = newProcessRecordLocked(info, info.processName, false, 0);
                app.persistent = true;
                app.pid = MY_PID;
                app.maxAdj = ProcessList.SYSTEM_ADJ;
                app.makeActive(mSystemThread.getApplicationThread(), mProcessStats);
                synchronized (mPidsSelfLocked) {
                    mPidsSelfLocked.put(app.pid, app);
                }
                updateLruProcessLocked(app, false, null);
                updateOomAdjLocked();
            }
        } catch (PackageManager.NameNotFoundException e) {
            throw new RuntimeException(
                    "Unable to find android system package", e);
        }
    }
```

调用 setSystemProcess 方法中会向 ServcieManager 进程额外发布一些服务：procstats(进程信息)、meminfo(内存信息)、gfxinfo(图形信息)、cpuinfo(cpu信息)、permission(权限)、processinfo(应用使用情况)。

### 3.1installSystemApplicationInfo

```
   public void installSystemApplicationInfo(ApplicationInfo info, ClassLoader classLoader) {
        synchronized (this) {
            //3.2
            getSystemContext().installSystemApplicationInfo(info, classLoader);
            //创建用于性能统计的Profiler对象
            mProfiler = new Profiler();
        }
    }
```

### 3.2installSystemApplicationInfo

```
    void installSystemApplicationInfo(ApplicationInfo info, ClassLoader classLoader) {
        assert info.packageName.equals("android");
        /将包名为"android"的应用信息保存到mApplicationInfo
        mApplicationInfo = info;
        mClassLoader = classLoader;
    }
```

## 4 SystemReady

```
 public void systemReady(final Runnable goingCallback) {
        synchronized(this) {
            //第一次mSystemReady=false
            if (mSystemReady) {
                if (goingCallback != null) {
                    goingCallback.run();
                }
                return;
            }
         //执行Runnable
         if (goingCallback != null) goingCallback.run();
         // Start up initial activity.
         mBooting = true;
         //4.1启动系统桌面app
         startHomeActivityLocked(mCurrentUserId, "systemReady");
        }
    }
```

### 4.1 startHomeActivityLocked

```
  boolean startHomeActivityLocked(int userId, String reason) {
        //4.1.1获取intent参数
        Intent intent = getHomeIntent();
        ActivityInfo aInfo =
            resolveActivityInfo(intent, STOCK_PM_FLAGS, userId);
        if (aInfo != null) {
            intent.setComponent(new ComponentName(
                    aInfo.applicationInfo.packageName, aInfo.name));
            aInfo = new ActivityInfo(aInfo);
            aInfo.applicationInfo = getAppInfoForUser(aInfo.applicationInfo, userId);
            ProcessRecord app = getProcessRecordLocked(aInfo.processName,
                    aInfo.applicationInfo.uid, true);
            if (app == null || app.instrumentationClass == null) {
                intent.setFlags(intent.getFlags() | Intent.FLAG_ACTIVITY_NEW_TASK);
                //4.1.2启动桌面系统
                mStackSupervisor.startHomeActivity(intent, aInfo, reason);
            }
        }

        return true;
    }
```

### 4.1.1getHomeIntent

```
   Intent getHomeIntent() {
        Intent intent = new Intent(mTopAction, mTopData != null ? Uri.parse(mTopData) : null);
        intent.setComponent(mTopComponent);
        if (mFactoryTest != FactoryTest.FACTORY_TEST_LOW_LEVEL) {
            intent.addCategory(Intent.CATEGORY_HOME);
        }
        return intent;
    }
```

### 4.1.2mStackSupervisor.startHomeActivity(intent, aInfo, reason)

```
   //启动桌面系统应用
   void startHomeActivity(Intent intent, ActivityInfo aInfo, String reason) {
        moveHomeStackTaskToTop(HOME_ACTIVITY_TYPE, reason);
        startActivityLocked(null /* caller */, intent, null /* resolvedType */, aInfo,
                null /* voiceSession */, null /* voiceInteractor */, null /* resultTo */,
                null /* resultWho */, 0 /* requestCode */, 0 /* callingPid */, 0 /* callingUid */,
                null /* callingPackage */, 0 /* realCallingPid */, 0 /* realCallingUid */,
                0 /* startFlags */, null /* options */, false /* ignoreTargetSecurity */,
                false /* componentSpecified */,
                null /* outActivity */, null /* container */,  null /* inTask */);
        //已经是显示
       if (inResumeTopActivity) {
            scheduleResumeTopActivities();
        }
    }
```

 AMS总结

1. 创建AMS实例对象，共创建了三个线程”ActivityManager”，”android.ui”，”CpuTracker”。
2. setSystemProcess：注册AMS、meminfo、cpuinfo等服务到ServiceManager。
3. installSystemProviderss，加载SettingsProvider。
4. 启动SystemUIService，调用一系列服务的systemReady()方法。