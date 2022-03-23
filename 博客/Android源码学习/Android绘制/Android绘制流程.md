# Android绘制流程

## 一,setContentView后怎么显示出来的

我们知道`setContentView`操作他主要做了一下几点

- 创建`DecorView`
- 添加`window`和`decorView`的依赖关系
- 通过我们设置的`xml`对控件创建

我们知道视图真正显示是在`ActivityThread`类中`handleResumeActivity`方法里的`activity.makeVisible()`实现，其实进行`onMeasure`，`onLayout`,`onDraw`的过程也是在`handleResumeActivity`方法中

```
public void handleResumeActivity(IBinder token, boolean finalStateRequest, boolean isForward,
        String reason) {


    //1.1进行分发onReStart和onResume的方法
    final ActivityClientRecord r = performResumeActivity(token, finalStateRequest, reason);
    final Activity a = r.activity;

    if (r.window == null && !a.mFinished && willBeVisible) {
        r.window = r.activity.getWindow();
        View decor = r.window.getDecorView();
        decor.setVisibility(View.INVISIBLE);
        ViewManager wm = a.getWindowManager();
        WindowManager.LayoutParams l = r.window.getAttributes();
        a.mDecor = decor;
   
        if (a.mVisibleFromClient) {
            if (!a.mWindowAdded) {
                a.mWindowAdded = true;
                //1.2Activity第一执行会将decorView添加到WindowManager中
                wm.addView(decor, l);
            } else {
                a.onWindowAttributesChanged(l);
            }
        }

    } else if (!willBeVisible) {
        r.hideForNow = true;
    }

    if (!r.activity.mFinished && willBeVisible && r.activity.mDecor != null && !r.hideForNow) {
       WindowManager.LayoutParams l = r.window.getAttributes();
            if (r.activity.mVisibleFromClient) {
                ViewManager wm = a.getWindowManager();
                View decor = r.window.getDecorView();
                //1.3重新执行OnMeasure,onLayout,onDraw流程
                wm.updateViewLayout(decor, l);
            }
        }

        r.activity.mVisibleFromServer = true;
        mNumVisibleActivities++;
        if (r.activity.mVisibleFromClient) {
            //1.4视图显示出来
            r.activity.makeVisible();
        }
    }

    r.nextIdle = mNewActivities;
    mNewActivities = r;
    if (localLOGV) Slog.v(TAG, "Scheduling idle handler for " + r);
    Looper.myQueue().addIdleHandler(new Idler());
}
```

`handlerResumeActivity`方法中如果`Activity`的状态是`Stop`会触发`reStart`的状态，如果是`start`的状态会出`start`可以跟进`handlerResumeActivity`代码，如果`decorview`如果没有被加载进`windowManager`中就进行加载操作然后`makevisible`进行显示给用户

### wm.addView

windowManager实现类是WindowManagerImp

```
//WindowManagerImpl.java
public void addView(@NonNull View view, @NonNull ViewGroup.LayoutParams params) {
    applyDefaultToken(params);
    mGlobal.addView(view, params, mContext.getDisplay(), mParentWindow);
}

//WindowManagerGlobal.java
    private final ArrayList<View> mViews = new ArrayList<View>();
    private final ArrayList<ViewRootImpl> mRoots = new ArrayList<ViewRootImpl>();
    private final ArrayList<WindowManager.LayoutParams> mParams =
            new ArrayList<WindowManager.LayoutParams>();
  public void addView(View view, ViewGroup.LayoutParams params,
            Display display, Window parentWindow) {
        final WindowManager.LayoutParams wparams = (WindowManager.LayoutParams) params;
        ViewRootImpl root;
        View panelParentView = null;
        //1.2.1创建一个ViewRootImp对象
		root = new ViewRootImpl(view.getContext(), display);
		//1.2.2进行视图onMeasure,onLayout,onDraw
		view.setLayoutParams(wparams);
		//1.2.3对应对象添加到对应集合中
		mViews.add(view);
        mRoots.add(root);
        mParams.add(wparams);
        }
    }
    
   //View.java    
    public void setLayoutParams(ViewGroup.LayoutParams params) {      
        mLayoutParams = params;
        resolveLayoutParams();
        if (mParent instanceof ViewGroup) {
            ((ViewGroup) mParent).onSetLayoutParams(this, params);
        }
        //1.2.4进行onMeasure,onLayout,onDraw     
        requestLayout();
    }
    
```

