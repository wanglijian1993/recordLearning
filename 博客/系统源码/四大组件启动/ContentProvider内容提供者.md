# ContentProvider内容提供者

**内容提供者是Android四大组件之一主要提供给其他app自己app内部的内容**

```
获取ContentResolver对象
content.getContentResolver()
核心功能:增删改查
insert
query
delete
update
```

## 1.注册

通过PMS解析清单文件注册到PackageParse内部静态类Package的providers集合

```
 public final ArrayList<Provider> providers = new ArrayList<Provider>(0);
```

## 2.content.getContentResolver().query()

```
//创建ApplicationContentResolver对象
mContentResolver = new ApplicationContentResolver(this, mainThread, user);

public ContentResolver getContentResolver() {
        return mContentResolver;
}

    //query()调用的
    public final @Nullable Cursor query(final @NonNull Uri uri, @Nullable String[] projection,
            @Nullable String selection, @Nullable String[] selectionArgs,
            @Nullable String sortOrder, @Nullable CancellationSignal cancellationSignal) {
        Preconditions.checkNotNull(uri, "uri");
        //2.1通过传递的uri获取IContentProvider对象
        IContentProvider unstableProvider = acquireUnstableProvider(uri);
        if (unstableProvider == null) {
            return null;
        }
        IContentProvider stableProvider = null;
        Cursor qCursor = null;
        try {
            long startTime = SystemClock.uptimeMillis();

            ICancellationSignal remoteCancellationSignal = null;
            if (cancellationSignal != null) {
                cancellationSignal.throwIfCanceled();
                remoteCancellationSignal = unstableProvider.createCancellationSignal();
                cancellationSignal.setRemote(remoteCancellationSignal);
            }
            try {
                qCursor = unstableProvider.query(mPackageName, uri, projection,
                        selection, selectionArgs, sortOrder, remoteCancellationSignal);
            } catch (DeadObjectException e) {
                // The remote process has died...  but we only hold an unstable
                // reference though, so we might recover!!!  Let's try!!!!
                // This is exciting!!1!!1!!!!1
                unstableProviderDied(unstableProvider);
                stableProvider = acquireProvider(uri);
                if (stableProvider == null) {
                    return null;
                }
                qCursor = stableProvider.query(mPackageName, uri, projection,
                        selection, selectionArgs, sortOrder, remoteCancellationSignal);
            }
            if (qCursor == null) {
                return null;
            }

            // Force query execution.  Might fail and throw a runtime exception here.
            qCursor.getCount();
            long durationMillis = SystemClock.uptimeMillis() - startTime;
            maybeLogQueryToEventLog(durationMillis, uri, projection, selection, sortOrder);

            // Wrap the cursor object into CursorWrapperInner object.
            CursorWrapperInner wrapper = new CursorWrapperInner(qCursor,
                    stableProvider != null ? stableProvider : acquireProvider(uri));
            stableProvider = null;
            qCursor = null;
            return wrapper;
        } catch (RemoteException e) {
            // Arbitrary and not worth documenting, as Activity
            // Manager will kill this process shortly anyway.
            return null;
        } finally {
            if (qCursor != null) {
                qCursor.close();
            }
            if (cancellationSignal != null) {
                cancellationSignal.setRemote(null);
            }
            if (unstableProvider != null) {
                releaseUnstableProvider(unstableProvider);
            }
            if (stableProvider != null) {
                releaseProvider(stableProvider);
            }
        }
    }
```

### 2.1 acquireUnstableProvider(uri)

```
    public final IContentProvider acquireUnstableProvider(Uri uri) {
        if (!SCHEME_CONTENT.equals(uri.getScheme())) {
            return null;
        }
        String auth = uri.getAuthority();
        if (auth != null) {
            //2.2ContentResover的抽象方法找子类实现
            return acquireUnstableProvider(mContext, uri.getAuthority());
        }
        return null;
    }
```

### 2.2 acquireUnstableProvider

```
        protected IContentProvider acquireUnstableProvider(Context c, String auth) {
            //2.3 调用ActivityThread的acuireProvider方法
            return mMainThread.acquireProvider(c,
                    ContentProvider.getAuthorityWithoutUserId(auth),
                    resolveUserIdFromAuthority(auth), false);
        }
```

### 2.3 acquireProvider

```
    public final IContentProvider acquireProvider(
            Context c, String auth, int userId, boolean stable) {
        //2.4通过获取获取IContentProvider对象     
        final IContentProvider provider = acquireExistingProvider(c, auth, userId, stable);
        if (provider != null) {
            return provider;
        }
        IActivityManager.ContentProviderHolder holder = null;
        try {
            //2.5 没有缓存区AMS获取
            holder = ActivityManagerNative.getDefault().getContentProvider(
                    getApplicationThread(), auth, userId, stable);
        } catch (RemoteException ex) {
        }

        holder = installProvider(c, holder, holder.info,
                true /*noisy*/, holder.noReleaseNeeded, stable);
        return holder.provider;
    }
```

