# Android性能调试技巧之Systrace

**Systrace**记录短时间内的设备活动。系统跟踪会生成跟踪文件，该文件可用于生成系统报告。

**Systrace**保证系统流畅度可以连续不间断地提供每秒60帧的运行状态。当出现掉帧时(也可称为**Jank**)，需要知道当前整个系统所处的状态，systrace便是最佳的选择。

## 通过python命令追踪系统记录

`systrace` 命令会调用 [Systrace 工具](https://developer.android.com/topic/performance/tracing?hl=zh-cn)，您可以借助该工具收集和检查设备上在系统一级运行的所有进程的时间信息



### 语法

如需为应用生成 HTML 报告，您需要使用以下语法通过命令行运行 `systrace`：

```bsh
   python systrace.py [options] [categories]
```

**用python命令的时候可能会提示需要安装pywin和six**

例如，以下命令会调用 `systrace` 来记录设备活动，并生成一个名为 `mynewtrace.html` 的 HTML 报告。此类别列表是大多数设备的合理默认列表。

```bash
$ python systrace.py -o mynewtrace.html sched freq idle am wm gfx view \
        binder_driver hal dalvik camera input res
    
```

如需查看已连接设备支持的类别列表，请运行以下命令：

```bash
$ python systrace.py --list-categories
```

### 命令和命令选项

| 命令和选项                                     | 说明                                                         |
| :--------------------------------------------- | :----------------------------------------------------------- |
| `-o file`                                      | 将 HTML 跟踪报告写入指定的文件。如果您未指定此选项，`systrace` 会将报告保存到 `systrace.py` 所在的目录中，并将其命名为 `trace.html`。 |
| `-t N | --time=N`                              | 跟踪设备活动 N 秒。如果您未指定此选项，`systrace` 会提示您在命令行中按 Enter 键结束跟踪。 |
| `-b N | --buf-size=N`                          | 使用 N KB 的跟踪缓冲区大小。使用此选项，您可以限制跟踪期间收集到的数据的总大小。 |
| `-k functions|--ktrace=functions`              | 追踪kernel函数，用逗号分隔                                   |
| `-a app-name|--app=app-name`                   | 追踪应用包名，用逗号分隔                                     |
| `--from-file=file-path`                        | 从文件中创建互动的systrace                                   |
| -e `<DEVICE_SERIAL`>,–serial=`<DEVICE_SERIAL`> | 指定设备                                                     |
| `-l, –list-categories`                         | 列举可用的tags                                               |

### category可取值：

| category   | 解释                           |
| :--------- | :----------------------------- |
| gfx        | Graphics                       |
| input      | Input                          |
| view       | View System                    |
| webview    | WebView                        |
| wm         | Window Manager                 |
| am         | Activity Manager               |
| sm         | Sync Manager                   |
| audio      | Audio                          |
| video      | Video                          |
| camera     | Camera                         |
| hal        | Hardware Modules               |
| app        | Application                    |
| res        | Resource Loading               |
| dalvik     | Dalvik VM                      |
| rs         | RenderScript                   |
| bionic     | Bionic C Library               |
| power      | Power Management               |
| sched      | CPU Scheduling                 |
| irq        | IRQ Events                     |
| freq       | CPU Frequency                  |
| idle       | CPU Idle                       |
| disk       | Disk I/O                       |
| mmc        | eMMC commands                  |
| load       | CPU Load                       |
| sync       | Synchronization                |
| workq      | Kernel Workqueues              |
| memreclaim | Kernel Memory Reclaim          |
| regulators | Voltage and Current Regulators |

### 三、 快捷操作

####  导航操作

| 导航操作 | 作用                   |
| :------- | :--------------------- |
| w        | 放大，[+shift]速度更快 |
| s        | 缩小，[+shift]速度更快 |
| a        | 左移，[+shift]速度更快 |
| d        | 右移，[+shift]速度更快 |

#### 快捷操作

| 常用操作 | 作用                                        |
| :------- | :------------------------------------------ |
| f        | **放大**当前选定区域                        |
| m        | **标记**当前选定区域                        |
| v        | 高亮**VSync**                               |
| g        | 切换是否显示**60hz**的网格线                |
| 0        | 恢复trace到**初始态**，这里是数字0而非字母o |

| 一般操作 | 作用                                |
| :------- | :---------------------------------- |
| h        | 切换是否显示详情                    |
| /        | 搜索关键字                          |
| enter    | 显示搜索结果，可通过← →定位搜索结果 |
| `        | 显示/隐藏脚本控制台                 |
| ?        | 显示帮助功能                        |

#### 模式切换

1. Select mode: **双击已选定区**能将所有相同的块高亮选中；（对应数字1）
2. Pan mode: 拖动平移视图（对应数字2）
3. Zoom mode:通过上/下拖动鼠标来实现放大/缩小功能；（对应数字3）
4. Timing mode:拖动来创建或移除时间窗口线。（对应数字4）

### 自定义systrace

```
import android.os.Trace; 
Trace.traceBegin(long traceTag, String methodName)
Trace.traceEnd(long traceTag)
```

**在程序调试中无法正常调试**

原因不支持app使用的

```
@UnsupportedAppUsage 
public static void traceBegin(long traceTag, String methodName) {
    if (isTagEnabled(traceTag)) {
        nativeTraceBegin(traceTag, methodName);
    }
}

    @UnsupportedAppUsage
    public static boolean isTagEnabled(long traceTag) {
        long tags = nativeGetEnabledTags();
        return (tags & traceTag) != 0;
    }
```

### 通过应用插桩生成跟踪日志

```kotlin
Debug.startMethodTracing("sample")
Debug.stopMethodTracing()
```

可以通过官方提供的这种方式检测你的应用，可让您更精确地控制设备何时开始和停止记录信息。

### 查看生成日志的位置

![img](https://developer.android.com/studio/images/profile/locating_log_with_device_explorer-2X.png?hl=zh-cn)

1. 