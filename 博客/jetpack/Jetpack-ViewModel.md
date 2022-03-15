# Jetpack-ViewModel

## ViewModel简介

ViewMode是具有对Activity生命感知能力的VM容器，对View层数据进行存储可以绑定多个View层，当Activity界面旋转导致Activity生命周期发生改变不会影响View层数据丢失问题。

![说明 ViewModel 随着 Activity 状态的改变而经历的生命周期。](https://developer.android.com/images/topic/libraries/architecture/viewmodel-lifecycle.png?hl=zh-cn)

## ViewMode使用

1.创建自定义ViewModel类继承ViewModel()

```
class MainViewModel: ViewModel() 
```

2.在view层创建ViewModel的对象

```
val viewModel= ViewModelProvider(this).get(MainViewModel::class.java)
```

简单二步就完成ViewMdeol类的创建和view层对应关系

## ViewMdeol源码分析

分析ViewModelProvider(this).get(MainViewModel::class.java)源码都做了些什么

### 1.ViewModelProvider(this)

```
public ViewModelProvider(@NonNull ViewModelStoreOwner owner) {
    /**
     * 1.owner.getViewModelStore()创建ViewModel存储器
     * 2.帮助我们自定义ViewModel实例化的工厂类
     */
    this(owner.getViewModelStore(), owner instanceof HasDefaultViewModelProviderFactory
            ? ((HasDefaultViewModelProviderFactory) owner).getDefaultViewModelProviderFactory()
            : NewInstanceFactory.getInstance());
}

		1.创建ViewModel存储器
   public ViewModelStore getViewModelStore() {
        //viewmodel存储器为null的时候进行初始化
        if (mViewModelStore == null) {        
            if (mViewModelStore == null) {
            		//创建ViewModelStore对象
                mViewModelStore = new ViewModelStore();
            }
        }
        //viewmodel不为 null直接返回对象
        return mViewModelStore;
    }
    
  	  2.ViewModel实例化的工厂类
       public ViewModelProvider.Factory getDefaultViewModelProviderFactory() {
        if (mDefaultFactory == null) {
            mDefaultFactory = new SavedStateViewModelFactory(
                    getApplication(),
                    this,
                    getIntent() != null ? getIntent().getExtras() : null);
        }
        return mDefaultFactory;
    }

```

ViewModelProvider(this)主要处理了二件事情上面注释很清楚接下来看get(MainViewModel::class.java)

做了什么

```
	1.
public <T extends ViewModel> T get(@NonNull Class<T> modelClass) {
    //获取类的全名
    String canonicalName = modelClass.getCanonicalName();
    /**我们的ket是androidx.lifecycle.ViewModelProvider.DefaultKey+“:”+类全名
     */
     return get(DEFAULT_KEY + ":" + canonicalName, modelClass);
}
	2.
  public <T extends ViewModel> T get(@NonNull String key, @NonNull Class<T> modelClass) {
       //第一次的时候viewmodel肯定是null的
       ViewModel viewModel = mViewModelStore.get(key);
        //第一进入可以忽略这个if，else判断
        if (modelClass.isInstance(viewModel)) {
            if (mFactory instanceof OnRequeryFactory) {
                ((OnRequeryFactory) mFactory).onRequery(viewModel);
            }
            return (T) viewModel;
        } else {
            //noinspection StatementWithEmptyBody
            if (viewModel != null) {
                // TODO: log a warning.
            }
        }
        
        if (mFactory instanceof KeyedFactory) {
            viewModel = ((KeyedFactory) (mFactory)).create(key, modelClass);
        } else {
        		 /**通过我们在上面创建的viewmodel工厂去实例化我们的自定义的viewmodel
        		  * 通过反射的方式进行初始化
        		  */
            viewModel = (mFactory).create(modelClass);
        }
        //存储到我们的创建viewmodelStore存储器进行内存缓存
        mViewModelStore.put(key, viewModel);
        return (T) viewModel;
    }
```

目前在View层ViewModelProvider(this).get(MainViewModel::class.java)方法源码已经走完了，但是当Activity销毁的时候什么时候清理的ViewModel？？？我决定去ComponentActivity看看

```
public ComponentActivity() {
    Lifecycle lifecycle = getLifecycle();

    getLifecycle().addObserver(new LifecycleEventObserver() {
        @Override
        public void onStateChanged(@NonNull LifecycleOwner source,
                @NonNull Lifecycle.Event event) {
            if (event == Lifecycle.Event.ON_DESTROY) {
                if (!isChangingConfigurations()) {
                    getViewModelStore().clear();
                }
            }
        }
    });

}
```

在构造方法中会添加一个清理ViewModelStore的订阅当Activity执行ON_DESTORY事件的时候，会把对应的ViewModelStore里面存储的ViewModel清理了