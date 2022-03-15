# 						自定义View

### View是什么

Android自身提供了复杂且强大的控件库提供开发人员使用，可帮助开发人员根据基本布局类View和ViewGroup构建页面，该平台包含各种预构建的View和ViewGroup子类，分别称为控件和布局，可提供来构建界面。

可用的部分微件包括 `Button`、`TextView`、`EditText`、`ListView`、`CheckBox`、`RadioButton`、`Gallery`、`Spinner`，以及具有特殊用途的 `AutoCompleteTextView`、`ImageSwitcher` 和 `TextSwitcher`。

可用布局包括 `LinearLayout`、`FrameLayout`、`RelativeLayout` 等

如果预构建的控件和布局不能满足开发人员需求可以创建自己的`View`子类。

View的相关方法

![image-20210222221012202](/Users/wangllijian/Library/Application Support/typora-user-images/image-20210222221012202.png)

### View绘制流程

绘制流程大致可以分为测量过程`onMeasure()`布局过程`onLayout()`绘制过程`onDraw()`

**测量阶段**

从上到下递归地调用每个 View 或者 ViewGroup 的 measure() 方法，测量他们的尺寸并计算它们的位置。
**布局阶段**

从上到下递归地调用每个 View 或者 ViewGroup 的 layout() 方法，把测得的它们的尺寸和位置赋值给它们。

view或ViewGroup的布局过程

1.测量阶段，measure()方法被父View调用，在measure()中做一些准备和优化工作后,调用onMeasure()来进行实际的自我测量。onMeasure()做的事,View和ViewGroup不一样。

**View**：View在·onMeasure()·中会计算出自己的尺寸然后保存。

**ViewGroup**:ViewGroup在onMeasure()中会调用所有子View的measure()让它们进行自我测量，并根据子View计算出期望尺寸来计算出它们的实际尺寸和位置,同时，它也会根据子View的尺寸和位置来计算出自己的尺寸然后保存。

2.布局阶段，`Layout()`方法被View调用，在`layout()`中它会保存父View传进来的自己的位置和尺寸，并且调用`onLayout()`来进行实际的内部布局。`onLayout()` 做的事， `View` 和 `ViewGroup` 也不一样：

1. **View**：由于没有子 View，所以 `View` 的 `onLayout()` 什么也不做。
2. **ViewGroup**：`ViewGroup` 在 `onLayout()` 中会调用自己的所有子 View 的 `layout()` 方法，把它们的尺寸和位置传给它们，让它们完成自我的内部布局。

**绘制过程**

`onDraw()` 方法为您提供了一个 `Canvas`，您可以在其上实现所需的任何东西。

- 需要绘制什么，由 `Canvas` 处理
- 如何绘制，由 `Paint` 处理。

**注意**：这不适用于实现 3D 图形。如果您想要使用 3D 图形，则必须扩展 `SurfaceView`（而不是 View），并从单独的线程绘制。

![image-20210222223752644](/Users/wangllijian/Library/Application Support/typora-user-images/image-20210222223752644.png)

***部分内容Hencoder本人很喜欢的作者。**

### 硬件加速

所谓硬件加速，指的是把某些计算工作交给专门的硬件来做，而不是和普通的计算工作一样交给 CPU 来处理。这样不仅减轻了 CPU 的压力，而且由于有了「专人」的处理，这份计算工作的速度也被加快了。这就是「硬件加速」。

从 Android 3.0（API 级别 11）开始，Android 2D 渲染管道支持硬件加速，也就是说，在 `View` 的画布上执行的所有绘制操作都会使用 GPU。启用硬件加速需要更多资源，因此应用会占用更多内存。

您可以在以下级别控制硬件加速：

- 应用
- Activity
- 窗口
- 视图

#### **应用级别**

在 Android 清单文件中，将以下属性添加到 [``](https://developer.android.com/guide/topics/manifest/application-element?hl=zh-cn) 标记中，为整个应用启用硬件加速：

```xml
    <application android:hardwareAccelerated="true" ...>
```



#### Activity 级别

如果全局启用硬件加速后，您的应用无法正常运行，则您也可以针对各个 Activity 控制硬件加速。要在 Activity 级别启用或停用硬件加速，您可以使用 ·activity·元素的 `android:hardwareAccelerated` 属性。以下示例展示了如何为整个应用启用硬件加速，但为一个 Activity 停用硬件加速：

```xml
    <application android:hardwareAccelerated="true">
        <activity ... />
        <activity android:hardwareAccelerated="false" />
    </application>
    
```

#### 窗口级别

如果您需要实现更精细的控制，可以使用以下代码为给定窗口启用硬件加速：

```java
    getWindow().setFlags(
        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
    
```

#### 视图级别

您可以使用以下代码在运行时为单个视图停用硬件加速：

```java
    myView.setLayerType(View.LAYER_TYPE_SOFTWARE, null);
```

## 确定视图是否经过硬件加速

有时，应用有必要了解当前是否经过硬件加速，尤其是对于自定义视图等内容。如果您的应用执行大量自定义绘制，但并非所有操作都得到新渲染管道的正确支持，这就会特别有用。

您可以通过以下两种不同的方式检查应用是否经过硬件加速。

- 如果 `View` 已附加到硬件加速窗口，则 `View.isHardwareAccelerated()` 会返回 `true`。
- 如果 `Canvas` 经过硬件加速，则 `Canvas.isHardwareAccelerated()` 会返回 `true`

如果您必须在绘制代码中执行这项检查，请尽可能使用 `Canvas.isHardwareAccelerated()`，而不是 `View.isHardwareAccelerated()`。如果某个视图已附加到硬件加速窗口，则仍可以使用未经过硬件加速的画布进行绘制。例如，将视图绘制为位图以进行缓存就会发生这种情况。

