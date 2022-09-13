# InputReader

上层调用InputManager的初始化和start()函数对应InputReader的初始化和start()函数

## 1.InputRedaer初始化

```
InputReader::InputReader(const sp<EventHubInterface>& eventHub,
        const sp<InputReaderPolicyInterface>& policy,
        const sp<InputListenerInterface>& listener) :
        mContext(this), mEventHub(eventHub), mPolicy(policy),
        mGlobalMetaState(0), mGeneration(1),
        mDisableVirtualKeysTimeout(LLONG_MIN), mNextTimeout(LLONG_MAX),
        mConfigurationChangesToRefresh(0) {
    mQueuedListener = new QueuedInputListener(listener);

    { // acquire lock
        AutoMutex _l(mLock);

        refreshConfigurationLocked(0);
        updateGlobalMetaStateLocked();
    } // release lock
}
```

2.loopOnce

```
void InputReader::loopOnce() {
    int32_t oldGeneration;
    int32_t timeoutMillis;
    bool inputDevicesChanged = false;
    //InputDeviceInfo队列
    Vector<I o> inputDevices;
    {  
        
        AutoMutex _l(mLock);
        //oldGeneration=1 
        oldGeneration = mGeneration;
        timeoutMillis = -1;
        // changes=0 
        uint32_t changes = mConfigurationChangesToRefresh;
        if (changes) {
            mConfigurationChangesToRefresh = 0;
            timeoutMillis = 0;
            refreshConfigurationLocked(changes);
        } else if (mNextTimeout != LLONG_MAX) {
            //获取当前时间
            nsecs_t now = systemTime(SYSTEM_TIME_MONOTONIC);
            timeoutMillis = toMillisecondTimeoutDelay(now, mNextTimeout);
        }
    }
    //2 从EventHub读取事件 EVENT_BUFFER_SIZE=256
    size_t count = mEventHub->getEvents(timeoutMillis, mEventBuffer, EVENT_BUFFER_SIZE);

    { 
        AutoMutex _l(mLock);
        //
        mReaderIsAliveCondition.broadcast();

        if (count) {
            //3 处理事件
            processEventsLocked(mEventBuffer, count);
        }

        if (mNextTimeout != LLONG_MAX) {
            nsecs_t now = systemTime(SYSTEM_TIME_MONOTONIC);
            if (now >= mNextTimeout) {
                mNextTimeout = LLONG_MAX;
                timeoutExpiredLocked(now);
            }
        }

        if (oldGeneration != mGeneration) {
            inputDevicesChanged = true;
            getInputDevicesLocked(inputDevices);
        }
    } 


    if (inputDevicesChanged) {
        mPolicy->notifyInputDevicesChanged(inputDevices);
    }
    //4发送事件到InputDispatcher
    mQueuedListener->flush();
}
```

`InputReader`三步骤

1.从`EventHub`读取消息

2.处理消息 

3.消息分发到`InputDispatcher`

## 2 getEvents

