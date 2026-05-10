#import "/config.typ": template, tufted
#show: template.with(
  title: "自动求导, 道阻且长",
  date: datetime(year: 2024, month: 12, day: 29),
)

#link("https://github.com/Da1sypetals/Symars")[Symars] Rust代码生成库和 #link("https://github.com/Da1sypetals/Raddy")[Raddy] 自动求导库的来龙去脉

== 故事的起因

前段时间读了一些物理模拟的论文，想尝试复现一下。下手点先选了 #link("https://graphics.pixar.com/library/StableElasticity/paper.pdf")[stable neo hookean flesh simulation]。

这之中就涉及到了：对能量的本构模型求导数（一阶梯度，二阶 hessian 矩阵）。

从 #link("https://www.tkim.graphics/DYNAMIC_DEFORMABLES/")[*Dynamic Deformables*] 这篇文章中可以看出推导这个公式就要花不少功夫，于是我搜了搜更多东西，尝试寻找一些其他的解决方法：
- 求符号导数，然后进行代码生成；
- 自动求导。

找到的资料中，前者有 MATLAB 或者 SymPy，后者有 PyTorch 等深度学习库，和更适合的 #link("https://github.com/patr-schm/TinyAD")[TinyAD]。

但是一个致命的问题来了：上述工具都在 C++ 的工具链上，而我不会 C++。

我只好换一门我比较熟悉的语言：Rust。这是一切罪恶的开始...

== 一条看起来简单的路

目前 Rust 还没有一个可以求二阶 hessian 的自动求导库。SymPy 目前还不能生成 Rust 代码（可以，但是有 bug）。

考虑实现难度我先选了后者：从 SymPy 表达式生成 Rust 代码。于是有了 #link("https://github.com/Da1sypetals/Symars")[Symars]。

== 再去走没走过的路

为了解决上述问题，我打算尝试原来放弃的那条路：自动求导。

=== 正确的走路姿势

- 每个求导链路上的标量值都带一个相对变量的梯度和 hessian
- 有大量需要实现 `(&)Type` 和 `(&)Type` 之间的 operator trait
- 用 Python 脚本进行代码生成（字符串拼接）
- 测试：用 `symars` 对每个测试表达式生成符号 `grad` 和 `hessian` 的代码，然后和求导结果交叉验证

== 稀疏之路

针对稀疏矩阵单独实现了其 hessian 的组装过程：

- 定义一个问题，即实现一个 `Objective<N>` trait
- AD 自动组装 `grad` 和 `hess`（稀疏）
- 最后用户手动将多个 `grad` 和 `hess` 加和

```rust
impl Objective<4> for SpringEnergy {
    type EvalArgs = f64; // restlength

    fn eval(&self, variables: &advec<4, 4>, restlen: &Self::EvalArgs) -> Ad<4> {
        let p1 = advec::<4, 2>::new(variables[0].clone(), variables[1].clone());
        let p2 = advec::<4, 2>::new(variables[2].clone(), variables[3].clone());
        let len = (p2 - p1).norm();
        let e = make::val(0.5 * self.k) * (len - make::val(*restlen)).powi(2);
        e
    }
}
```

#figure(image("spring.gif"))

== 结语

收获：
- 熟悉了自动求导
- 用 AI 写文档
- Happiness!