### requestLayout

```
@Override
public void requestLayout() {
    if (!mHandlingLayoutInLayoutRequest) {
        //判断主线程
        checkThread();
        mLayoutRequested = true;
        //核心代码
        scheduleTraversals();
    }
}
```

`reuqestLayout`会验证当前线程是否是主线程接着跟踪`scheduleTraversals`

```
void scheduleTraversals() {
    if (!mTraversalScheduled) {
        mTraversalScheduled = true;
         //1.2.5发送异步屏障
        mTraversalBarrier = mHandler.getLooper().getQueue().postSyncBarrier();
        //1.2.6通过Choreographer发送一个CALLBACK_TRAVERSAL行为runable对象
        mChoreographer.postCallback(
                Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null);
        if (!mUnbufferedInputDispatch) {
            scheduleConsumeBatchedInput();
        }
        notifyRendererOfFramePending();
        pokeDrawLockIfNeeded();
    }
}
```

通过`Choreographer`发送一个`mTraversalRunnable`

```
final class TraversalRunnable implements Runnable {
    @Override
    public void run() {
        doTraversal();
    }
}
```

`mTraversalRunnable`是实现`Runable`接口的对象进行回调`doTraversal`进行对`View`的`onMeasure`，`onLayout`，`onDraw`

```
//Choreographer.java
public void postCallback(int callbackType, Runnable action, Object token) {
    postCallbackDelayed(callbackType, action, token, 0);
}

public void postCallbackDelayed(int callbackType,
            Runnable action, Object token, long delayMillis) {                
        postCallbackDelayedInternal(callbackType, action, token, delayMillis);
}

  private void postCallbackDelayedInternal(int callbackType,
            Object action, Object token, long delayMillis) { 
        synchronized (mLock) {
            final long now = SystemClock.uptimeMillis();
            final long dueTime = now + delayMillis;
            mCallbackQueues[callbackType].addCallbackLocked(dueTime, action, token);

            if (dueTime <= now) {
                scheduleFrameLocked(now);
            } else {
                Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_CALLBACK, action);
                msg.arg1 = callbackType;
                msg.setAsynchronous(true);
                //1.2.7发送一个handle事件标识MSG_DO_SCHEDULE_CALLBACK
                mHandler.sendMessageAtTime(msg, dueTime);
            }
        }
    }
   /**1.2.7
    *FrameHandler.java
    */
   private final class FrameHandler extends Handler {
        public FrameHandler(Looper looper) {
            super(looper);
        }

        @Override
        public void handleMessage(Message msg) {
            switch (msg.what) {
                case MSG_DO_FRAME:
                   //收到同步信号后的处理函数，也就是帧处理函数
                    doFrame(System.nanoTime(), 0);
                    break;
                case MSG_DO_SCHEDULE_VSYNC:
                      //请求垂直同步信号
                    doScheduleVsync();
                    break;
                case MSG_DO_SCHEDULE_CALLBACK:
                 //1.2.8 跟踪.....
                 doScheduleCallback(msg.arg1);
                    break;
            }
        }
    }
    
        void doScheduleCallback(int callbackType) {
        synchronized (mLock) {
            if (!mFrameScheduled) {
                final long now = SystemClock.uptimeMillis();
                if (mCallbackQueues[callbackType].hasDueCallbacksLocked(now)) {
                    scheduleFrameLocked(now);
                }
            }
        }
    }
    
      private void scheduleFrameLocked(long now) {
        if (!mFrameScheduled) {
            mFrameScheduled = true;
            if (USE_VSYNC) {
                if (isRunningOnLooperThreadLocked()) {
                    scheduleVsyncLocked();
                } else {
                   //1.2.9 发送一个异步vsync事件
                    Message msg = mHandler.obtainMessage(MSG_DO_SCHEDULE_VSYNC);
                    msg.setAsynchronous(true);
                    mHandler.sendMessageAtFrontOfQueue(msg);
                }
            } else {
                final long nextFrameTime = Math.max(
                        mLastFrameTimeNanos / TimeUtils.NANOS_PER_MS + sFrameDelay, now);
                if (DEBUG_FRAMES) {
                    Log.d(TAG, "Scheduling next frame in " + (nextFrameTime - now) + " ms.");
                }
                Message msg = mHandler.obtainMessage(MSG_DO_FRAME);
                msg.setAsynchronous(true);
                mHandler.sendMessageAtTime(msg, nextFrameTime);
            }
        }
    }
    
    
    void doScheduleVsync() {
        synchronized (mLock) {
            if (mFrameScheduled) {
               //1.3.0跟踪...
                scheduleVsyncLocked();
            }
        }
    }
    
    
      private void scheduleVsyncLocked() {
        //1.3.1  跟踪...
        mDisplayEventReceiver.scheduleVsync();
    }
       //Schedules a single vertical sync pulse to be delivered when the next display frame begins.
      public void scheduleVsync() {
            //1.3.2 根据翻译理解 注册一个垂直信号这个信号带有屏幕刷新的频率
            nativeScheduleVsync(mReceiverPtr);
        
    }
    
```