```
size_t EventHub::getEvents(int timeoutMillis, RawEvent* buffer, size_t bufferSize) {

    AutoMutex _l(mLock);
    
    struct input_event readBuffer[bufferSize];
    //传递的RawEvent
    RawEvent* event = buffer;
    size_t capacity = bufferSize;
    bool awoken = false;
    for (;;) {
        //获取当前消息后续处理ANR input时间5S
        nsecs_t now = systemTime(SYSTEM_TIME_MONOTONIC);

        //报告最后添加/删除的任何设备
        while (mClosingDevices) {
            Device* device = mClosingDevices;
            ALOGV("Reporting device closed: id=%d, name=%s\n",
                 device->id, device->path.string());
            mClosingDevices = device->next;
            event->when = now;
            event->deviceId = device->id == mBuiltInKeyboardId ? BUILT_IN_KEYBOARD_ID : device->id;
            event->type = DEVICE_REMOVED;
            event += 1;
            delete device;
            mNeedToSendFinishedDeviceScan = true;
        }
        //默认true 
        if (mNeedToScanDevices) {
            mNeedToScanDevices = false;
            //2.1扫描Devices
            scanDevicesLocked();
            mNeedToSendFinishedDeviceScan = true;
        }
        //有设备
        while (mOpeningDevices != NULL) {
           //获取设备的头节点
            Device* device = mOpeningDevices;
            mOpeningDevices = device->next;
            //给RawEvent赋值
            event->when = now;
            event->deviceId = device->id == mBuiltInKeyboardId ? 0 : device->id;
            //设备类型添加设备
            event->type = DEVICE_ADDED;
            event += 1;
            mNeedToSendFinishedDeviceScan = true;
            if (--capacity == 0) {
                break;
            }
        }
          //重新赋值 tupe类型改变成 FINISHED_DEVICE_SCAN
        if (mNeedToSendFinishedDeviceScan) {
            mNeedToSendFinishedDeviceScan = false;
           
            event->when = now;
            event->type = FINISHED_DEVICE_SCAN;
            event += 1;
            if (--capacity == 0) {
                break;
            }
        }

      
        bool deviceChanged = false;
        while (mPendingEventIndex < mPendingEventCount) {
            //从mPendingEventItems读取事件项
            const struct epoll_event& eventItem = mPendingEventItems[mPendingEventIndex++];
             
            //获取设备ID对应的设备 
            ssize_t deviceIndex = mDevices.indexOfKey(eventItem.data.u32);
            Device* device = mDevices.valueAt(deviceIndex);
            if (eventItem.events & EPOLLIN) {
                 //从设备中不断读取事件，放入到readBuffer
                int32_t readSize = read(device->fd, readBuffer,
                        sizeof(struct input_event) * capacity);
                 //设备已被移除则执行关闭操作        
                if (readSize == 0 || (readSize < 0 && errno == ENODEV)) {
                    deviceChanged = true;
                    closeDeviceLocked(device);
                }else {     
                    int32_t deviceId = device->id == mBuiltInKeyboardId ? 0 : device->id;
                    //事件数量 
                    size_t count = size_t(readSize) / sizeof(struct input_event);
                    for (size_t i = 0; i < count; i++) {
                        //获取readBuffer数据
                        struct input_event& iev = readBuffer[i];
                        //input_event事件封装成RawEvent事件
                        event->deviceId = deviceId;
                        event->type = iev.type;
                        event->code = iev.code;
                        event->value = iev.value;
                        event += 1;
                        capacity -= 1;
                    }
                    if (capacity == 0) {

                        mPendingEventIndex -= 1;
                        break;
                    }
                }
            } 
        }
         //释放锁
        mLock.unlock();
         //等待input事件的到来 
        int pollResult = epoll_wait(mEpollFd, mPendingEventItems, EPOLL_MAX_EVENTS, timeoutMillis);

        //锁
        mLock.lock();
       //返回所读事件的数量 
      return event - buffer;
}
```

EventHub中getEvents函数通过epoll机制实现监听dev/input下的设备，读出数据将input_event结构体转换成RawEvent结构体返回事件数量

### 2.1 scanDevicesLocked

```
void EventHub::scanDevicesLocked() {
    //DEVICE_PATH=/dev/input
    status_t res = scanDirLocked(DEVICE_PATH);
    if(res < 0) {
        ALOGE("scan dir failed for %s\n", DEVICE_PATH);
    }
    if (mDevices.indexOfKey(VIRTUAL_KEYBOARD_ID) < 0) {
        createVirtualKeyboardLocked();
    }
}

status_t EventHub::scanDirLocked(const char *dirname)
{
    char devname[PATH_MAX];
    char *filename;
    DIR *dir;
    struct dirent *de;
    //判断文件夹是否存在
    dir = opendir(dirname);
    if(dir == NULL)
        return -1;
    strcpy(devname, dirname);
    filename = devname + strlen(devname);
    *filename++ = '/';
    //读取/dev/input/目录下所有的设备节点
    while((de = readdir(dir))) {
        if(de->d_name[0] == '.' &&
           (de->d_name[1] == '\0' ||
            (de->d_name[1] == '.' && de->d_name[2] == '\0')))
            continue;
        //赋值    
        strcpy(filename, de->d_name);
        //2.2 打开Device设备
        openDeviceLocked(devname);
    }
    closedir(dir);
    return 0;
}
```

