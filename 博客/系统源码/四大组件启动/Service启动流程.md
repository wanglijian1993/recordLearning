# Service启动流程

**服务四大组件之一主要提供一个前台看不见的服务或者服务进程进行一些行为操作**

## Activity启动服务流程分析

服务启动二种方式:

1.bindService方式:可以通过ServiceConnection与服务进行通信，如果需要跨进程通信需要借助AIDL

2.startService方式:直接开启一个服务(无交互)

```
bindService(Intent,serviceConnection, Service.BIND_AUTO_CREATE);
生命周期 ->onCreate->onBind
unbindService(Intent)
生命周期->unBind->onDestory
startService(Intent);
生命周期->onCreate->onStartConmmand
stopService(Intent);
生命周期->onDestory
```

## 源码分析

### 1 BindService

```
    public boolean bindService(Intent service, ServiceConnection conn,
            int flags) {
        return bindServiceCommon(service, conn, flags, Process.myUserHandle());
    }
    
    
        private boolean bindServiceCommon(Intent service, ServiceConnection conn, int flags,
            UserHandle user) {
        IServiceConnection sd;
        if (conn == null) {
            throw new IllegalArgumentException("connection is null");
        }
        if (mPackageInfo != null) {
           //IserviceConnection支持跨进程通讯对conn进行包裹sd的实例对象ServiceDispatcher   
            sd = mPackageInfo.getServiceDispatcher(conn, getOuterContext(),
                    mMainThread.getHandler(), flags);
        } else {
            throw new RuntimeException("Not supported in system context");
        }
        //判断targetSDKversion是否大于当前源码的版本
        validateServiceIntent(service);
        try {
            //获取token
            IBinder token = getActivityToken();
            if (token == null && (flags&BIND_AUTO_CREATE) == 0 && mPackageInfo != null
                    && mPackageInfo.getApplicationInfo().targetSdkVersion
                    < android.os.Build.VERSION_CODES.ICE_CREAM_SANDWICH) {
                flags |= BIND_WAIVE_PRIORITY;
            }
            service.prepareToLeaveProcess();
            //1.1通过binder获取AMS调用binderService
            int res = ActivityManagerNative.getDefault().bindService(
                mMainThread.getApplicationThread(), getActivityToken(), service,
                service.resolveTypeIfNeeded(getContentResolver()),
                sd, flags, getOpPackageName(), user.getIdentifier());
            if (res < 0) {
                throw new SecurityException(
                        "Not allowed to bind to service " + service);
            }
            return res != 0;
        } catch (RemoteException e) {
            throw new RuntimeException("Failure from system", e);
        }
    }
    
```

### 1.1bindService

```
    public int bindService(IApplicationThread caller, IBinder token, Intent service,
            String resolvedType, IServiceConnection connection, int flags, String callingPackage,
            int userId) throws TransactionTooLargeException {
        enforceNotIsolatedCaller("bindService");
        //同步锁 
        synchronized(this) {   
            //1.2调用ActiveServices对象的bindServiceLocked方法
            return mServices.bindServiceLocked(caller, token, service,
                    resolvedType, connection, flags, callingPackage, userId);
        }
    }
    
    
    
```

### 1.2 bindServiceLocked