总结:**Choreographer向native层注册垂直信号**

### FrameDisplayEventReceiver

FrameDisplayEventReceiver:回调底层传过来的行为

```
//DisplayEventReceiver.java
  //接受底层传递过来的事件
  public DisplayEventReceiver(Looper looper) {
        this(looper, VSYNC_SOURCE_APP);
    }

//Choreographer的匿名类FrameDisplayEventReceiver.java
  public void onVsync(long timestampNanos, long physicalDisplayId, int frame) {              
            mTimestampNanos = timestampNanos;
            mFrame = frame;
            Message msg = Message.obtain(mHandler, this);
            msg.setAsynchronous(true);
            //继续发送handle事件 msg.what未赋值默认0
            mHandler.sendMessageAtTime(msg, timestampNanos / TimeUtils.NANOS_PER_MS);
        }

```

接受底层事件后发送handler事件

```
private final class FrameHandler extends Handler {
    public FrameHandler(Looper looper) {
        super(looper);
    }

    @Override
    public void handleMessage(Message msg) {
        switch (msg.what) {
            case MSG_DO_FRAME:
                //进入doFrame
                doFrame(System.nanoTime(), 0);
                break;
            case MSG_DO_SCHEDULE_VSYNC:
                doScheduleVsync();
                break;
            case MSG_DO_SCHEDULE_CALLBACK:
                doScheduleCallback(msg.arg1);
                break;
        }
    }
}
```

进入doFrame逻辑