### 2.2 openDeviceLocked

```
status_t EventHub::openDeviceLocked(const char *devicePath) {
    char buffer[80];
    //打开设备文件
    int fd = open(devicePath, O_RDWR | O_CLOEXEC);
    if(fd < 0) {
        ALOGE("could not open %s, %s\n", devicePath, strerror(errno));
        return -1;
    }

    InputDeviceIdentifier identifier;

    //获取device的名字
    if(ioctl(fd, EVIOCGNAME(sizeof(buffer) - 1), &buffer) < 1) {
        //fprintf(stderr, "could not get device name for %s, %s\n", devicePath, strerror(errno));
    } else {
        buffer[sizeof(buffer) - 1] = '\0';
        identifier.name.setTo(buffer);
    }

    //过滤没用的设备
    for (size_t i = 0; i < mExcludedDevices.size(); i++) {
        const String8& item = mExcludedDevices.itemAt(i);
        if (identifier.name == item) {
            //close
            close(fd);
            return -1;
        }
    }

    //获取设备版本号
    int driverVersion;
    if(ioctl(fd, EVIOCGVERSION, &driverVersion)) {
        ALOGE("could not get driver version for %s, %s\n", devicePath, strerror(errno));
        close(fd);
        return -1;
    }

    //获取设备的inputId
    struct input_id inputId;
    if(ioctl(fd, EVIOCGID, &inputId)) {
        ALOGE("could not get device input id for %s, %s\n", devicePath, strerror(errno));
        close(fd);
        return -1;
    }
    //给identifier赋值
    identifier.bus = inputId.bustype;
    identifier.product = inputId.product;
    identifier.vendor = inputId.vendor;
    identifier.version = inputId.version;

    //未知
    if(ioctl(fd, EVIOCGPHYS(sizeof(buffer) - 1), &buffer) < 1) {
        //fprintf(stderr, "could not get location for %s, %s\n", devicePath, strerror(errno));
    } else {
        buffer[sizeof(buffer) - 1] = '\0';
        identifier.location.setTo(buffer);
    }

    //获取设备唯一标识
    if(ioctl(fd, EVIOCGUNIQ(sizeof(buffer) - 1), &buffer) < 1) {
        //fprintf(stderr, "could not get idstring for %s, %s\n", devicePath, strerror(errno));
    } else {
        buffer[sizeof(buffer) - 1] = '\0';
        identifier.uniqueId.setTo(buffer);
    }

    // 填充描述符
    assignDescriptorLocked(identifier);

    //设置fd为非阻塞方式
    if (fcntl(fd, F_SETFL, O_NONBLOCK)) {
        ALOGE("Error %d making device file descriptor non-blocking.", errno);
        close(fd);
        return -1;
    }

    //生成deviceId mNextDeviceId++方式
    int32_t deviceId = mNextDeviceId++;
    //创建一个Device
    Device* device = new Device(fd, deviceId, String8(devicePath), identifier);
    //加载设备配置参数 
    loadConfigurationLocked(device);



    //注册epoll
    struct epoll_event eventItem;
    memset(&eventItem, 0, sizeof(eventItem));

    eventItem.events = EPOLLIN;
    if (mUsingEpollWakeup) {
        eventItem.events |= EPOLLWAKEUP;
    }
    eventItem.data.u32 = deviceId;
    //添加设备监听 
    if (epoll_ctl(mEpollFd, EPOLL_CTL_ADD, fd, &eventItem)) {
        //添加失败删除设备
        delete device;
        return -1;
    }

    //2.3添加设备
    addDeviceLocked(device);
    return 0;
}
```

### 2.3 addDeviceLocked

```
void EventHub::addDeviceLocked(Device* device) {
    //添加mDevices键值对集合中
    mDevices.add(device->id, device);
    //放到链表的头节点
    device->next = mOpeningDevices;
    //device链表结构
    mOpeningDevices = device;
}
```