```
   int bindServiceLocked(IApplicationThread caller, IBinder token, Intent service,
            String resolvedType, IServiceConnection connection, int flags,
            String callingPackage, int userId) throws TransactionTooLargeException {
        //获取caller所在的进程 
        final ProcessRecord callerApp = mAm.getRecordForAppLocked(caller);
         //没有创建进程抛出异常
        if (callerApp == null) {
            throw new SecurityException(
                    "Unable to find app for caller " + caller
                    + " (pid=" + Binder.getCallingPid()
                    + ") when binding service " + service);
        }
              
        ActivityRecord activity = null;
        if (token != null) {
            //获取当前Activity
            activity = ActivityRecord.isInStackLocked(token);
            if (activity == null) {
                Slog.w(TAG, "Binding with unknown activity: " + token);
                return 0;
            }
        }

        int clientLabel = 0;
        PendingIntent clientIntent = null;

        final boolean callerFg = callerApp.setSchedGroup != Process.THREAD_GROUP_BG_NONINTERACTIVE;

        ServiceLookupResult res =
            retrieveServiceLocked(service, resolvedType, callingPackage,
                    Binder.getCallingPid(), Binder.getCallingUid(), userId, true, callerFg);
        if (res == null) {
            return 0;
        }
        if (res.record == null) {
            return -1;
        }
        ServiceRecord s = res.record;

        final long origId = Binder.clearCallingIdentity();
 
         mAm.startAssociationLocked(callerApp.uid, callerApp.processName,
                    s.appInfo.uid, s.name, s.processName);

            AppBindRecord b = s.retrieveAppBindingLocked(service, callerApp);
           //activity调用bindService的一个记录对象
            ConnectionRecord c = new ConnectionRecord(b, activity,
                    connection, flags, clientLabel, clientIntent);
             
            IBinder binder = connection.asBinder();
            ArrayList<ConnectionRecord> clist = s.connections.get(binder);
            if (clist == null) {
                clist = new ArrayList<ConnectionRecord>();
                s.connections.put(binder, clist);
            }
            clist.add(c);
            b.connections.add(c);
            if (activity != null) {
                if (activity.connections == null) {
                    activity.connections = new HashSet<ConnectionRecord>();
                }
                activity.connections.add(c);
            }
            b.client.connections.add(c);
            if ((c.flags&Context.BIND_ABOVE_CLIENT) != 0) {
                b.client.hasAboveClient = true;
            }
            if (s.app != null) {
                updateServiceClientActivitiesLocked(s.app, c, true);
            }
            clist = mServiceConnections.get(binder);
            if (clist == null) {
                clist = new ArrayList<ConnectionRecord>();
                mServiceConnections.put(binder, clist);
            }
            clist.add(c);
            //判断bind服务的flag属性是否是BIND_AUTO_CREATE
            if ((flags&Context.BIND_AUTO_CREATE) != 0) {
                s.lastActivity = SystemClock.uptimeMillis();
                //2.调用service的oncreate入口
                if (bringUpServiceLocked(s, service.getFlags(), callerFg, false) != null) {
                    return 0;
                }
            }


            if (s.app != null && b.intent.received) {
                try {
                    //3.service已经启动调用ServiceConnection的onServiceConnected回调
                    c.conn.connected(s.name, b.intent.binder);
                } catch (Exception e) {
        
                }
                if (b.intent.apps.size() == 1 && b.intent.doRebind) {
                    //4.调用service对应的onBind方法
                    requestServiceBindingLocked(s, b.intent, callerFg, true);
                }
            } else if (!b.intent.requested) {
                requestServiceBindingLocked(s, b.intent, callerFg, false);
            }

            getServiceMap(s.userId).ensureNotStartingBackground(s);

        } finally {
            Binder.restoreCallingIdentity(origId);
        }

        return 1;
    }
```

## 2.bringUpServiceLocked

```
 private final String bringUpServiceLocked(ServiceRecord r, int intentFlags, boolean execInFg,
            boolean whileRestarting) throws TransactionTooLargeException {
        ....     
        try {
            //服务正在启动对应的应用不能关闭 
            AppGlobals.getPackageManager().setPackageStoppedState(
                    r.packageName, false, r.userId);
        } catch (RemoteException e) {
        } catch (IllegalArgumentException e) {
            Slog.w(TAG, "Failed trying to unstop package "
                    + r.packageName + ": " + e);
        }

        final boolean isolated = (r.serviceInfo.flags&ServiceInfo.FLAG_ISOLATED_PROCESS) != 0;
        final String procName = r.processName;
        ProcessRecord app;

        if (!isolated) {
            app = mAm.getProcessRecordLocked(procName, r.appInfo.uid, false);
            if (app != null && app.thread != null) {
                try {
                    app.addPackage(r.appInfo.packageName, r.appInfo.versionCode, mAm.mProcessStats);
                    //2.1继续跟进调用service的oncreate方法
                    realStartServiceLocked(r, app, execInFg);
                    return null;
                } catch (TransactionTooLargeException e) {
                    throw e;
                } catch (RemoteException e) {
                    Slog.w(TAG, "Exception when starting service " + r.shortName, e);
                }

                // If a dead object exception was thrown -- fall through to
                // restart the application.
            }
        } else {

            app = r.isolatedProc;
        }
      ....
        return null;
    }
```

