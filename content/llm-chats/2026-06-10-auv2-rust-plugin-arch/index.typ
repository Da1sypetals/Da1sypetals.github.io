#import "/config.typ": template, tufted
#show: template.with(
  title: "用Rust实现AUv2格式的Logic Pro插件的一种可能架构",
  date: datetime(year: 2026, month: 6, day: 10),
)


== 架构：Rust DSP + Web UI + 最薄 C++ 桥接

=== 核心思路

将 C++ 代码压缩到*绝对不可替代的最小集合*——即 JUCE 要求你必须用 C++ 实现的那些接口。所有"有逻辑"的代码全部移出。

---

=== 三个层

*1. Rust 层 — 所有 DSP 和业务逻辑*

Rust crate 编译为静态库（`libdsp_engine.a`），通过 `extern "C"` 暴露一组极简的 C ABI 函数：

- `dsp_create() -> *mut c_void` — 创建引擎实例
- `dsp_destroy(engine)` — 销毁
- `dsp_prepare(engine, sample_rate: f64, max_block_size: i32)` — 初始化/重置
- `dsp_process(engine, in_l, in_r, out_l, out_r, num_samples)` — 处理音频
- `dsp_set_parameter(engine, param_index: u32, value: f32)` — 设置参数
- `dsp_get_state(engine, buffer, buffer_size) -> usize` — 序列化内部状态
- `dsp_set_state(engine, buffer, size)` — 反序列化状态

所有 DSP 算法、采样率转换、模式切换、preset 数据、内部状态管理——全部在 Rust 中实现。C++ 侧完全不接触信号处理逻辑。

*2. Web 层 — 所有 UI*

这个项目已经有了完整的 WebView 路径。在 macOS 上使用 WKWebView，JUCE 8 提供了 `WebSliderRelay` + `WebSliderParameterAttachment` 的双向绑定机制。你的 UI 代码是纯 TypeScript/HTML/CSS，通过 `window.__JUCE__.sliderState` 与参数交互。

UI 层负责：所有可视化渲染（Canvas/WebGL）、旋钮/滑块控件、电平表、粒度可视化等等。这部分和 C++ 零耦合——它只和 JUCE 的 WebView relay 协议通信。

*3. C++ 层 — 纯粹的胶水*

C++ 只做 JUCE 框架强制你做的事情，大约 *150-200 行*：

`PluginProcessor.cpp` 的全部内容压缩为：
- 构造函数：创建 APVTS + 调用 `dsp_create()`
- 析构函数：调用 `dsp_destroy()`
- `prepareToPlay`：调用 `dsp_prepare()`
- `processBlock`：从 APVTS 读取所有参数的原子值 → 调用 `dsp_set_parameter()` 逐个传入 → 调用 `dsp_process()` 传入/传出 float 指针
- `getStateInformation`：调用 `dsp_get_state()` 拿到 bytes，附加到 APVTS 的 XML 序列化中
- `setStateInformation`：解析后调用 `dsp_set_state()`
- `createParameterLayout`：声明参数列表（这必须在 C++ 中，因为 APVTS 是 JUCE 类型）

`PluginEditor.cpp` 几乎不变——它已经是一个很薄的 WebView 容器了。做的事情只有：
- 创建 relay + attachment
- 创建 WebBrowserComponent，注册 resource provider
- Timer 回调里调用 `evaluateJavascript` 推送 metering 数据

`createPluginFilter()` 工厂函数——这是 JUCE 的入口点，一行。

---

=== 什么绝对无法移出 C++

1. *`juce::AudioProcessor` 子类声明* — JUCE 的 AUv2 wrapper 通过这个类发现你的插件
2. *APVTS 参数布局* — 必须在 C++ 中构造，因为 AU host 通过 JUCE 的接口来枚举参数
3. *`juce::AudioProcessorEditor` 子类* — WebView 宿主容器
4. *WebSliderRelay 声明和 attachment 创建* — JUCE 8 的 WebView 参数绑定机制是 C++ 对象
5. *`createPluginFilter()` 工厂函数* — AU 入口

但这些全都是*无逻辑的声明式代码*——不包含任何你需要"审查"的算法。

---

=== 构建系统集成

CMake 中使用 `corrosion`（一个成熟的 CMake-Rust 桥接模块）：

```cmake
include(FetchContent)
FetchContent_Declare(Corrosion GIT_REPOSITORY https://github.com/corrosion-rs/corrosion.git)
FetchContent_MakeAvailable(Corrosion)

corrosion_import_crate(MANIFEST_PATH dsp/Cargo.toml)
target_link_libraries(MyPlugin PRIVATE dsp_engine)
```

Rust crate 住在插件目录下的 `dsp/` 文件夹里，`cargo build --release` 产出 `libdsp_engine.a`，CMake 自动链接进 JUCE 插件 bundle。

---

=== 对于 AUv2 Only

在 CMakeLists.txt 中把 `FORMATS` 只设为 `AU`：

```cmake
juce_add_plugin(MyPlugin
    FORMATS AU
    AU_MAIN_TYPE kAudioUnitType_Effect
    ...
)
```

不生成 VST3，不生成 Standalone。只产出 `.component` bundle，直接部署到 `~/Library/Audio/Plug-Ins/Components/`。

---

=== 项目目录结构

```
plugins/MyPlugin/
├── dsp/                    ← Rust crate（所有 DSP）
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs          ← extern "C" 接口
│       ├── engine.rs       ← DSP 引擎核心
│       └── ...
├── Source/                 ← C++ 桥接（~150 行）
│   ├── PluginProcessor.h
│   ├── PluginProcessor.cpp
│   ├── PluginEditor.h
│   ├── PluginEditor.cpp
│   └── ffi.h              ← Rust FFI 声明
├── ui/                     ← Web UI（TypeScript）
│   ├── src/
│   ├── index.html
│   ├── package.json
│   └── vite.config.ts
├── CMakeLists.txt
└── status.json
```

---

=== 为什么这个方案是可行的

1. *Rust → C FFI 是零开销的*。Rust 编译为 native code，`extern "C"` 函数调用就是普通的函数调用，没有序列化、没有 IPC、没有 overhead。传递 `*mut f32` 指针给 Rust 处理音频 buffer，和在 C++ 里直接写一模一样快。

2. *JUCE 的 WebView 路径已经证明可行*。CloudWash 就是一个完整的例子——UI 全在 JS 里，C++ 只是容器。你甚至不需要修改这个模式，只是复用它。

3. *macOS 上 Rust 静态库链接到 C++ 完全成熟*。`cargo build --target aarch64-apple-darwin --release` 产出标准 `.a` 文件，CMake 链接它就像链接任何其他 C 库一样。Universal Binary (arm64 + x86_64) 也没问题，分别编译两个 target 然后 `lipo` 合并。

4. *你不需要 Rust 的 AU 框架*。JUCE 负责所有 AU 协议层面的事情（Component registration, parameter discovery, state save/load, audio threading）。Rust 只是一个"被调用的 DSP 函数库"，它不知道也不关心自己运行在什么宿主格式里。

---

=== 你最终需要"会审"的 C++ 代码量

大约 *4 个文件、200 行总计*，全部是机械性的声明代码：
- 参数列表声明（`addParameter(...)`）
- FFI 函数调用转发
- WebView relay 对象创建

没有循环、没有算法、没有指针运算、没有内存管理。你需要审查的所有"真正的代码"都在 Rust 和 TypeScript 中。

---

有什么想进一步讨论的吗？比如 Rust FFI 的具体接口设计、Web UI 的参数绑定协议细节、或者 CI/CD 构建流程。