```
void doFrame(long frameTimeNanos, int frame) {
    synchronized (mLock) {
        if (!mFrameScheduled) {
            return; // no work to do
        }
 
         //送帧的时间
        long intendedFrameTimeNanos = frameTimeNanos;
        //记录处理开始的时间
        startNanos = System.nanoTime();
        //计算这段时间差
        final long jitterNanos = startNanos - frameTimeNanos;
         //判断是否出现Jank
        if (jitterNanos >= mFrameIntervalNanos) {
            final long skippedFrames = jitterNanos / mFrameIntervalNanos;
            //如果超过30帧延期处理就打印log有严重耗时任务未处理
            if (skippedFrames >= SKIPPED_FRAME_WARNING_LIMIT) {
                Log.i(TAG, "Skipped " + skippedFrames + " frames!  "
                        + "The application may be doing too much work on its main thread.");
            }
            final long lastFrameOffset = jitterNanos % mFrameIntervalNanos;
             //处理时间-上次事件处理时间
            frameTimeNanos = startNanos - lastFrameOffset;
        }
         //可能是丢事件的情况 重新注册垂直信号
        if (frameTimeNanos < mLastFrameTimeNanos) {
            if (DEBUG_JANK) {
                Log.d(TAG, "Frame time appears to be going backwards.  May be due to a "
                        + "previously skipped frame.  Waiting for next vsync.");
            }
            scheduleVsyncLocked();
            return;
        }

        if (mFPSDivisor > 1) {
            long timeSinceVsync = frameTimeNanos - mLastFrameTimeNanos;
            if (timeSinceVsync < (mFrameIntervalNanos * mFPSDivisor) && timeSinceVsync > 0) {
                scheduleVsyncLocked();
                return;
            }
        }

        mFrameInfo.setVsync(intendedFrameTimeNanos, frameTimeNanos);
        mFrameScheduled = false;
        mLastFrameTimeNanos = frameTimeNanos;
    }

    try {
        //开始处理任务
        Trace.traceBegin(Trace.TRACE_TAG_VIEW, "Choreographer#doFrame");
        AnimationUtils.lockAnimationClock(frameTimeNanos / TimeUtils.NANOS_PER_MS);

        mFrameInfo.markInputHandlingStart();
        doCallbacks(Choreographer.CALLBACK_INPUT, frameTimeNanos);

        mFrameInfo.markAnimationsStart();
        doCallbacks(Choreographer.CALLBACK_ANIMATION, frameTimeNanos);
        doCallbacks(Choreographer.CALLBACK_INSETS_ANIMATION, frameTimeNanos);

        mFrameInfo.markPerformTraversalsStart();
        //我们追踪的事件
        doCallbacks(Choreographer.CALLBACK_TRAVERSAL, frameTimeNanos);

        doCallbacks(Choreographer.CALLBACK_COMMIT, frameTimeNanos);
    } finally {
        AnimationUtils.unlockAnimationClock();
        Trace.traceEnd(Trace.TRACE_TAG_VIEW);
    }

    if (DEBUG_FRAMES) {
        final long endNanos = System.nanoTime();
        Log.d(TAG, "Frame " + frame + ": Finished, took "
                + (endNanos - startNanos) * 0.000001f + " ms, latency "
                + (startNanos - frameTimeNanos) * 0.000001f + " ms.");
    }
}
```

这块逻辑主要在真正处理事件前做的一些事情

1.打印丢帧数据

2.事件回溯的情况重新注册垂直信号

3.开始处理任务

```
void doCallbacks(int callbackType, long frameTimeNanos) {
    CallbackRecord callbacks;
    synchronized (mLock) {
        final long now = System.nanoTime();
        //找到Choreographer.CALLBACK_TRAVERSAL这类任务数据集合
        callbacks = mCallbackQueues[callbackType].extractDueCallbacksLocked(
                now / TimeUtils.NANOS_PER_MS);
        if (callbacks == null) {
            return;
        }
        mCallbacksRunning = true;
   
    try {
        Trace.traceBegin(Trace.TRACE_TAG_VIEW, CALLBACK_TRACE_TITLES[callbackType]);
        for (CallbackRecord c = callbacks; c != null; c = c.next) {
            if (DEBUG_FRAMES) {
                Log.d(TAG, "RunCallback: type=" + callbackType
                        + ", action=" + c.action + ", token=" + c.token
                        + ", latencyMillis=" + (SystemClock.uptimeMillis() - c.dueTime));
            }
            //执行事件处理
            c.run(frameTimeNanos);
        }
    } finally {
        synchronized (mLock) {
            mCallbacksRunning = false;
            do {
                final CallbackRecord next = callbacks.next;
                recycleCallbackLocked(callbacks);
                callbacks = next;
            } while (callbacks != null);
        }
        Trace.traceEnd(Trace.TRACE_TAG_VIEW);
    }
}
```

 c.run(frameTimeNanos);就是执行Choreographer对象的mTraversalRunnable事件doTraversal()