### 2.1  realStartServiceLocked(r, app, execInFg)

```
  private final void realStartServiceLocked(ServiceRecord r,
            ProcessRecord app, boolean execInFg) throws RemoteException {

        r.app = app;
        r.restartTime = r.lastActivity = SystemClock.uptimeMillis();

        final boolean newService = app.services.add(r);
        bumpServiceExecutingLocked(r, execInFg, "create");
        mAm.updateLruProcessLocked(app, false, null);
        mAm.updateOomAdjLocked();

        boolean created = false;
        try {
            synchronized (r.stats.getBatteryStats()) {
                r.stats.startLaunchedLocked();
            }
            //压缩 
            mAm.ensurePackageDexOpt(r.serviceInfo.packageName);
            app.forceProcessStateUpTo(ActivityManager.PROCESS_STATE_SERVICE);
             //2.2调用ActivityThread的 scheduleCreateService方法
             app.thread.scheduleCreateService(r, r.serviceInfo,
                    mAm.compatibilityInfoForPackageLocked(r.serviceInfo.applicationInfo),
                    app.repProcState);
            r.postNotification();
            created = true;
        } catch (DeadObjectException e) {
            Slog.w(TAG, "Application dead when creating service " + r);
            mAm.appDiedLocked(app);
            throw e;
        } finally {
            if (!created) {
                // Keep the executeNesting count accurate.
                final boolean inDestroying = mDestroyingServices.contains(r);
                serviceDoneExecutingLocked(r, inDestroying, inDestroying);

                // Cleanup.
                if (newService) {
                    app.services.remove(r);
                    r.app = null;
                }

                // Retry.
                if (!inDestroying) {
                    scheduleServiceRestartLocked(r, false);
                }
            }
        }

    }
```

### 2.2 scheduleCreateService

```
        public final void scheduleCreateService(IBinder token,
                ServiceInfo info, CompatibilityInfo compatInfo, int processState) {
            updateProcessState(processState, false);
            CreateServiceData s = new CreateServiceData();
            s.token = token;
            s.info = info;
            s.compatInfo = compatInfo;
            //调用handler的code=CREATE_SERVICE传递CreateServiceData
            sendMessage(H.CREATE_SERVICE, s);
        }
```

#### 2.3 sendMessage

```
    private void handleCreateService(CreateServiceData data) {
        unscheduleGcIdler();

        LoadedApk packageInfo = getPackageInfoNoCheck(
                data.info.applicationInfo, data.compatInfo);
        Service service = null;
        try {
            //获取加载packageInfo对象的classLoader
            java.lang.ClassLoader cl = packageInfo.getClassLoader();
            //通过classLaoder进行加载启动的服务
            service = (Service) cl.loadClass(data.info.name).newInstance();
        } catch (Exception e) {
        }

        try {
            //创建上下文
            ContextImpl context = ContextImpl.createAppContext(this, packageInfo);
            //传递service对象
            context.setOuterContext(service);
            //单例获取application
            Application app = packageInfo.makeApplication(false, mInstrumentation);
            //调用对应service的attach传递对应参数只有attach方法调用完才能使用对用的context等属性
            service.attach(context, this, data.info.name, data.token, app,
                    ActivityManagerNative.getDefault());
            //调用服务的onCreate对象        
            service.onCreate();
            //存活的service存入mServices集合中
            mServices.put(data.token, service);
            try {
                ActivityManagerNative.getDefault().serviceDoneExecuting(
                        data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
            } catch (RemoteException e) {
                // nothing to do.
            }
        } catch (Exception e) {
        }
    }
```

## 3 c.conn.connected

最终会调用ActivityThread的H对象post一个Runable执行doConnected