## 3 processEventsLocked

```
void InputReader::processEventsLocked(const RawEvent* rawEvents, size_t count) {
    for (const RawEvent* rawEvent = rawEvents; count;) {
        int32_t type = rawEvent->type;
        size_t batchSize = 1;
        if (type < EventHubInterface::FIRST_SYNTHETIC_EVENT) {
            int32_t deviceId = rawEvent->deviceId;
            while (batchSize < count) {
                if (rawEvent[batchSize].type >= EventHubInterface::FIRST_SYNTHETIC_EVENT
                        || rawEvent[batchSize].deviceId != deviceId) {
                    break;
                }
                //同一个设备
                batchSize += 1;
            }
            //3.2数据事件的处理
            processEventsForDeviceLocked(deviceId, rawEvent, batchSize);
        } else {
            switch (rawEvent->type) {
            case EventHubInterface::DEVICE_ADDED:
                //3.1添加设备
                addDeviceLocked(rawEvent->when, rawEvent->deviceId);
                break;
            case EventHubInterface::DEVICE_REMOVED:
                //移除设备
                removeDeviceLocked(rawEvent->when, rawEvent->deviceId);
                break;
            case EventHubInterface::FINISHED_DEVICE_SCAN:
                //扫描设备完成 
                handleConfigurationChangedLocked(rawEvent->when);
                break;
            default:
                ALOG_ASSERT(false);
                break;
            }
        }
        count -= batchSize;
        rawEvent += batchSize;
    }
}
```

### 3.1 addDeviceLocked

```
void InputReader::addDeviceLocked(nsecs_t when, int32_t deviceId) {
    ssize_t deviceIndex = mDevices.indexOfKey(deviceId);
     if (deviceIndex >= 0) {
        //已添加的相同设备则不再添加
       return;
    }
    //通过deviceId获取参数
    InputDeviceIdentifier identifier = mEventHub->getDeviceIdentifier(deviceId);  
    uint32_t classes = mEventHub->getDeviceClasses(deviceId);
    int32_t controllerNumber = mEventHub->getDeviceControllerNumber(deviceId);
    //3.1.1创建InputDevice对象里面封装的类型事件
    InputDevice* device = createDeviceLocked(deviceId, controllerNumber, identifier, classes);
    device->configure(when, &mConfig, 0);
    device->reset(when);
    //设备添加到mDevices集合中
    mDevices.add(deviceId, device);
    bumpGenerationLocked();

    if (device->getClasses() & INPUT_DEVICE_CLASS_EXTERNAL_STYLUS) {
        notifyExternalStylusPresenceChanged();
    }
}
```

#### 3.1.1 createDeviceLocked

```
InputDevice* InputReader::createDeviceLocked(int32_t deviceId, int32_t controllerNumber,
        const InputDeviceIdentifier& identifier, uint32_t classes) {
    InputDevice* device = new InputDevice(&mContext, deviceId, bumpGenerationLocked(),
            controllerNumber, identifier, classes);

  
     //获取键盘源类型
    uint32_t keyboardSource = 0;
    int32_t keyboardType = AINPUT_KEYBOARD_TYPE_NON_ALPHABETIC;
    if (classes & INPUT_DEVICE_CLASS_KEYBOARD) {
        keyboardSource |= AINPUT_SOURCE_KEYBOARD;
    }
    if (classes & INPUT_DEVICE_CLASS_ALPHAKEY) {
        keyboardType = AINPUT_KEYBOARD_TYPE_ALPHABETIC;
    }
    if (classes & INPUT_DEVICE_CLASS_DPAD) {
        keyboardSource |= AINPUT_SOURCE_DPAD;
    }
    if (classes & INPUT_DEVICE_CLASS_GAMEPAD) {
        keyboardSource |= AINPUT_SOURCE_GAMEPAD;
    }
    //添加键盘类设备InputMapper
    if (keyboardSource != 0) {
        device->addMapper(new KeyboardInputMapper(device, keyboardSource, keyboardType));
    }

     //添加鼠标类设备InputMapper
    if (classes & INPUT_DEVICE_CLASS_CURSOR) {
        device->addMapper(new CursorInputMapper(device));
    }

    //添加触摸屏设备InputMapper
    if (classes & INPUT_DEVICE_CLASS_TOUCH_MT) {
        device->addMapper(new MultiTouchInputMapper(device));
    } else if (classes & INPUT_DEVICE_CLASS_TOUCH) {
        device->addMapper(new SingleTouchInputMapper(device));
    }

    //添加操作杆设备InputMapper
    if (classes & INPUT_DEVICE_CLASS_JOYSTICK) {
        device->addMapper(new JoystickInputMapper(device));
    }

    // 外部设备InputMapper
    if (classes & INPUT_DEVICE_CLASS_EXTERNAL_STYLUS) {
        device->addMapper(new ExternalStylusInputMapper(device));
    }

    return device;
}
```

