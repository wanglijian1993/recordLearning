# Input启动

SystemServer启动的InputManagerService服务并设置wms的InputMonitor对象

```
 //1.创建InputManagerService对象
 inputManager = new InputManagerService(context);
 inputManager.setWindowManagerCallbacks(wm.getInputMonitor());
 //2.启动
 inputManager.start();
```

## 1.创建InputManagerService

```
    public InputManagerService(Context context) {
        this.mContext = context;
       //创建运行在线程"android.display"的handler对象
       this.mHandler = new InputManagerHandler(DisplayThread.get().getLooper());
        //1.1 native层创建一个NativeInputManager对象返回到java层指针
        mPtr = nativeInit(this, mContext, mHandler.getLooper().getQueue());
           
        LocalServices.addService(InputManagerInternal.class, new LocalService());
    }
```

```
 static jlong nativeInit(JNIEnv* env, jclass /* clazz */,
        jobject serviceObj, jobject contextObj, jobject messageQueueObj) {
     //获取MessageQuque->对应native层的
    sp<MessageQueue> messageQueue = android_os_MessageQueue_getMessageQueue(env, messageQueueObj);
    if (messageQueue == NULL) {
        jniThrowRuntimeException(env, "MessageQueue is not initialized.");
        return 0;
    }
    //1.1创建NativeInputManager
    NativeInputManager* im = new NativeInputManager(contextObj, serviceObj,
            messageQueue->getLooper());
    im->incStrong(0);
    return reinterpret_cast<jlong>(im);
}


sp<MessageQueue> android_os_MessageQueue_getMessageQueue(JNIEnv* env, jobject messageQueueObj) {
    //取出java对象保存在C++中的地址   
    jlong ptr = env->GetLongField(messageQueueObj, gMessageQueueClassInfo.mPtr);
    return reinterpret_cast<NativeMessageQueue*>(ptr);
}
```

### 1.1 NativeInputManager

```
NativeInputManager::NativeInputManager(jobject contextObj,
        jobject serviceObj, const sp<Looper>& looper) :
        mLooper(looper), mInteractive(true) {
    JNIEnv* env = jniEnv();
    //创建Native层的context对应InputManagerService中的Context
    mContextObj = env->NewGlobalRef(contextObj);
    //创建native层的InputManagerService中的InputManagerService对象
    mServiceObj = env->NewGlobalRef(serviceObj);

    { 
        //锁的参数
        AutoMutex _l(mLock);
        mLocked.systemUiVisibility = ASYSTEM_UI_VISIBILITY_STATUS_BAR_VISIBLE;
        mLocked.pointerSpeed = 0;
        mLocked.pointerGesturesEnabled = true;
        mLocked.showTouches = false;
    }
    mInteractive = true;
    //2.0创建EventHub 
    sp<EventHub> eventHub = new EventHub();
    //1.2创建InputManager
     mInputManager = new InputManager(eventHub, this, this);
}
```

### 1.2 创建InputManager

```
InputManager::InputManager(
        const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& readerPolicy,
        const sp<InputDispatcherPolicyInterface>& dispatcherPolicy) {
    //1.3创建InputDispatcher并传入IMS接口回调  
    mDispatcher = new InputDispatcher(dispatcherPolicy);
    //1.4创建Inputreader并传递IMS接口回调和mDispatcher对象
    mReader = new InputReader(eventHub, readerPolicy, mDispatcher);
    initialize();
}
void InputManager::initialize() {
    //创建InputReaderThread和InputDispacherThread线程
    mReaderThread = new InputReaderThread(mReader);
    mDispatcherThread = new InputDispatcherThread(mDispatcher);
}
```

### 1.3EventHub

```
EventHub::EventHub(void) :
        mBuiltInKeyboardId(NO_BUILT_IN_KEYBOARD), mNextDeviceId(1), mControllerNumbers(),
        mOpeningDevices(0), mClosingDevices(0),
        mNeedToSendFinishedDeviceScan(false),
        mNeedToReopenDevices(false), mNeedToScanDevices(true),
        mPendingEventCount(0), mPendingEventIndex(0), mPendingINotify(false) {
    acquire_wake_lock(PARTIAL_WAKE_LOCK, WAKE_LOCK_ID);
    //创建epoll句柄容量8 
    mEpollFd = epoll_create(EPOLL_SIZE_HINT);
    //获取/dev/input文件句柄
    mINotifyFd = inotify_init();
     //DEVICE_PATH=‘dev/input’ 监听DEVICE_PATH设备
    int result = inotify_add_watch(mINotifyFd, DEVICE_PATH, IN_DELETE | IN_CREATE);
    //创建eventItem
    struct epoll_event eventItem;
    memset(&eventItem, 0, sizeof(eventItem));
    eventItem.events = EPOLLIN;
    eventItem.data.u32 = EPOLL_ID_INOTIFY;
    //添加INotify到epoll实例
    result = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, mINotifyFd, &eventItem);
    //创建管道
    int wakeFds[2];
    result = pipe(wakeFds);
    //服务的
    mWakeReadPipeFd = wakeFds[0];
     //用户端
    mWakeWritePipeFd = wakeFds[1];

    //将pipe的读和写都设置为非阻塞方式
    result = fcntl(mWakeReadPipeFd, F_SETFL, O_NONBLOCK);
    result = fcntl(mWakeWritePipeFd, F_SETFL, O_NONBLOCK);
    

    eventItem.data.u32 = EPOLL_ID_WAKE;
    //添加管道的读端到epoll实例
    result = epoll_ctl(mEpollFd, EPOLL_CTL_ADD, mWakeReadPipeFd, &eventItem);
  
    int major, minor;
    getLinuxRelease(&major, &minor);
    mUsingEpollWakeup = major > 3 || (major == 3 && minor >= 5);
}
```

### 1.4 InputDispatcher

```
InputDispatcher::InputDispatcher(const sp<InputDispatcherPolicyInterface>& policy) :
    mPolicy(policy),
    mPendingEvent(NULL), mLastDropReason(DROP_REASON_NOT_DROPPED),
    mAppSwitchSawKeyDown(false), mAppSwitchDueTime(LONG_LONG_MAX),
    mNextUnblockedEvent(NULL),
    mDispatchEnabled(false), mDispatchFrozen(false), mInputFilterEnabled(false),
    mInputTargetWaitCause(INPUT_TARGET_WAIT_CAUSE_NONE) {
    //InputDispatcher对象中创建一个Looper
    mLooper = new Looper(false);

    mKeyRepeatState.lastKeyEntry = NULL;
    //获取分发超时参数
    policy->getDispatcherConfiguration(&mConfig);
}
```

### 1.5 InputReader

```
InputReader::InputReader(const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& policy,
        const sp<InputListenerInterface>& listener) :
        mContext(this), mEventHub(eventHub), mPolicy(policy),
        mGlobalMetaState(0), mGeneration(1),
        mDisableVirtualKeysTimeout(LLONG_MIN), mNextTimeout(LLONG_MAX),
        mConfigurationChangesToRefresh(0) {
    // 创建输入监听对象    
    mQueuedListener = new QueuedInputListener(listener);

    { 
        AutoMutex _l(mLock);

        refreshConfigurationLocked(0);
        updateGlobalMetaStateLocked();
    } 
}
```

总结:java层通过jni创建NativeInputManager对象并返回指针保存在java层并返回指针。

 创建三个线程java层 InputManagerHandler线程 native层InputReaderThread和InputDIspatcherThread