```
private void performTraversals() {
    // cache mView since it is used so much below...
    final View host = mView;

    if (DBG) {
        System.out.println("======================================");
        System.out.println("performTraversals");
        host.debug();
    }

    if (host == null || !mAdded)
        return;

    mIsInTraversal = true;
    mWillDrawSoon = true;
    boolean windowSizeMayChange = false;
    boolean surfaceChanged = false;
    WindowManager.LayoutParams lp = mWindowAttributes;

    int desiredWindowWidth;
    int desiredWindowHeight;

    final int viewVisibility = getHostVisibility();
    final boolean viewVisibilityChanged = !mFirst
            && (mViewVisibility != viewVisibility || mNewSurfaceNeeded
            // Also check for possible double visibility update, which will make current
            // viewVisibility value equal to mViewVisibility and we may miss it.
            || mAppVisibilityChanged);
    mAppVisibilityChanged = false;
    final boolean viewUserVisibilityChanged = !mFirst &&
            ((mViewVisibility == View.VISIBLE) != (viewVisibility == View.VISIBLE));

    WindowManager.LayoutParams params = null;
    if (mWindowAttributesChanged) {
        mWindowAttributesChanged = false;
        surfaceChanged = true;
        params = lp;
    }
    CompatibilityInfo compatibilityInfo =
            mDisplay.getDisplayAdjustments().getCompatibilityInfo();
    if (compatibilityInfo.supportsScreen() == mLastInCompatMode) {
        params = lp;
        mFullRedrawNeeded = true;
        mLayoutRequested = true;
        if (mLastInCompatMode) {
            params.privateFlags &= ~WindowManager.LayoutParams.PRIVATE_FLAG_COMPATIBLE_WINDOW;
            mLastInCompatMode = false;
        } else {
            params.privateFlags |= WindowManager.LayoutParams.PRIVATE_FLAG_COMPATIBLE_WINDOW;
            mLastInCompatMode = true;
        }
    }

    mWindowAttributesChangesFlag = 0;

    Rect frame = mWinFrame;
    if (mFirst) {
        mFullRedrawNeeded = true;
        mLayoutRequested = true;

        final Configuration config = mContext.getResources().getConfiguration();
        if (shouldUseDisplaySize(lp)) {
            // NOTE -- system code, won't try to do compat mode.
            Point size = new Point();
            mDisplay.getRealSize(size);
            desiredWindowWidth = size.x;
            desiredWindowHeight = size.y;
        } else {
            desiredWindowWidth = mWinFrame.width();
            desiredWindowHeight = mWinFrame.height();
        }

        // We used to use the following condition to choose 32 bits drawing caches:
        // PixelFormat.hasAlpha(lp.format) || lp.format == PixelFormat.RGBX_8888
        // However, windows are now always 32 bits by default, so choose 32 bits
        mAttachInfo.mUse32BitDrawingCache = true;
        mAttachInfo.mWindowVisibility = viewVisibility;
        mAttachInfo.mRecomputeGlobalAttributes = false;
        mLastConfigurationFromResources.setTo(config);
        mLastSystemUiVisibility = mAttachInfo.mSystemUiVisibility;
        // Set the layout direction if it has not been set before (inherit is the default)
        if (mViewLayoutDirectionInitial == View.LAYOUT_DIRECTION_INHERIT) {
            host.setLayoutDirection(config.getLayoutDirection());
        }
        host.dispatchAttachedToWindow(mAttachInfo, 0);
        mAttachInfo.mTreeObserver.dispatchOnWindowAttachedChange(true);
        dispatchApplyInsets(host);
    } else {
        desiredWindowWidth = frame.width();
        desiredWindowHeight = frame.height();
        if (desiredWindowWidth != mWidth || desiredWindowHeight != mHeight) {
            if (DEBUG_ORIENTATION) Log.v(mTag, "View " + host + " resized to: " + frame);
            mFullRedrawNeeded = true;
            mLayoutRequested = true;
            windowSizeMayChange = true;
        }
    }

    if (viewVisibilityChanged) {
        mAttachInfo.mWindowVisibility = viewVisibility;
        host.dispatchWindowVisibilityChanged(viewVisibility);
        if (viewUserVisibilityChanged) {
            host.dispatchVisibilityAggregated(viewVisibility == View.VISIBLE);
        }
        if (viewVisibility != View.VISIBLE || mNewSurfaceNeeded) {
            endDragResizing();
            destroyHardwareResources();
        }
        if (viewVisibility == View.GONE) {
            // After making a window gone, we will count it as being
            // shown for the first time the next time it gets focus.
            mHasHadWindowFocus = false;
        }
    }

    // Non-visible windows can't hold accessibility focus.
    if (mAttachInfo.mWindowVisibility != View.VISIBLE) {
        host.clearAccessibilityFocus();
    }

    // Execute enqueued actions on every traversal in case a detached view enqueued an action
    getRunQueue().executeActions(mAttachInfo.mHandler);

    boolean insetsChanged = false;

    boolean layoutRequested = mLayoutRequested && (!mStopped || mReportNextDraw);
    if (layoutRequested) {

        final Resources res = mView.getContext().getResources();

        if (mFirst) {
            // make sure touch mode code executes by setting cached value
            // to opposite of the added touch mode.
            mAttachInfo.mInTouchMode = !mAddedTouchMode;
            ensureTouchModeLocally(mAddedTouchMode);
        } else {
            if (!mPendingOverscanInsets.equals(mAttachInfo.mOverscanInsets)) {
                insetsChanged = true;
            }
            if (!mPendingContentInsets.equals(mAttachInfo.mContentInsets)) {
                insetsChanged = true;
            }
            if (!mPendingStableInsets.equals(mAttachInfo.mStableInsets)) {
                insetsChanged = true;
            }
            if (!mPendingDisplayCutout.equals(mAttachInfo.mDisplayCutout)) {
                insetsChanged = true;
            }
            if (!mPendingVisibleInsets.equals(mAttachInfo.mVisibleInsets)) {
                mAttachInfo.mVisibleInsets.set(mPendingVisibleInsets);
                if (DEBUG_LAYOUT) Log.v(mTag, "Visible insets changing to: "
                        + mAttachInfo.mVisibleInsets);
            }
            if (!mPendingOutsets.equals(mAttachInfo.mOutsets)) {
                insetsChanged = true;
            }
            if (mPendingAlwaysConsumeSystemBars != mAttachInfo.mAlwaysConsumeSystemBars) {
                insetsChanged = true;
            }
            if (lp.width == ViewGroup.LayoutParams.WRAP_CONTENT
                    || lp.height == ViewGroup.LayoutParams.WRAP_CONTENT) {
                windowSizeMayChange = true;

                if (shouldUseDisplaySize(lp)) {
                    // NOTE -- system code, won't try to do compat mode.
                    Point size = new Point();
                    mDisplay.getRealSize(size);
                    desiredWindowWidth = size.x;
                    desiredWindowHeight = size.y;
                } else {
                    Configuration config = res.getConfiguration();
                    desiredWindowWidth = dipToPx(config.screenWidthDp);
                    desiredWindowHeight = dipToPx(config.screenHeightDp);
                }
            }
        }

        // Ask host how big it wants to be
        windowSizeMayChange |= measureHierarchy(host, lp, res,
                desiredWindowWidth, desiredWindowHeight);
    }
```