将`InputDeviceIdentifier`类型转换成`Device`类型封装对应`Mapper`类型添加到`mDevices`键值对集合中

### 3.2 processEventsForDeviceLocked

```
void InputReader::processEventsForDeviceLocked(int32_t deviceId,
        const RawEvent* rawEvents, size_t count) {
    ssize_t deviceIndex = mDevices.indexOfKey(deviceId);
 
    InputDevice* device = mDevices.valueAt(deviceIndex);
    //3.2.1   
    device->process(rawEvents, count);
}
```

#### 3.2.1 process

```
void InputDevice::process(const RawEvent* rawEvents, size_t count) {
    //事件个数
    size_t numMappers = mMappers.size();
    for (const RawEvent* rawEvent = rawEvents; count--; rawEvent++) {
        if (mDropUntilNextSync) {
            if (rawEvent->type == EV_SYN && rawEvent->code == SYN_REPORT) {
                mDropUntilNextSync = false;
        } else if (rawEvent->type == EV_SYN && rawEvent->code == SYN_DROPPED) {
            ALOGI("Detected input event buffer overrun for device %s.", getName().string());
            mDropUntilNextSync = true;
            reset(rawEvent->when);
        } else {
            for (size_t i = 0; i < numMappers; i++) {
                InputMapper* mapper = mMappers[i];
                //3.2.2  具体事件的process
                mapper->process(rawEvent);
            }
        }
    }
}
```

#### 3.2.2 分析 KeyboardInputMapper

```
void KeyboardInputMapper::process(const RawEvent* rawEvent) {
    switch (rawEvent->type) {
    case EV_KEY: {
        int32_t scanCode = rawEvent->code;
        int32_t usageCode = mCurrentHidUsage;
        mCurrentHidUsage = 0;

        if (isKeyboardOrGamepadKey(scanCode)) {
            int32_t keyCode;
            uint32_t flags;
            //3.3.3 获取所对应的KeyCode
            if (getEventHub()->mapKey(getDeviceId(), scanCode, usageCode, &keyCode, &flags)) {
                keyCode = AKEYCODE_UNKNOWN;
                flags = 0;
            }
            //3.3.4 处理事件
            processKey(rawEvent->when, rawEvent->value != 0, keyCode, scanCode, flags);
        }
        break;
    }
    case EV_MSC: {
        if (rawEvent->code == MSC_SCAN) {
            mCurrentHidUsage = rawEvent->value;
        }
        break;
    }
    case EV_SYN: {
        if (rawEvent->code == SYN_REPORT) {
            mCurrentHidUsage = 0;
        }
    }
    }
}
```

#### 3.3.3 mapKey

```
tatus_t EventHub::mapKey(int32_t deviceId, int32_t scanCode, int32_t usageCode,
        int32_t* outKeycode, uint32_t* outFlags) const {
    AutoMutex _l(mLock);
    Device* device = getDeviceLocked(deviceId);

    if (device) {
      
        sp<KeyCharacterMap> kcm = device->getKeyCharacterMap();
        if (kcm != NULL) {
             //KeyCharacterMap获取mapkey
             if (!kcm->mapKey(scanCode, usageCode, outKeycode)) {
                *outFlags = 0;
                return NO_ERROR;
            }
        }

        // Check the key layout next.
        if (device->keyMap.haveKeyLayout()) {
            if (!device->keyMap.keyLayoutMap->mapKey(
                    scanCode, usageCode, outKeycode, outFlags)) {
                return NO_ERROR;
            }
        }
    }

    *outKeycode = 0;
    *outFlags = 0;
    return NAME_NOT_FOUND;
}
```

