#import "/config.typ": template, tufted
#show: template.with(
  title: "cuTile 历险记，第2集：eDSL, DX & LSP",
  description: "为 cuTile 编写 LSP 类型提示工具",
  date: datetime(year: 2025, month: 12, day: 11),
)

= cuTile 历险记，第2集：eDSL, DX & LSP

== eDSL，开发难度，以及DX

DSL（Domain-Specific Language，领域特定语言）是一种专为特定问题领域设计的编程语言。

听某写了很多个triton kernel的大佬同事说，主要的debug triton代码的方式是：
- 跑一遍看报错
- triton提供的print
- 读IR

并没有能够提供良好的IDE功能的软件可以用，导致许多可以静态知道的类型信息需要靠运行时报错来修复，造成了DX在这方面的欠缺。

== 找回静态的信息

=== 编译器的一半的一半的一半

先把cuTile的整个编译流程切一切。

- 上半：开源部分
  - 上半：python -> cutile-python-ir (python实现)
    - 参数检查，语法检查，类型检查
    - 基本优化
  - 下半：cutile-python-ir -> TileIR (C++实现)
- 下半：`tileiras`

=== 需求

尝试写一个软件，找回这些静态的信息，并显示到编辑器上。

== 实现

=== 大致结构

- 查看infer type pass生成的IR可以发现大致结构是这样的递归定义：
  ```
  Program = list[Stmt]
  Stmt = Block | Assign
  Block = for + list[Stmt] | if + list[Stmt] + else + list[Stmt]
  ```

- 标识符：
  - `$` 开头的标识符是编译器生成的变量
  - 没有 `$` 开头的标识符是代码原有的变量

=== 类型检查

通过每次 assign 的 IR，检查等号左边标识符如果不是 `$` 开头的，那么就把这一次 assign 对应的 type 信息添加到所需的 type 信息里面。

=== 输入参数

需要输入的类型才能推断出中间变量的类型：
- tensor: dtype, ndim
- scalar: dtype, 是否在编译期确认(constant)

=== LSP server

使用`pygls`库实现LSP server。

1. **Tile type hints**: 将原代码和输入参数组装成运行脚本，得到IR，提供inlay hints。
2. **Diagnostics**: 捕获所有`TileError`，在对应位置显示红色diagnostics。

== （半）成品

#figure(image("typehint.png"))
