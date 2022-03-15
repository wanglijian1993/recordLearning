# Jetpack架构之Lifecycle,LiveData,ViewModel

## Lifecycle使用生命周期感知型组件处理生命周期 

Lifecycle生命周期感知型组件可执行操作来响应另一个组件（如 Activity 和 Fragment）的生命周期状态的变化。

### Lifecycle

`Lifecycle`是一个类，用于存储有关组件（如 Activity 或 Fragment）的生命周期状态的信息，并允许其他对象观察此状态。

`Lifecycler`使用两种主要枚举跟踪其关联组件的生命周期状态

**事件**

从框架和Lifecycle类分配的生命周期事件。这些事件映射到Activity和Fragment中的回调事件。

**状态**

由Lifecycle对象跟踪的组件的当前状态。

![生命周期状态示意图](https://developer.android.com/images/topic/libraries/architecture/lifecycle-states.svg?hl=zh-cn)

## Lifecycle关键类介绍

### Lifecycle.java文件源码

```
public abstract class Lifecycle {
    @RestrictTo({Scope.LIBRARY_GROUP})
    @NonNull
    AtomicReference<Object> mInternalScopeRef = new AtomicReference();

    public Lifecycle() {
    }
    //添加订阅者
    @MainThread
    public abstract void addObserver(@NonNull LifecycleObserver var1);
    //移除订阅者
    @MainThread
    public abstract void removeObserver(@NonNull LifecycleObserver var1);
   
    //类抽象行为获取Lifecycle.state
    @MainThread
    @NonNull
    public abstract Lifecycle.State getCurrentState();
    //状态
    public static enum State {
        DESTROYED,
        INITIALIZED,
        CREATED,
        STARTED,
        RESUMED;

        private State() {
        }

        public boolean isAtLeast(@NonNull Lifecycle.State state) {
            return this.compareTo(state) >= 0;
        }
    }
    //事件 
    public static enum Event {
        ON_CREATE,
        ON_START,
        ON_RESUME,
        ON_PAUSE,
        ON_STOP,
        ON_DESTROY,
        ON_ANY;

        private Event() {
        }
    }
}

```

### LifecycleOwner.java文件源码

```
public interface LifecycleOwner {
    @NonNull
    Lifecycle getLifecycle();
}

```

### LifecycleOberver文件源码

```
public interface LifecycleObserver {
}
```

### 使用示例

```
//订阅者
class LifecycleListener : LifecycleObserver {
    @OnLifecycleEvent(Lifecycle.Event.ON_CREATE)
    fun onCreateActivity(){
        println("onCreateActivity")

    }
}

//被订阅者
class LifecycleActivity : AppCompatActivity(){
    override fun onCreate(savedInstanceState: Bundle?) {
		//添加订阅 
		getLifecycle().addObserver(LifecycleListener())
    }
}
```

**示例步骤**

1.LifecycleListner类通过实现接口Liifecycleobserver和创建函数并再函数上声明注解的方式声明一个去订阅Activity的生命周期。

2.getLifecycle().addobserver(LifecycleListner())再Activity层添加订阅

通过步骤1，步骤2就可以实现用LifecycleListener类去监听LifecycleActivity的声明周期。

## 源码分析

通过示例去看源码学习Lifecycle精髓。

产生订阅关系是通过LifecycleActivity类的getLifecycle().addObserver(LifecycleListener())代码

逐步分析

1.**getLifecycle()**

```
@Override
public Lifecycle getLifecycle() {
    return mLifecycleRegistry;
}
```

`getLifecycle`是在`LifecycleActivity`基类`ComponentActivity`的重写方法，返回`mLifecycleRegistry`对象

`mLifecycleRegistry`的创建实在最上层

```
public class LifecycleRegistry extends Lifecycle

private final LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);

    public LifecycleRegistry(@NonNull LifecycleOwner provider) {
        mLifecycleOwner = new WeakReference<>(provider);
        mState = INITIALIZED;
    }
```

`LifecycleRegistry`是`Lifecycle`的实现类

**LifecycleRegistry的作用？？？**

绕过LifecycleRegistry继续往下分析调用addObserver()方法做了些什么，addObserver是Lifecycle抽象类的抽象方法那我们就LifecycleRegistry实现类

```
@Override
public void addObserver(@NonNull LifecycleObserver observer) {
    //mState变量不是销毁状态就是初始化的状态，第一次进来 initialState=INITIALIZED
    State initialState = mState == DESTROYED ? DESTROYED : INITIALIZED;
    //创建一个包装类对LifecycleObserver实现类和他对应的状态进行包装
    ObserverWithState statefulObserver = new ObserverWithState(observer, initialState);
    //mObserverMap通过observer做key对statefulObserver进行存储，mObserverMap是对hashmap进行了二       次封装双向列表结构。
    ObserverWithState previous = mObserverMap.putIfAbsent(observer, statefulObserver);
    //获取LifecycleActivity(栈顶Activity)对应的LifecycleOwner引用
    LifecycleOwner lifecycleOwner = mLifecycleOwner.get();
    
    boolean isReentrance = mAddingObserverCounter != 0 || mHandlingEvent;
    State targetState = calculateTargetState(observer);
    mAddingObserverCounter++;
    //默认状态都是INITIALIZED不会进里面的方法
    while ((statefulObserver.mState.compareTo(targetState) < 0
            && mObserverMap.contains(observer))) {
        pushParentState(statefulObserver.mState);
        statefulObserver.dispatchEvent(lifecycleOwner, upEvent(statefulObserver.mState));
        popParentState();
        // mState / subling may have been changed recalculate
        targetState = calculateTargetState(observer);
    }
    //Reentrance=false
    if (!isReentrance) {
        // we do sync only on the top level.
        sync();
    }
    mAddingObserverCounter--;
}
```

最终会走到sync方法里 只有栈顶的Activity才会执行sync方法

```
private void sync() {
    LifecycleOwner lifecycleOwner = mLifecycleOwner.get();
    //默认不是进while循环
    while (!isSynced()) {
        mNewEventOccurred = false;
        // no need to check eldest for nullability, because isSynced does it for us.
        if (mState.compareTo(mObserverMap.eldest().getValue().mState) < 0) {
            backwardPass(lifecycleOwner);
        }
        Entry<LifecycleObserver, ObserverWithState> newest = mObserverMap.newest();
        if (!mNewEventOccurred && newest != null
                && mState.compareTo(newest.getValue().mState) > 0) {
            forwardPass(lifecycleOwner);
        }
    }
    mNewEventOccurred = false;
}
    //第一次注册的时候eldestObserverState和newestObserverState的状态是相同的可以看SafeIterableMap类中put方法
    private boolean isSynced() {
        if (mObserverMap.size() == 0) {
            return true;
        }
        State eldestObserverState = mObserverMap.eldest().getValue().mState;
        State newestObserverState = mObserverMap.newest().getValue().mState;
        return eldestObserverState == newestObserverState && mState == newestObserverState;
    }
    
```

通过上述源码分析getLifecycle().addObserver(LifecycleListener())整个添加订阅过程已经结束，但是LifecycleListener怎么去监听LifecycleActivity生命周期的还没有发现，我们直接LifecycleRegistry事在ComponentActivity里面进行实例初始化的，那我们就去ComponentActivity类看一看。

在ComponentActivity中onCreate方法里有一句话代码ReportFragment.injectIfNeededIn(this);这是一个透明Fragment跟他所在容器Activity生命周期同步。

```
@Override
public void onActivityCreated(Bundle savedInstanceState) {
    dispatch(Lifecycle.Event.ON_CREATE);
}

@Override
public void onStart() {
     dispatch(Lifecycle.Event.ON_START);
}

@Override
public void onResume() {
    dispatch(Lifecycle.Event.ON_RESUME);
}

@Override
public void onPause() {
    dispatch(Lifecycle.Event.ON_PAUSE);
}

@Override
public void onStop() {
    dispatch(Lifecycle.Event.ON_STOP);
}

@Override
public void onDestroy() {
   dispatch(Lifecycle.Event.ON_DESTROY);
}
```

在Fragment生命周期中进行分发Lifecycle中对应Activity生命周期的Event事件。

```
private void dispatch(Lifecycle.Event event) {
    Activity activity = getActivity();
    if (activity instanceof LifecycleOwner) {
        Lifecycle lifecycle = ((LifecycleOwner) activity).getLifecycle();
        if (lifecycle instanceof LifecycleRegistry) {
            ((LifecycleRegistry) lifecycle).handleLifecycleEvent(event);
        }
    }
}
```

最终调用`LifecycleRegistry`类中`handleLifecycleEvent`方法

```
public void handleLifecycleEvent(@NonNull Lifecycle.Event event) {
    //通过Fragment分发的Event事件推导Lifecycle的状态
    State next = getStateAfter(event);
    moveToState(next);
}

    static State getStateAfter(Event event) {
        switch (event) {
            case ON_CREATE:
            case ON_STOP:
                return CREATED;
            case ON_START:
            case ON_PAUSE:
                return STARTED;
            case ON_RESUME:
                return RESUMED;
            case ON_DESTROY:
                return DESTROYED;
            case ON_ANY:
                break;
        }
        throw new IllegalArgumentException("Unexpected event value " + event);
    }
```

`getStateAfter(event)`方法获取`Lifecycle`对应类的状态规则是按照最上面的`Event`和`State`对应状态图规则。

```
private void moveToState(State next) {
    if (mState == next) {
        return;
    }
    mState = next;
    if (mHandlingEvent || mAddingObserverCounter != 0) {
        mNewEventOccurred = true;
        // we will figure out what to do on upper level.
        return;
    }
    mHandlingEvent = true;
    sync();
    mHandlingEvent = false;
}
```

最终还是走到sync方法里

```
private void sync() {
    LifecycleOwner lifecycleOwner = mLifecycleOwner.get();

    while (!isSynced()) {
        mNewEventOccurred = false;
        //如果mState的值小于注册时候存储的订阅者包装类对应的state
        if (mState.compareTo(mObserverMap.eldest().getValue().mState) < 0) {
            backwardPass(lifecycleOwner);
        }
        Entry<LifecycleObserver, ObserverWithState> newest = mObserverMap.newest();
        if (!mNewEventOccurred && newest != null
                && mState.compareTo(newest.getValue().mState) > 0) {
            forwardPass(lifecycleOwner);
        }
    }
    mNewEventOccurred = false;
}

    private boolean isSynced() {
        if (mObserverMap.size() == 0) {
            return true;
        }
        State eldestObserverState = mObserverMap.eldest().getValue().mState;
        State newestObserverState = mObserverMap.newest().getValue().mState;
        return eldestObserverState == newestObserverState && mState == newestObserverState;
    }
```

这时候isSynced()方法返回false因为mState!=newestObserverState（newestObserverState==INITIALIZED，mState是通过getStateAfter(event)方法获得）这时候mState值会大于newest.getValue().mState的值所以会走forwardPass(lifecycleOwner);方法

```
private void forwardPass(LifecycleOwner lifecycleOwner) {
     //mObserverMap转换成迭代器方便遍历
    Iterator<Entry<LifecycleObserver, ObserverWithState>> ascendingIterator =
            mObserverMap.iteratorWithAdditions();
    //判断有没有订阅者的Entry 看下面hasNext方法
    while (ascendingIterator.hasNext() && !mNewEventOccurred) {
        //获取第一个订阅者Entry
        Entry<LifecycleObserver, ObserverWithState> entry = ascendingIterator.next();
        //获取具体订阅对象
        ObserverWithState observer = entry.getValue();
        //根据订阅者的State与ReportFragment.dispatch(Event)分发事件通过getStateAfter方法对事件转		   换成state进行比较
        while ((observer.mState.compareTo(mState) < 0 && !mNewEventOccurred
                && mObserverMap.contains(entry.getKey()))) {
             //最终通知Activity生命周期的方法
            observer.dispatchEvent(lifecycleOwner, upEvent(observer.mState));
        }
    }
}

         
        public boolean hasNext() {
            if (mBeforeStart) {
                return mStart != null;
            }
            return mCurrent != null && mCurrent.mNext != null;
        }
        
           //与forwardPass道理相同
          private void backwardPass(LifecycleOwner lifecycleOwner) {
        Iterator<Entry<LifecycleObserver, ObserverWithState>> descendingIterator =
                mObserverMap.descendingIterator();
        while (descendingIterator.hasNext() && !mNewEventOccurred) {
            Entry<LifecycleObserver, ObserverWithState> entry = descendingIterator.next();
            ObserverWithState observer = entry.getValue();
            while ((observer.mState.compareTo(mState) > 0 && !mNewEventOccurred
                    && mObserverMap.contains(entry.getKey()))) {
                Event event = downEvent(observer.mState);
                pushParentState(getStateAfter(event));
                observer.dispatchEvent(lifecycleOwner, event);
                popParentState();
            }
        }
    }
```

**backwardPass**与**forwardpass**内部逻辑相同，唯一区别就是订阅类与Activity生命周期Event事件转换成对应State状态如果比较值小于就去Forwardpass方法进行遍历分发Event事件，如果大于就去backwardPass进行分发事件。

**启动Activity的过程中会走forwardPass，销毁Activity过程中会走backwardPass**

最终会走到 `observer.dispatchEvent(lifecycleOwner, event)`方法中。

```
static class ObserverWithState {
    State mState;
    LifecycleEventObserver mLifecycleObserver;

    ObserverWithState(LifecycleObserver observer, State initialState) {
        mLifecycleObserver = Lifecycling.lifecycleEventObserver(observer);
        mState = initialState;
    }

    void dispatchEvent(LifecycleOwner owner, Event event) {
        State newState = getStateAfter(event);
        mState = min(mState, newState);
        mLifecycleObserver.onStateChanged(owner, event);
        mState = newState;
    }
}
```

`ObserverWithState`类很眼熟是在**Activity**中调用`addObserver`方法添加订阅关系创建的包装类，在`dispatchEvent`方法里最终调用`mLifecycleObserver.onStateChanged(owner, event)`，先看看`mLifecycleObserver`的实现类

```
1.

static LifecycleEventObserver lifecycleEventObserver(Object object) {

    final Class<?> klass = object.getClass();
    int type = getObserverConstructorType(klass);
    return new ReflectiveGenericLifecycleObserver(object);
}

2.

ReflectiveGenericLifecycleObserver(Object wrapped) {
        mWrapped = wrapped;
        mInfo = ClassesInfoCache.sInstance.getInfo(mWrapped.getClass());
    }
    
3.  

CallbackInfo getInfo(Class klass) {
        CallbackInfo existing = mCallbackMap.get(klass);
        existing = createInfo(klass, null);
        return existing;
    }
    
4.
private CallbackInfo createInfo(Class klass, @Nullable Method[] declaredMethods) {
        Class superclass = klass.getSuperclass();
        Map<MethodReference, Lifecycle.Event> handlerToEvent = new HashMap<>();
 
        Method[] methods = declaredMethods != null ? declaredMethods : getDeclaredMethods(klass);
        boolean hasLifecycleMethods = false;
        for (Method method : methods) {
            OnLifecycleEvent annotation = method.getAnnotation(OnLifecycleEvent.class);
            if (annotation == null) {
                continue;
            }
            hasLifecycleMethods = true;
            Class<?>[] params = method.getParameterTypes();
            int callType = CALL_TYPE_NO_ARG;
            if (params.length > 0) {
                callType = CALL_TYPE_PROVIDER;
                if (!params[0].isAssignableFrom(LifecycleOwner.class)) {
                    throw new IllegalArgumentException(
                            "invalid parameter type. Must be one and instanceof LifecycleOwner");
                }
            }
            Lifecycle.Event event = annotation.value();

            if (params.length > 1) {
                callType = CALL_TYPE_PROVIDER_WITH_EVENT;
                if (!params[1].isAssignableFrom(Lifecycle.Event.class)) {
                    throw new IllegalArgumentException(
                            "invalid parameter type. second arg must be an event");
                }
                if (event != Lifecycle.Event.ON_ANY) {
                    throw new IllegalArgumentException(
                            "Second arg is supported only for ON_ANY value");
                }
            }
            if (params.length > 2) {
                throw new IllegalArgumentException("cannot have more than 2 params");
            }
            MethodReference methodReference = new MethodReference(callType, method);
            verifyAndPutHandler(handlerToEvent, methodReference, event, klass);
        }
        CallbackInfo info = new CallbackInfo(handlerToEvent);
        mCallbackMap.put(klass, info);
        mHasLifecycleMethods.put(klass, hasLifecycleMethods);
        return info;
    }
    
    
```

不做过多的描述了就是通过反射解析把订阅类全部Method方法用CallBackInfo包装下。最终调用方法在

`ReflectiveGenericLifecycleObserver`类中`mInfo.invokeCallbacks(source, event, mWrapped)`

```
void invokeCallbacks(LifecycleOwner source, Lifecycle.Event event, Object target) {
    //分发Event事件
   invokeMethodsForEvent(mEventToHandlers.get(event), source, event, target);
    //通过注解标注的Any事件每次生命周期改变了都会发送通知
   invokeMethodsForEvent(mEventToHandlers.get(Lifecycle.Event.ON_ANY), source, event,
            target);
}
```

去CallBackInfo类拿通过反射存储的数据调用`invokeMethodsForEvent`

```
    private static void invokeMethodsForEvent(List<MethodReference> handlers,
            LifecycleOwner source, Lifecycle.Event event, Object mWrapped) {
        if (handlers != null) {
            for (int i = handlers.size() - 1; i >= 0; i--) {
                handlers.get(i).invokeCallback(source, event, mWrapped);
            }
        }
    }
}
```

```
void invokeCallback(LifecycleOwner source, Lifecycle.Event event, Object target) {
    //noinspection TryWithIdenticalCatches
    try {
        switch (mCallType) {
            case CALL_TYPE_NO_ARG:
                mMethod.invoke(target);
                break;
            case CALL_TYPE_PROVIDER:
                mMethod.invoke(target, source);
                break;
            case CALL_TYPE_PROVIDER_WITH_EVENT:
                mMethod.invoke(target, source, event);
                break;
        }
    } catch (InvocationTargetException e) {
        throw new RuntimeException("Failed to call observer method", e.getCause());
    } catch (IllegalAccessException e) {
        throw new RuntimeException(e);
    }
}
```

最终反射调用，`LifeCycle`源码分析结束。

回答下LifecycleRegistry:LifeCycle注册表里面存储统一对添加

LifeCycle总结：

1.LifeCycleRe