#### 3.3.4 mapKey

```
status_t KeyCharacterMap::mapKey(int32_t scanCode, int32_t usageCode, int32_t* outKeyCode) const {
    if (scanCode) {
        ssize_t index = mKeysByScanCode.indexOfKey(scanCode);
        if (index >= 0) {
            //根据canCode找到mapkey
            *outKeyCode = mKeysByScanCode.valueAt(index);
            return OK;
        }
    }
    *outKeyCode = AKEYCODE_UNKNOWN;
    return NAME_NOT_FOUND;
}

```

### 3.4 processKey

```
void KeyboardInputMapper::processKey(nsecs_t when, bool down, int32_t keyCode,
        int32_t scanCode, uint32_t policyFlags) {

    if (down) {

        if (mParameters.orientationAware && mParameters.hasAssociatedDisplay) {
            keyCode = rotateKeyCode(keyCode, mOrientation);
        }

        ssize_t keyDownIndex = findKeyDown(scanCode);
        if (keyDownIndex >= 0) {
            //mKeyDowns记录着所有按下事件
            keyCode = mKeyDowns.itemAt(keyDownIndex).keyCode;
        } else {
           / /压入栈顶
            mKeyDowns.push();
            KeyDown& keyDown = mKeyDowns.editTop();
            keyDown.keyCode = keyCode;
            keyDown.scanCode = scanCode;
        }
        //记录按下时间
        mDownTime = when;
    } else {
        ssize_t keyDownIndex = findKeyDown(scanCode);
        if (keyDownIndex >= 0) {
            //键抬起操作，则移除按下事件
            keyCode = mKeyDowns.itemAt(keyDownIndex).keyCode;
            mKeyDowns.removeAt(size_t(keyDownIndex));
        } else { 
            return;
        }
    }NotifyKeyArgs对象，when记录eventTime时间，downTime记录按下时间
    //创建
    NotifyKeyArgs args(when, getDeviceId(), mSource, policyFlags,
            down ? AKEY_EVENT_ACTION_DOWN : AKEY_EVENT_ACTION_UP,
            AKEY_EVENT_FLAG_FROM_SYSTEM, keyCode, scanCode, newMetaState, downTime);
    //3.5通知key时间  QueuedInputListener     
    getListener()->notifyKey(&args);
}
```

### 3.5 notifyKey

```
void QueuedInputListener::notifyKey(const NotifyKeyArgs* args) {
    //mArgsQueue的数据类型为Vector<NotifyArgs*> 将该key事件压入栈顶
    mArgsQueue.push(new NotifyKeyArgs(*args));
}
```

事件的处理通过`Mapper`类型执行对应事件的函数，最后封装成`NotifyKeyArgs`参数添加到`mArgsQueue`队列中等待事件的分发到`InputDispacher`中

### 4 mQueuedListener->flush

```
void QueuedInputListener::flush() {
    size_t count = mArgsQueue.size();
    for (size_t i = 0; i < count; i++) {
        NotifyArgs* args = mArgsQueue[i];
        //4.1mInnerListener是InputDispatcher实现的接口
        args->notify(mInnerListener);
        delete args;
    }
    mArgsQueue.clear();
}
```

#### 4.1notify

```
void NotifyKeyArgs::notify(const sp<InputListenerInterface>& listener) const {
    //4.2 InputDispatcher对象中
    listener->notifyKey(this);
}

```

#### 4.2 notifyKey

