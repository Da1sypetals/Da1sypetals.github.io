#import "/config.typ": template, tufted
#show: template.with(
  title: "苹果终于推出了text-based的命令行gpu profiler。它还是有点用的",
  date: datetime(year: 2026, month: 8, day: 4),
)

== 新的工具！Xcode 27 & `gpudebug`

苹果终于在WWDC26推出了text-based的GPU profiler。此前所有的GPU性能数据都必须在GUI上查看，因为苹果的.gputrace是一个闭源格式，必须用闭源软件 Instruments 才能查看。

在2025年及以前这当然是最方便的，那时候还没有能稳定调用工具的LLM Agent；但是现在大家已经不太会写代码了，绝大多数分析都丢给AI写了，然而并不是所有模型都有多模态，往往只有那些总参数量足够大的模型才会有质量好的多模态，因此让Agent读GUI实际上是低效且不现实的事情。好在今年终于随着Xcode 27推出了新的text-based GPU profiler工具：`gpudebug`。
- https://developer.apple.com/documentation/xcode/investigating-gpu-issues-with-ai-agents
- https://developer.apple.com/documentation/xcode/debugging-with-interactive-command-line-tools

text-based CLI工具的最大优点就是Agent可以自主调用、自主分析工具输出，就形成了profile -> 优化 -> profile again的最基本的PGO闭环。借鉴现在已经大量存在的基于`nsys`, `ncu`的在NVIDIA平台上优化深度学习系统和算子的Agent，我们也可以用一段简单的prompt让Agent开始PGO的工作。

下面这段prompt并没有设定很严格的工作流程和标准，因此你可能需要一个足够强的LLM。你还需要一个示例输入用来喂给你需要优化的那个系统。

```
# Apple Silicon平台 Metal / MLX 性能优化

## 仓库自身材料
开始工作前必须完整读取目标仓库及其父目录中的 `AGENTS.md`。

## 本机工具链与设备
sw_vers
system_profiler SPHardwareDataType
xcode-select -p
xcodebuild -version
xcrun --show-sdk-path
xcrun --find gpudebug
xcrun gpudebug --version
xcrun --find gpucapture
必须通过 `xcrun` 解析当前选中 Xcode 内的工具。禁止根据 PATH 中同名程序推断当前工具链。
必须读取当前 SDK 的 Metal headers。通过 `xcrun --show-sdk-path` 取得 SDK 根目录，再读取 `System/Library/Frameworks/Metal.framework/Headers/` 下与 capture、command buffer、compute pipeline、resource、counter 相关的声明和注释。API 可用性以当前 SDK headers 为准。
## GPU capture 与 gpudebug
必须完整阅读本机提供的以下 man page：
man gpudebug
man gpucapture
你的主要优化依据是`gpudebug`工具，你必须遵循Profile-guided Opimization对程序进行性能分析和性能优化。
必须使用 `gpudebug <command> ?` 阅读准备调用的每个子命令的上下文帮助。包括但不限于 `list`、`go`、`info`、`fetch`、`find`、`profile`、`wait`、`status`。参数、对象层级、会话生命周期和 JSON 输出格式以本机help文档为准。
必须完整阅读 Apple 官方文档：
- [Investigating GPU issues with AI agents](https://developer.apple.com/documentation/xcode/investigating-gpu-issues-with-ai-agents)
- [Debugging with interactive command-line tools](https://developer.apple.com/documentation/xcode/debugging-with-interactive-command-line-tools)
真实推理生成的 `.gputrace` 是 GPU 工作负载的事实来源。必须读取 trace 内的以下对象树：
- `commands`
- `performance`
- `api_calls`
- `resources`
必须从当前 trace 动态读取可用的 counter、shader、encoder、command buffer、pipeline 和 resource。禁止沿用另一台机器、另一个系统版本或另一份 trace 的对象编号与 counter 名称。
必须读取生成 trace 的 capture 代码或 capture 命令，确认预热、同步、求值、capture 起止位置、输入读取和输出读取所在的边界。MLX 使用 lazy evaluation；测量区间由实际求值边界决定。
必须将原始 `.gputrace` 与生成它的可执行文件、source commit、模型、输入、构建配置、工具链和 capture 边界关联保存。缺少关联信息的 trace 无法支持可复核的性能判断。
你需要探索gpudebug提供的更多输出，不限于上面所描述的输出，以对程序性能进行更精确的分析。

## Benchmark 与正确性
在优化的过程中，你需要确保程序的运行结果和优化前保持一致，数值误差应当在浮点数运算顺序误差的可接受范围之内。你需要用（最大绝对误差、平均绝对误差）来衡量程序的正确性。
```

== 尝试

使用`gputrace`需要Xcode 27和*MacOS 27 Golden Gate*。工具链和系统都需要升级到最新版本，在2026年8月4日，MacOS 27还处于beta。

下面是一个跑了大约1h的优化任务，优化了一个音频Vocoder神经网络的运行效率。使用的Agent是Codex，模型是GPT 5.6 Sol，优化前的代码是一个他自己在几天前从PyTorch 1:1 移植到MLX（Rust）的代码。
#image("./opt.png")

转换的生成的歌声（我和AI合唱，经过了混音）：

#html.video(width: 400, src: "feitian.mp4")

可以看到效率和效果还是非常好的。在Amdahl's Law的指导下，对于整个系统来说，这个网络进一步优化已经没有多大的意义了，就没有让Agent继续进行下去了。

这确实开放了大量实用中小型神经网络在MacOS上部署的机会！在AI时代脑子感觉被驴踢了的苹果终于知道对的事情是什么了。在做“让自己的操作系统更容易被Agent使用”这件事上，在MacOS上做，终究还是比Windows Powershell那种Agent至今还会犯删C盘低级错误的垃圾系统好做的。