### 2.4 acquireExistingProvider

```
    public final IContentProvider acquireExistingProvider(
            Context c, String auth, int userId, boolean stable) {
        synchronized (mProviderMap) {
            final ProviderKey key = new ProviderKey(auth, userId);
            //通过mProviderMap集合获取ProviderClientRecord对象(缓存机制)
            final ProviderClientRecord pr = mProviderMap.get(key);
            if (pr == null) {
                return null;
            }

            IContentProvider provider = pr.mProvider;
            IBinder jBinder = provider.asBinder();
            //jBinder的进程是否存活
            if (!jBinder.isBinderAlive()) {
                //清除缓存对象
                handleUnstableProviderDiedLocked(jBinder, true);
                //返回null
                return null;
            }
            //获取跨进程的缓存对象 ProviderRefCount
            ProviderRefCount prc = mProviderRefCountMap.get(jBinder);
            if (prc != null) {
                incProviderRefLocked(prc, stable);
            }
            return provider;
        }
    }
```

### 2.5 getContentProvider

```
    public final ContentProviderHolder getContentProvider(
            IApplicationThread caller, String name, int userId, boolean stable) {
        enforceNotIsolatedCaller("getContentProvider");
        //调用线程的caller对象空抛异常
        if (caller == null) {
            String msg = "null IApplicationThread when getting content provider "
                    + name;
            Slog.w(TAG, msg);
            throw new SecurityException(msg);
        }     
        return getContentProviderImpl(caller, name, null, stable, userId);
    }
    
    private final ContentProviderHolder getContentProviderImpl(IApplicationThread caller,
            String name, IBinder token, boolean stable, int userId) {
        ContentProviderRecord cpr;
        ContentProviderConnection conn = null;
        ProviderInfo cpi = null;

        synchronized(this) {
            long startTime = SystemClock.elapsedRealtime();
            //获取调用者进程
            ProcessRecord r = null;
            if (caller != null) {
                r = getRecordForAppLocked(caller);           
            }

            boolean checkCrossUser = true;

            checkTime(startTime, "getContentProviderImpl: getProviderByName");

            //通过mPriverMap缓存获取cpr
            cpr = mProviderMap.getProviderByName(name, userId);
             //如果有缓存并且userid不等于USER_OWNER
            if (cpr == null && userId != UserHandle.USER_OWNER) {
                //替换cpr内容提供者包装对象
                cpr = mProviderMap.getProviderByName(name, UserHandle.USER_OWNER);
                if (cpr != null) {
                    cpi = cpr.info;
                    if (isSingleton(cpi.processName, cpi.applicationInfo,
                            cpi.name, cpi.flags)
                            && isValidSingletonCall(r.uid, cpi.applicationInfo.uid)) {
                        userId = UserHandle.USER_OWNER;
                        checkCrossUser = false;
                    } else {
                        cpr = null;
                        cpi = null;
                    }
                }
            }

            boolean providerRunning = cpr != null;
             //cpr存活
            if (providerRunning) {
                cpi = cpr.info;
                String msg;
                checkTime(startTime, "getContentProviderImpl: before checkContentProviderPermission");
               
                checkTime(startTime, "getContentProviderImpl: after checkContentProviderPermission");
                //2.5.1设置provider参数multiprocess设置true或者同一进程
                if (r != null && cpr.canRunHere(r)) {
                    ContentProviderHolder holder = cpr.newHolder(null);
                    holder.provider = null;
                    //直接返回holder
                    return holder;
                }

                final long origId = Binder.clearCallingIdentity();

                checkTime(startTime, "getContentProviderImpl: incProviderCountLocked");

                //2.5.2非统一进程创建conn可跨进程的对象               
                conn = incProviderCountLocked(r, cpr, token, stable);
                if (conn != null && (conn.stableCount+conn.unstableCount) == 1) {
                    if (cpr.proc != null && r.setAdj <= ProcessList.PERCEPTIBLE_APP_ADJ) {
                        checkTime(startTime, "getContentProviderImpl: before updatLruProcess");
                        updateLruProcessLocked(cpr.proc, false, null);
                        checkTime(startTime, "getContentProviderImpl: after updateLruProcess");
                    }
                }

                if (cpr.proc != null) {
                    if (false) {
                        if (cpr.name.flattenToShortString().equals(
                                "com.android.providers.calendar/.CalendarProvider2")) {
                            Slog.v(TAG, "****************** KILLING "
                                + cpr.name.flattenToShortString());
                            Process.killProcess(cpr.proc.pid);
                        }
                    }
                    checkTime(startTime, "getContentProviderImpl: before updateOomAdj");
                    boolean success = updateOomAdjLocked(cpr.proc);
                    maybeUpdateProviderUsageStatsLocked(r, cpr.info.packageName, name);
                    checkTime(startTime, "getContentProviderImpl: after updateOomAdj");
                    if (!success) {
                        Slog.i(TAG, "Existing provider " + cpr.name.flattenToShortString()
                                + " is crashing; detaching " + r);
                        boolean lastRef = decProviderCountLocked(conn, cpr, token, stable);
                        checkTime(startTime, "getContentProviderImpl: before appDied");
                        appDiedLocked(cpr.proc);
                        checkTime(startTime, "getContentProviderImpl: after appDied");
                        if (!lastRef) {
                            return null;
                        }
                        providerRunning = false;
                        conn = null;
                    }
                }

                Binder.restoreCallingIdentity(origId);
            }

            boolean singleton;
            //没有运行第一次
            if (!providerRunning) {
                try {
                    checkTime(startTime, "getContentProviderImpl: before resolveContentProvider");
                    //通过ams查询注册的provider
                    cpi = AppGlobals.getPackageManager().
                        resolveContentProvider(name,
                            STOCK_PM_FLAGS | PackageManager.GET_URI_PERMISSION_PATTERNS, userId);
                    checkTime(startTime, "getContentProviderImpl: after resolveContentProvider");
                } catch (RemoteException ex) {
                }
                if (cpi == null) {
                    return null;
                }
                //实例化singleton 
                singleton = isSingleton(cpi.processName, cpi.applicationInfo,
                        cpi.name, cpi.flags)
                        && isValidSingletonCall(r.uid, cpi.applicationInfo.uid);
                if (singleton) {
                    userId = UserHandle.USER_OWNER;
                }
                cpi.applicationInfo = getAppInfoForUser(cpi.applicationInfo, userId);
                checkTime(startTime, "getContentProviderImpl: got app info for user");

        
                checkTime(startTime, "getContentProviderImpl: after checkContentProviderPermission");
                //分装componentName
                ComponentName comp = new ComponentName(cpi.packageName, cpi.name);
                checkTime(startTime, "getContentProviderImpl: before getProviderByClass");
                //从mProviderMap查询cpr
                cpr = mProviderMap.getProviderByClass(comp, userId);
                checkTime(startTime, "getContentProviderImpl: after getProviderByClass");
                final boolean firstClass = cpr == null;
                // 第一次false
                if (firstClass) {
                    final long ident = Binder.clearCallingIdentity();
                    try {
                        checkTime(startTime, "getContentProviderImpl: before getApplicationInfo");
                        ApplicationInfo ai =
                            AppGlobals.getPackageManager().
                                getApplicationInfo(
                                        cpi.applicationInfo.packageName,
                                        STOCK_PM_FLAGS, userId);
                        checkTime(startTime, "getContentProviderImpl: after getApplicationInfo");
                        if (ai == null) {
                            Slog.w(TAG, "No package info for content provider "
                                    + cpi.name);
                            return null;
                        }
                        ai = getAppInfoForUser(ai, userId);
                        cpr = new ContentProviderRecord(this, cpi, ai, comp, singleton);
                    } catch (RemoteException ex) {
                        // pm is in same process, this will never happen.
                    } finally {
                        Binder.restoreCallingIdentity(ident);
                    }
                }

                checkTime(startTime, "getContentProviderImpl: now have ContentProviderRecord");
                //如果不需要跨进程直接返回
                if (r != null && cpr.canRunHere(r)) {
                    //不需要跨进程不需要conn对象
                    return cpr.newHolder(null);
                }
                //启动的providers
                final int N = mLaunchingProviders.size();
                int i;
                for (i = 0; i < N; i++) {
                    if (mLaunchingProviders.get(i) == cpr) {
                        break;
                    }
                }
                 //如果没有provider   
                if (i >= N) {
                    final long origId = Binder.clearCallingIdentity();

                    try {
                        // Content provider is now in use, its package can't be stopped.
                        try {
                            checkTime(startTime, "getContentProviderImpl: before set stopped state");
                            AppGlobals.getPackageManager().setPackageStoppedState(
                                    cpr.appInfo.packageName, false, userId);
                            checkTime(startTime, "getContentProviderImpl: after set stopped state");
                        } catch (RemoteException e) {
                        } catch (IllegalArgumentException e) {
                            Slog.w(TAG, "Failed trying to unstop package "
                                    + cpr.appInfo.packageName + ": " + e);
                        }
             
                        checkTime(startTime, "getContentProviderImpl: looking for process record");
                        //查询cpi对应进程 
                        ProcessRecord proc = getProcessRecordLocked(
                                cpi.processName, cpr.appInfo.uid, false);
                        //判断是否启动的进程
                        if (proc != null && proc.thread != null) {
                            if (DEBUG_PROVIDER) Slog.d(TAG_PROVIDER,
                                    "Installing in existing process " + proc);
                            if (!proc.pubProviders.containsKey(cpi.name)) {
                                checkTime(startTime, "getContentProviderImpl: scheduling install");
                                proc.pubProviders.put(cpi.name, cpr);
                                try {
                                    proc.thread.scheduleInstallProvider(cpi);
                                } catch (RemoteException e) {
                                }
                            }
                        } else {
                            checkTime(startTime, "getContentProviderImpl: before start process"); 
                            //启动进程 内部会遍历清单文件查询需要启动的四大组件 
                            proc = startProcessLocked(cpi.processName,
                                    cpr.appInfo, false, 0, "content provider",
                                    new ComponentName(cpi.applicationInfo.packageName,
                                            cpi.name), false, false, false);
                            checkTime(startTime, "getContentProviderImpl: after start process");
                            if (proc == null) {
                                Slog.w(TAG, "Unable to launch app "
                                        + cpi.applicationInfo.packageName + "/"
                                        + cpi.applicationInfo.uid + " for provider "
                                        + name + ": process is bad");
                                return null;
                            }
                        }
                        cpr.launchingApp = proc;
                        mLaunchingProviders.add(cpr);
                    } finally {
                        Binder.restoreCallingIdentity(origId);
                    }
                }

                checkTime(startTime, "getContentProviderImpl: updating data structures");

             
                if (firstClass) {
                    mProviderMap.putProviderByClass(comp, cpr);
                }
                //添加缓存
                mProviderMap.putProviderByName(name, cpr);
                conn = incProviderCountLocked(r, cpr, token, stable);
                if (conn != null) {
                    conn.waiting = true;
                }
            }
            checkTime(startTime, "getContentProviderImpl: done!");
        }

        
        synchronized (cpr) {
            while (cpr.provider == null) {
                if (cpr.launchingApp == null) {
                    Slog.w(TAG, "Unable to launch app "
                            + cpi.applicationInfo.packageName + "/"
                            + cpi.applicationInfo.uid + " for provider "
                            + name + ": launching app became null");
                    EventLog.writeEvent(EventLogTags.AM_PROVIDER_LOST_PROCESS,
                            UserHandle.getUserId(cpi.applicationInfo.uid),
                            cpi.applicationInfo.packageName,
                            cpi.applicationInfo.uid, name);
                    return null;
                }
                try {
                    if (DEBUG_MU) Slog.v(TAG_MU,
                            "Waiting to start provider " + cpr
                            + " launchingApp=" + cpr.launchingApp);
                    if (conn != null) {
                        conn.waiting = true;
                    }
                  //等待进程里面的对象创建 
                 cpr.wait();
                } catch (InterruptedException ex) {
                } finally {
                    if (conn != null) {
                        conn.waiting = false;
                    }
                }
            }
        }
        //返回
        return cpr != null ? cpr.newHolder(conn) : null;
    }

    
```

