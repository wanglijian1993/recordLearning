# Jetpack架构之LiveData

## 什么是LiveData

- `LiveData`组件是Jetpack新推出的基于观察者的消息订阅/分发组件，具有宿主(Activity,Fragment)生命周期感知能力，这种感知能力可确保`LiveData`仅分发消息给处于**活跃状态**的观察者。

  **活跃状态**:Activity对应Lifecycle是Start或者Resume的状态

- LiveData订阅宿主不需要手动移除订阅消息

- 黏性消息分发流程。既新消息的observer也能接收到前面发送的最后一条数据

介绍几个LiveData相关的类

## MutableLiveData.java

```
public class MutableLiveData<T> extends LiveData<T> {
    public MutableLiveData() {
    }

    public void postValue(T value) {
        super.postValue(value);
    }

    public void setValue(T value) {
        super.setValue(value);
    }
}
```

我们在使用`LiveData`的做消息分发的时候，需要使用这个子类。之所以这么设计，是考虑倒单一开闭原则，只有继承LiveData类或者才可以发送消息的能力。

接来下看看在View层怎么去监听数据源发生改变

```
viewModel.liveData.observe(this（owner）, Observer {
  
})

   public void observe(@NonNull LifecycleOwner owner, @NonNull Observer<? super T> observer) {
        /** owner对象和observer进行包装
          * owner activity的状态管理
          * observer 订阅回调方法
          */
        LifecycleBoundObserver wrapper = new LifecycleBoundObserver(owner, observer);
        ObserverWrapper existing = mObservers.putIfAbsent(observer, wrapper);
        if (existing != null && !existing.isAttachedTo(owner)) {
            throw new IllegalArgumentException("Cannot add the same observer"
                    + " with different lifecycles");
        }
        if (existing != null) {
            return;
        }
        //吧wrapper包装类放到lifecycle里进行状态管理
        owner.getLifecycle().addObserver(wrapper);
    }

```

其实进行订阅代码还是比较简单的接下来看看发送消息怎么进行通知的

```
@Override
public void postValue(T value) {
    super.postValue(value);
}

@Override
public void setValue(T value) {
    super.setValue(value);
}
```

发送消息无非是setValue和postValuew(可异步发送)但是最终都是setValuew的方式

```
protected void setValue(T value) {
     //是否主线程
    assertMainThread("setValue");
    //更新下version 后面会用他对比消息是否发送过
    mVersion++;
    //变量更新
    mData = value;
    dispatchingValue(null);
}

    void dispatchingValue(@Nullable ObserverWrapper initiator) {
        do {
            mDispatchInvalidated = false;
            if (initiator != null) {
                considerNotify(initiator);
                initiator = null;
            } else {
                   //拿出全部观察对象
                for (Iterator<Map.Entry<Observer<? super T>, ObserverWrapper>> iterator =
                        mObservers.iteratorWithAdditions(); iterator.hasNext(); ) {
                     //最终发送消息的方法
                    considerNotify(iterator.next().getValue());
                    if (mDispatchInvalidated) {
                        break;
                    }
                }
            }
        } while (mDispatchInvalidated);
    }
    
        private void considerNotify(ObserverWrapper observer) {
        if (!observer.mActive) {
            return;
        }
         //判断当前订阅是否是start，resume状态
        if (!observer.shouldBeActive()) {
            observer.activeStateChanged(false);
            return;
        }
        //判断observer是否发送过
        if (observer.mLastVersion >= mVersion) {
            return;
        }
        //满足发送条件更新下发送版本号
        observer.mLastVersion = mVersion;
        //activity的observer实现方法
        observer.mObserver.onChanged((T) mData);
    }
```

以上就是liveData的观察者方式进行数据发送。