```
void InputDispatcher::notifyKey(const NotifyKeyArgs* args) {

    if (!validateKeyEvent(args->action)) {
        return;
    }

    uint32_t policyFlags = args->policyFlags;
    int32_t flags = args->flags;
    int32_t metaState = args->metaState;
    policyFlags |= POLICY_FLAG_TRUSTED;
    int32_t keyCode = args->keyCode;
    ...
     //按下的一些处理 
    if (metaState & AMETA_META_ON && args->action == AKEY_EVENT_ACTION_DOWN) {
        int32_t newKeyCode = AKEYCODE_UNKNOWN;
        if (keyCode == AKEYCODE_DEL) {
            newKeyCode = AKEYCODE_BACK;
        } else if (keyCode == AKEYCODE_ENTER) {
            newKeyCode = AKEYCODE_HOME;
        }
        if (newKeyCode != AKEYCODE_UNKNOWN) {
            AutoMutex _l(mLock);
            struct KeyReplacement replacement = {keyCode, args->deviceId};
            mReplacedKeys.add(replacement, newKeyCode);
            keyCode = newKeyCode;
            metaState &= ~AMETA_META_ON;
        }
    } 
    //抬起的处理
    else if (args->action == AKEY_EVENT_ACTION_UP) {
        AutoMutex _l(mLock);
        struct KeyReplacement replacement = {keyCode, args->deviceId};
        ssize_t index = mReplacedKeys.indexOfKey(replacement);
        if (index >= 0) {
            keyCode = mReplacedKeys.valueAt(index);
            mReplacedKeys.removeItemsAt(index);
            metaState &= ~AMETA_META_ON;
        }
    }
    //初始化Key参数
    KeyEvent event;
    event.initialize(args->deviceId, args->source, args->action,
            flags, keyCode, args->scanCode, metaState, 0,
            args->downTime, args->eventTime);
    //4.3 mPlicy是指NativceInputManager对象
    mPolicy->interceptKeyBeforeQueueing(&event, /*byref*/ policyFlags);

    bool needWake;
    {  
        mLock.lock();

      
        int32_t repeatCount = 0;
        KeyEntry* newEntry = new KeyEntry(args->eventTime,
                args->deviceId, args->source, policyFlags,
                args->action, flags, keyCode, args->scanCode,
                metaState, repeatCount, args->downTime);
        //4.4 将newEntry对象放入队列 
        needWake = enqueueInboundEventLocked(newEntry);
        mLock.unlock();
    } // release lock

    if (needWake) {
        //唤醒InputDispatcher线程
        mLooper->wake();
    }
}
```

### 4.3 interceptKeyBeforeQueueing

```
void NativeInputManager::interceptKeyBeforeQueueing(const KeyEvent* keyEvent,
        uint32_t& policyFlags) {
    ...
    if ((policyFlags & POLICY_FLAG_TRUSTED)) {
        nsecs_t when = keyEvent->getEventTime(); //时间
        JNIEnv* env = jniEnv();
        jobject keyEventObj = android_view_KeyEvent_fromNative(env, keyEvent);
        if (keyEventObj) {
            // 调用Java层的IMS.interceptKeyBeforeQueueing
            wmActions = env->CallIntMethod(mServiceObj,
                    gServiceClassInfo.interceptKeyBeforeQueueing,
                    keyEventObj, policyFlags);
            ...
        } else {
            ...
        }
        handleInterceptActions(wmActions, when, /*byref*/ policyFlags);
    } else {
        ...
    }
}
```

该方法会调用Java层的`InputManagerService`的`interceptKeyBeforeQueueing()`方法。

#### 4.3.1 findTouchedWindowAtLocked

```
sp<InputWindowHandle> InputDispatcher::findTouchedWindowAtLocked(int32_t displayId,
        int32_t x, int32_t y) {
    //从前台到后台来遍历查询可触摸的窗口
    size_t numWindows = mWindowHandles.size();
    for (size_t i = 0; i < numWindows; i++) {
        sp<InputWindowHandle> windowHandle = mWindowHandles.itemAt(i);
        const InputWindowInfo* windowInfo = windowHandle->getInfo();
        if (windowInfo->displayId == displayId) {
            int32_t flags = windowInfo->layoutParamsFlags;
            if (windowInfo->visible) {
                if (!(flags & InputWindowInfo::FLAG_NOT_TOUCHABLE)) {
                    bool isTouchModal = (flags & (InputWindowInfo::FLAG_NOT_FOCUSABLE
                            | InputWindowInfo::FLAG_NOT_TOUCH_MODAL)) == 0;
                    if (isTouchModal || windowInfo->touchableRegionContainsPoint(x, y)) {
                        //找到目标窗口
                        return windowHandle;
                    }
                }
            }
        }
    }
    return NULL;
}
```