#### 2.5.1 canRunHere

```
 public boolean canRunHere(ProcessRecord app) {       
        return (info.multiprocess || info.processName.equals(app.processName))
                && uid == app.info.uid;
    }
```

#### 2.5.2 incProviderCountLocked

```
    //可跨进程的对象
    public final class ContentProviderConnection extends Binder {
    //provider封装对象
    public final ContentProviderRecord provider;
    //进程
    public final ProcessRecord client;
    public final long createTime;
    public int stableCount;
    public int unstableCount;
    // The client of this connection is currently waiting for the provider to appear.
    // Protected by the provider lock.
    public boolean waiting;
    // The provider of this connection is now dead.
    public boolean dead;

    // For debugging.
    public int numStableIncs;
    public int numUnstableIncs;
    
    public ContentProviderConnection(ContentProviderRecord _provider, ProcessRecord _client) {
        provider = _provider;
        client = _client;
        createTime = SystemClock.elapsedRealtime();
    }
    
    }
```

总结:

注册:

内容提供者是通过PMS解析xml读取信息封装成prvider对象

查询:

通过ContextImpl实现类查询getContentResolver,ContentResolver对象获取先通过binder到AMS服务中去查询对应provider是否缓存如果有缓存直接返回

没有缓存判断清单文件是否设置了multiprocess=true参数 如果设置了就创建对应Context对象就可以通过类加载机制去获取Provider相关代码，

如果设置process参数需要跨进程就会创建进程然后再创建provider，

这个过程会调用wait等待，等待创建完成后ntoityAll进行通知创建完成在返回

如果不需要跨进程直接返回conn跨进程对象为null

