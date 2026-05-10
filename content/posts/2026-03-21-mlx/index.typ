#import "/config.typ": template, tufted
#show: template.with(
  title: "MLX 初体验",
  description: "苹果 MLX 框架初体验与性能优化",
  date: datetime(year: 2026, month: 3, day: 21),
)

= MLX 初体验



从公司领到了人生第一台MacBook，据说苹果的GPU有一套虽然没有CUDA那么庞大，但是封装的比较好的生态，于是开始尝试玩苹果的GPU。

== 跑通

首先跑通了mlx-vlm的GLM-OCR。这个是一键安装的，识别率相比之前用的软件内置的垃圾OCR有了质的飞跃。于是想把他做成内置的屏幕识别OCR App。

AI做这种项目很快，Swift + AppKit 搓一个出来不过半小时的事情，调一调UI就能用了。

但是，我实在是不希望运行库依赖Python环境，主要不是因为大小，而是因为脆弱、不好分发。

== 迁移

mlx有binding的语言：Python，Swift，C（official），Rust（unofficial）。

显然我没有能力指挥AI写C项目。因此在Swift和Rust之间进行选择。我想到这部分代码很可能是需要人工介入的，因此选了我更熟悉的Rust。

让Claude扫一遍仓库之后，得知复刻仓库需要：mlx-rs，tokenizer，minijinja，swift-huggingface等库。

> 显然这些库都没有在LLM的训练素材里面出现过足够次数。一个比较好的办法把库直接拉下来提供给LLM参考。

== 实现

参考#link("https://fishshell.com/blog/rustport/")[忒修斯之鱼]，port采取的是忒修斯之船的方式。

- 先让LLM换掉decoder
- 再换掉Vision Encoder
- 最后换掉tokenizer和http server

于是出现了第一个能工作的版本。数值并不bit exact match，一开始我还比较担心；但是整个移植进行完之后，quality-wise是正确的。

== 性能问题

Python版本有100～110 tok/s；Rust版只有33 tok/s.

首先我让codex帮忙review，他很快就找到了第一个卡点：Python使用预分配、按每隔N个token的threshold，chunk增长的KVCache；Rust则是用的mlx-rs自带的naive KVCache。移植完这个KVCache之后，速度上升到36tok/s。

但是显然这个性能并不好。一番摸索之后，我了解到了瓶颈：
1. fp32 -> bf16类型转换占据了特别多的GPU时间
2. 大部分GEMM都是在fp32下计算的

解决方法是SDPA的输出手动cast到bf16。

这样修复后，性能直接达到120 tok/s，非常棒的速度。

#figure(image("orchid-use.gif"), caption: [Orchid App])

代码：
- App: #link("https://github.com/blossom-slopware/Orchid")
- Rust 模型推理：#link("https://github.com/blossom-slopware/glm-ocr-rs/tree/main")

== 小剧场

Rust编译是真的慢🤣
静态链接了几乎所有依赖，导致CI的时候如果cache miss就要编译巨量的东西。