```
       public void doConnected(ComponentName name, IBinder service) {
            ServiceDispatcher.ConnectionInfo old;
            ServiceDispatcher.ConnectionInfo info;

            synchronized (this) {
       
                old = mActiveConnections.get(name);
       
                if (service != null) {
                    mDied = false;
                    info = new ConnectionInfo();
                    info.binder = service;
                     //创建一个服务死亡监控
                    info.deathMonitor = new DeathMonitor(name, service);
                    try {
                        //链接存储到mActiveConnections集合中
                        mActiveConnections.put(name, info);
                    } catch (RemoteException e) {
                        mActiveConnections.remove(name);
                        return;
                    }

                } else {
                    //service为空移除对用链接
                    mActiveConnections.remove(name);
                }

                if (old != null) {
                    old.binder.unlinkToDeath(old.deathMonitor, 0);
                }
            }

            if (old != null) {
                mConnection.onServiceDisconnected(name);
            }
            if (service != null) {
                //服务不为null调用对用ServiceConnection的回调onServiceConnected
                mConnection.onServiceConnected(name, service);
            }
        }
```

## 4requestServiceBindingLocked

```
    private final boolean requestServiceBindingLocked(ServiceRecord r, IntentBindRecord i,
            boolean execInFg, boolean rebind) throws TransactionTooLargeException {
        if ((!i.requested || rebind) && i.apps.size() > 0) {
            try {
                bumpServiceExecutingLocked(r, execInFg, "bind");
                r.app.forceProcessStateUpTo(ActivityManager.PROCESS_STATE_SERVICE);
                //4.1调用service的bind方法
                r.app.thread.scheduleBindService(r, i.intent.getIntent(), rebind,
                        r.app.repProcState);
                if (!rebind) {
                    i.requested = true;
                }
                i.hasBound = true;
                i.doRebind = false;
            } catch (TransactionTooLargeException e) {
                // Keep the executeNesting count accurate.
                if (DEBUG_SERVICE) Slog.v(TAG_SERVICE, "Crashed while binding " + r, e);
                final boolean inDestroying = mDestroyingServices.contains(r);
                serviceDoneExecutingLocked(r, inDestroying, inDestroying);
                throw e;
            } catch (RemoteException e) {
                if (DEBUG_SERVICE) Slog.v(TAG_SERVICE, "Crashed while binding " + r);
                // Keep the executeNesting count accurate.
                final boolean inDestroying = mDestroyingServices.contains(r);
                serviceDoneExecutingLocked(r, inDestroying, inDestroying);
                return false;
            }
        }
        return true;
    }
```

### 4.1 scheduleBindService

```
        public final void scheduleBindService(IBinder token, Intent intent,
                boolean rebind, int processState) {
            updateProcessState(processState, false);
            BindServiceData s = new BindServiceData();
            s.token = token;
            s.intent = intent;
            s.rebind = rebind;
            //通过handler进行传递
            sendMessage(H.BIND_SERVICE, s);
        }
        
       case BIND_SERVICE:
            Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "serviceBind");
            //4.2
            handleBindService((BindServiceData)msg.obj);
            Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
              break;       
```

```
    private void handleBindService(BindServiceData data) {
        Service s = mServices.get(data.token);
        if (s != null) {
            try {
                data.intent.setExtrasClassLoader(s.getClassLoader());
                data.intent.prepareToEnterProcess();
                try {
                    if (!data.rebind) {
                        //调用对应服务的onBind
                        IBinder binder = s.onBind(data.intent);
                        ActivityManagerNative.getDefault().publishService(
                                data.token, data.intent, binder);
                    } else {
                        s.onRebind(data.intent);
                        ActivityManagerNative.getDefault().serviceDoneExecuting(
                                data.token, SERVICE_DONE_EXECUTING_ANON, 0, 0);
                    }
                    ensureJitEnabled();
                } catch (RemoteException ex) {
                }
            } catch (Exception e) {
                if (!mInstrumentation.onException(s, e)) {
                    throw new RuntimeException(
                            "Unable to bind to service " + s
                            + " with " + data.intent + ": " + e.toString(), e);
                }
            }
        }
    }
```

总结:流程

先通过ContextImpl->bindService->AMS(binder跨进程方式获得)->获取所在进程->通过类加载机制加载对应服务到内存中再调用ActivityThread.发送对用Handler调用内部管理的Service启动方法