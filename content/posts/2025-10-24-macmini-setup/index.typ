#import "/config.typ": template, tufted
#show: template.with(
  title: "我的 Mac Mini Setup",
  description: "Mac Mini M4 配置记录",
  date: datetime(year: 2025, month: 10, day: 24),
)

= 我的 Mac Mini Setup

花点时间配置一下我的Mac Mini.

== 配件

- Mac Mini M4 最丐版，3349
- Samsung 990 evo plus, 996
- 海备思硬盘盒+扩展坞，471
- Redmi 显示器 4K 60Hz，1449
- 鼠标，65

== Setup

- 把系统装到外接硬盘里：#link("https://www.bilibili.com/video/BV1m2rUYcEQA")[教程]
- 鼠标滚轮反向

== 软件

=== 浏览器

我的需求是：*Vertical tab, 以及熟悉*。

因为我之前在windows用的是edge，在mac上一搜居然也有，于是就直接用edge懒得换了。

=== Terminal

==== Emulator: iTerm2:
- 主题：#link("https://github.com/phureewat29/fairyfloss")[FairyFloss]，一个很girly的主题
- 字体：Jetbrains Mono

==== Shell: fish
- 注意去github装 fish 4
- 设置默认shell：有两个步骤，两个都要做

=== 笔记

ima.copilot，主要为了省心。

=== Brew换源

详见：#link("../brew-sources/")[这篇帖子]

=== 实用软件

```
typst
fd (replacement of find)
ripgrep
```