查询全部窗体找到对应`displayID`并且是visible=true和可触摸的状态，最后查询点击的位置是不是被窗体所包含找到了设置`needWake=true`

### 4.4 enqueueInboundEventLocked

```
bool InputDispatcher::enqueueInboundEventLocked(EventEntry* entry) {
    bool needWake = mInboundQueue.isEmpty();
    mInboundQueue.enqueueAtTail(entry);
    traceInboundQueueLengthLocked();

    switch (entry->type) {
    case EventEntry::TYPE_KEY: {
  
        KeyEntry* keyEntry = static_cast<KeyEntry*>(entry);
      
        if (isAppSwitchKeyEventLocked(keyEntry)) {
            //按下事件
            if (keyEntry->action == AKEY_EVENT_ACTION_DOWN) {
                mAppSwitchSawKeyDown = true;
            } else if (keyEntry->action == AKEY_EVENT_ACTION_UP) {
                if (mAppSwitchSawKeyDown) {
                    //APP_SWITCH_TIMEOUT=500ms
                    mAppSwitchDueTime = keyEntry->eventTime + APP_SWITCH_TIMEOUT;
                    mAppSwitchSawKeyDown = false;
                    needWake = true;
                }
            }
        }
        break;
    }

    case EventEntry::TYPE_MOTION: {
       //当前App无响应且用户希望切换到其他应用窗口，则drop该窗口事件，并处理其他窗口事件
        MotionEntry* motionEntry = static_cast<MotionEntry*>(entry);
        if (motionEntry->action == AMOTION_EVENT_ACTION_DOWN
                && (motionEntry->source & AINPUT_SOURCE_CLASS_POINTER)
                && mInputTargetWaitCause == INPUT_TARGET_WAIT_CAUSE_APPLICATION_NOT_READY
                && mInputTargetWaitApplicationHandle != NULL) {
            int32_t displayId = motionEntry->displayId;
            int32_t x = int32_t(motionEntry->pointerCoords[0].
                    getAxisValue(AMOTION_EVENT_AXIS_X));
            int32_t y = int32_t(motionEntry->pointerCoords[0].
                    getAxisValue(AMOTION_EVENT_AXIS_Y));
            //4.3.1 查询可触摸的窗口        
            sp<InputWindowHandle> touchedWindowHandle = findTouchedWindowAtLocked(displayId, x, y);
            if (touchedWindowHandle != NULL
                    && touchedWindowHandle->inputApplicationHandle
                            != mInputTargetWaitApplicationHandle) {
                mNextUnblockedEvent = motionEntry;
                needWake = true;
            }
        }
        break;
    }
    }

    return needWake;
}
```

### 核心工作

InputReader整个过程涉及多次事件封装转换，其主要工作核心是以下三大步骤:

- `getEvents`：通过`EventHub`(监听目录/dev/input)读取事件放入`mEventBuffer`,而`mEventBuffer`是一个大小为256的数组, 再将事件`input_event`转换为`RawEvent`;
- `processEventsLocked`: 对事件进行加工, 转换`RawEvent` -> `NotifyKeyArgs(NotifyArgs)` 
- `QueuedListener->flush`：将事件发送到`InputDispatcher`线程, 转换`NotifyKeyArgs` -> `KeyEntry(EventEntry) `

`InputReader`线程不断循环地执行`InputReader.loopOnce(),` 每次处理完生成的是`EventEntry`(比如`KeyEntry`, `MotionEntry`), 接下来的工作就交给`InputDispatcher`线程。