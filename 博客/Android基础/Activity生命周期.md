# 							Activity生命周期

#### **Activity生命周期概念**

为了在 `Activity` 生命周期的各个阶段之间导航转换，Activity 类提供六个核心回调：`onCreate()`、`onStart()`、`onResume()`、`onPause()`、`onStop()` 和 `onDestroy()`。当 Activity 进入新状态时，系统会调用其中每个回调。

#### **Activity生命周期直观展现**

![img](https://developer.android.com/guide/components/images/activity_lifecycle.png)

#### **生命周期的方法描述**

##### **onCreate方法**

​	您必须实现此回调，它会在系统首次创建`Activity`时触发。`Activity`会在创建后进入"已创建"状态。在`onCreate()`方法中，您需执行基本应用启动逻辑，该逻辑在`Activity`的整个生命周期中应发生一次。

##### **onStart()方法**

当`Activity`进入"已开始"状态时，系统会调用此回调。`onStart()`调用使用`Activity`对用户可见，因为应用会为`Activity`进入当前并支持互动做准备。

##### **onReame()方法**

`Activity`会在进入"已恢复"状态时来到前台，然后系统调用`onReamue()`回调。这是应用与用户互动的状态。应用会一直保持这种状态，直到某些事件发生，让焦点远离应用。此类事件包括接到电话，用户导航到另一个`Activity`，或设备屏幕关闭。

##### **onPause()方法**

系统将此方法视为用户将要离开您的`Activity`的第一标志(尽管这并总是意味着Activity会被销毁)；此方法表示`Activity`布在位于前台(尽管在用户处于多窗口模式时Activity仍然可见)。使用onPause()方法暂停或调整当`Activity`处于"已暂停"状态时不应继续(或应有节制地继续)的操作，以及您希望很快恢复的操作。

##### **onStop()方法**

如果您的`Activity`不再对用户可见，说明其已进入"已停止"状态，因此系统将调用`onStop()`回调。例如，当新启动的`Activity`覆盖整个屏幕时，可能会发生这种情况。如果`Activity`已结束运行并即将终止，系统还可以调用onStop()。

##### **onDestroy方法**

销毁Activity之前，系统会先调用`onDestroy()`。

#### 保存和恢复瞬时界面状态

##### 实例状态

用户期望 Activity 的界面状态在整个配置变更（例如旋转或切换到多窗口模式）期间保持不变。但是，默认情况下，系统会在发生此类配置更改时销毁 `Activity`，从而清除存储在 `Activity` 实例中的任何界面状态。同样，如果用户暂时从您的应用切换到其他应用，并在稍后返回您的应用，他们也希望界面状态保持不变。但是，当用户离开应用且您的 `Activity` 停止时，系统可能会销毁该应用的进程。

如果系统因系统限制(例如配置变更或内存压力)而销毁`Activity`，虽然实际`Activity`实例会消失，但系统会记住它曾经存在过。如果用户尝试回退到该`Activity`，系统将使用一租描述`Activity`销毁时状态的已保存数据新建该Activity的实例。

系统用于恢复先前状态的已保存数据称为实例状态，是存储在`Bundle`对象中的键值对集合。默认情况下，系统使用`Bundle`实例状态来保存`Activity`布局中每个View对象的相关信息(例如在EditText组件中输入文本值)。这样，如果您的`Activity`实例被销毁并重新创建，布局状态便会恢复为其先前的状态，且您无需编写代码。但是，您的`Activity`可能包含您要恢复的更多状态信息。录入追踪用户在`Activity`中的进程的成员变量。

**注意:为了使Android系统恢复Activity中视图的状态，每个视图必须具有android:id属性提供的唯一ID。**

##### 使用 `onSaveInstanceState()` 保存简单轻量的界面状态

当您的 `Activity` 开始停止时，系统会调用 `onSaveInstanceState()`方法，以便您的 `Activity` 可以将状态信息保存到实例状态 `Bundle` 中。此方法的默认实现保存有关 Activity 视图层次结构状态的瞬时信息，例如 `EditText` 微件中的文本或 `ListView` 微件的滚动位置。

`Bundel`对象并不适合保留大量数据，因为它需要在主线程上进行序列化处理并占用系统进程内存。如需要保存大量数据，您应组合使用持续性本地存储`onSaveInstanceState()`。例如

```
override fun onSaveInstanceState(outState: Bundle?) {
    // Save the user's current game state
    outState?.run {
        putInt(STATE_SCORE, currentScore)
        putInt(STATE_LEVEL, currentLevel)
    }

    // Always call the superclass so it can save the view hierarchy state
    super.onSaveInstanceState(outState)
}

companion object {
    val STATE_SCORE = "playerScore"
    val STATE_LEVEL = "playerLevel"
}
```

**注意：当用户显式关闭 `Activity` 时，或者在其他情况下调用 `finish()` 时，系统不会调用`onSaveInstanceState()`**

如需保存持久性数据（例如用户首选项或数据库中的数据），您应在 Activity 位于前台时抓住合适机会。如果没有这样的时机，您应在执行 `onStop()`方法期间保存此类数据。

##### 使用保存的实例状态恢复 Activity 界面状态

重建先前被销毁的Activity后，您可以从系统传递给`Activity`的`Bundle`中恢复保存的真实状态。`onCreate()`和`onRestoreInstanceState()`回调方法均会收到包含实例信息相同的`Bundle`。

因为无论系统是新建 Activity 实例还是重新创建之前的实例，都会调用 onCreate()方法，所以在尝试读取之前，您必须检查状态 Bundle 是否为 null。如果为 null，系统将新建 Activity 实例，而不会恢复之前销毁的实例。

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState) // Always call the superclass first

    // Check whether we're recreating a previously destroyed instance
    if (savedInstanceState != null) {
        with(savedInstanceState) {
            // Restore value of members from saved state
            currentScore = getInt(STATE_SCORE)
            currentLevel = getInt(STATE_LEVEL)
        }
    } else {
        // Probably initialize members with default values for a new instance
    }
    // ...
}
```

您可以选择实现系统在`onStart()`方法之后调用的`onRestoreInstanceState()`,而不是在`onCreate()`期间恢复状态。仅当存在要恢复的已保存状态，系统才会调用`onRestoreInstanceState(),`因此你无需检查`Bundle`是否为`null`。

```kotlin
override fun onRestoreInstanceState(savedInstanceState: Bundle?) {
    // Always call the superclass so it can restore the view hierarchy
    super.onRestoreInstanceState(savedInstanceState)

    // Restore state members from saved instance
    savedInstanceState?.run {
        currentScore = getInt(STATE_SCORE)
        currentLevel = getInt(STATE_LEVEL)
    }
}
```

