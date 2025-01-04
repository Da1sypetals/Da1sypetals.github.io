#import "/book.typ": book-page
#show: book-page.with(title: "Diff road")
 

// =================== Content ===================

= 求导之路，道阻且长
*TL;DR: I made #link("https://github.com/Da1sypetals/Raddy", "Raddy") the forward autodiff library, and #link("https://github.com/Da1sypetals/Symars", "Symars") the symbolic codegen library.* \

If you are interested, please give it a star and use it #emoji.heart

== _#link(<tag:eng>, "English Version")_

#set heading(numbering: "1.")

= 故事的起因：

前段时间读了一些物理模拟的论文，想尝试复现一下。下手点先选了 #link("https://graphics.pixar.com/library/StableElasticity/paper.pdf", "stable neo hookean flesh simulation")，但是选了什么并不重要。重要的是，“现代”的物理模拟很多是隐式模拟，需要用牛顿法解一个优化问题。

这之中就涉及到了：对能量的本构模型求导数（一阶梯度，二阶 hessian 矩阵）。这之中还涉及到从 `small and dense` 的 hessian 子矩阵组装成 `large and sparse` 的完整 hessian。这是一个蛮精细的活，一不小心就会出现 `undebuggable` 的 bug。

#linebreak()

从 *#link("https://www.tkim.graphics/DYNAMIC_DEFORMABLES/","Dynamic Deformables")* 这篇文章中可以看出推导这个公式就要花不少功夫（就算是看懂论文里的 notation 也要好一会儿），于是我搜了搜更多东西，尝试寻找一些其他的解决方法：我不是很想在精细的 debug 上花很多时间。最终找到的解决方法有两种：
- 求符号导数，然后进行代码生成；
- 自动求导。

#linebreak()

找到的资料中，前者有 MATLAB 或者 SymPy，后者有 PyTorch 等深度学习库，和更适合的 #link("https://github.com/patr-schm/TinyAD", "TinyAD").


#text(size: 13pt)[为什么说更适合？因为深度学习库的求导是以tensor为单位的，但是我这里的求导需要以单个标量为单位，粒度不同，深度学习库可能会跑出完全没法看的帧率。]

#linebreak()

但是一个致命的问题来了：上述工具都在 C++ 的工具链上，而我不会 C++（或者，我会一点点 C++，但是我不会 CMake，因此不会调包。我曾经花了三天尝试在项目里用上 Eigen，然后失败告终，印证了我能力不行的事实）。我只好换一门我比较熟悉的语言：Rust。这是一切罪恶的开始...

= 一条看起来简单的路

目前 Rust 还没有一个可以求二阶 hessian 的自动求导库（至少我在 crates.io 没搜到）。  
SymPy 目前还不能生成 Rust 代码（可以，但是有 bug）。  
考虑实现难度我先选了后者：从 SymPy 表达式生成 Rust 代码。于是有了 #link("https://github.com/Da1sypetals/Symars", "Symars")。
#linebreak()

SymPy 提供的访问符号表达式的数据结构是树的形式，节点类型是运算符类型（`Add`, `Mul`, `Div`, `Sin`, 等等）或者常数/符号，节点的孩子是 operand 操作数。实现代码生成的思路就是按深度优先遍历树，得到孩子的表达式，然后再根据节点类型得到当前节点的表达式。边界条件是当前节点是常数，或者符号。
#linebreak()

实现完了之后，我拿着生成的导数去先写一个简单的隐式弹簧质点系统；但是还是在 hessian 组装上消耗了很多时间在排查 index 打错这种 bug 上。

= 再去走没走过的路

为了解决上述问题，我打算尝试原来放弃的那条路：自动求导。方案是在 Rust 里面使用 TinyAD。

== 一条路的两种走法

一开始想了两个方法：毕竟我不懂 C++，可能相比于看懂整个 TinyAD 的 codebase，做一套 FFI 更现实一些。
#linebreak()

但是我发现，项目 clone 下来之后，我甚至不会拉依赖不会编译（什么赛博残废）。
#linebreak()

然后我重新观察了 TinyAD 的 codebase，发现核心逻辑大概在 ~1000 行代码，似乎不是不可能在完全不运行这个项目的前提下把代码复刻一遍。说干就干，于是有了#link("https://github.com/Da1sypetals/raddy", "Raddy")：

== 正确的走路姿势

找到了正确的走路姿势，开始着手实现。说一些实现细节：
- 每个求导链路上的标量值都带一个相对变量的梯度和 hessian，所以肉眼可见的 memory overhead 比较严重；一个提醒用户的方法是不实现 `Copy` trait，在需要一个副本的时候 `explicit clone`。
- 有大量需要实现 `(&)Type` 和 `(&)Type` 之间的 operator trait，组合有 `2 * 2 = 4` 种，这意味着相同的代码要写 4 次。于是考虑引进某些元编程的方法：
  - 用宏 `macro` 批量实现；
  - 用 Python 脚本进行代码生成。

#linebreak()
考虑到宏会让 `rust-analyzer` 罢工，但是我离开 LSP 简直活不了，于是选择了后者。具体代码见 `meta/` 目录，其实没啥技术含量，就是字符串拼接。

#linebreak()
- 测试：我要如何验证我求出来的导数是对的？第一个想法就是用我前面写过的 `symars`，对每个测试表达式生成其符号 `grad` 和 `hessian` 的代码，然后和求导结果交叉验证，然后让这些测试表达式尽可能覆盖所有实现过的方法。
  - `symars` 居然表现得很不错，稳定使用没有发现 bug。

== 稀疏之路

稠密的矩阵用一块连续的内存空间表示相邻的值；稀疏矩阵动辄上万的边长（上亿的总元素数 `numel`）不允许。于是针对稀疏矩阵单独实现了其 hessian 的组装过程：

#linebreak()
- 定义一个问题，即实现一个 `Objective<N>` trait，需要：
  - 确定 problem size `N`（这是编译器要求 const generics 必须是编译期常量）
  - 实现计算逻辑
  - 比如：弹簧质点系统的逻辑（其实就是高中学的胡克定律，$E=1/2 k x^2$）：
    ```rust
    impl Objective<4> for SpringEnergy {
        type EvalArgs = f64; // restlength

        fn eval(&self, variables: &advec<4, 4>, restlen: &Self::EvalArgs) -> Ad<4> {
            // extract node positions from problem input:
            let p1 = advec::<4, 2>::new(variables[0].clone(), variables[1].clone());
            let p2 = advec::<4, 2>::new(variables[2].clone(), variables[3].clone());

            let len = (p2 - p1).norm();
            let e = make::val(0.5 * self.k) * (len - make::val(*restlen)).powi(2);

            e
        }
    }
    ```

- 定义这个稀疏向量中的哪些分量，需要作为这个问题的输入（提供其 indices，`&[[usize; N]]`）。
- AD 自动组装 `grad` 和 `hess`（稀疏），涉及到 index map 的问题；
- 最后用户手动将多个 `grad` 和 `hess` 加和。这一步就没有 index map 的问题了，就是简单的矩阵加法（triplet matrix 就更简单，直接把多个 triplet vector 接在一起就好了）。
#linebreak()

添加测试之前总共有2.2k行代码，添加测试之后项目总代码量膨胀到了18k行，再次证明数LOC是个没啥用的事情。

#linebreak()
最后，经过一大堆冗长的测试，写了一个 demo 来娱乐自己，顺便作为 example：
#image("spring.gif")

= 结语

收获：
- 熟悉了自动求导
- 第一次用 AI 写文档（他目前还读不懂我的代码，或者说还读不太懂 Rust，所以写的测试有许多语法问题）
- Happiness!

#v(1%)
#line(length: 100%)
#v(1%)

#import "/book.typ": book-page
#show: book-page.with(title: "Diff road")
 

// =================== Content ===================

#set heading(numbering: none)

_The English version is mostly automatically converted from the Chinese version by Deepseek Chat model._

= The Arduous Way to Differentiation <tag:eng>
*TL;DR: I made #link("https://github.com/Da1sypetals/Raddy", "Raddy") the forward autodiff library, and #link("https://github.com/Da1sypetals/Symars", "Symars") the symbolic codegen library.* \

If you are interested, please give it a star and use it #emoji.heart


= The Origin of the Story:

I recently read some papers on physical simulation and wanted to try to reproduce them. I chose #link("https://graphics.pixar.com/library/StableElasticity/paper.pdf", "stable neo hookean flesh simulation") as a starting point, but the choice itself is not important. What is important is that many "modern" physical simulations are implicit simulations, which require solving an optimization problem using Newton's method.

This involves: taking derivatives of the constitutive model of energy (first-order gradient, second-order Hessian matrix). It also involves assembling a `large and sparse` complete Hessian from `small and dense` Hessian submatrices. This is a delicate task, and one can easily encounter `undebuggable` bugs.

#linebreak()

From the article *#link("https://www.tkim.graphics/DYNAMIC_DEFORMABLES/","Dynamic Deformables")*, it can be seen that deriving this formula takes a lot of effort (even understanding the notation in the paper takes a while). So I searched for more information, trying to find other solutions: I didn't want to spend a lot of time on meticulous debugging. The two solutions I found are:
- Symbolic differentiation, followed by code generation;
- Automatic differentiation.

#linebreak()

Among the materials I found, the former includes MATLAB or SymPy, and the latter includes deep learning libraries like PyTorch, and more suitable ones like #link("https://github.com/patr-schm/TinyAD", "TinyAD").


#text(size: 13pt)[Why more suitable? Because deep learning libraries differentiate at the tensor level, but here I need to differentiate at the scalar level, which is a different granularity. Deep learning libraries might result in completely unplayable frame rates.]

#linebreak()

But a fatal problem arises: the above tools are all in the C++ toolchain, and I don't know C++ (or, I know a little C++, but I don't know CMake, so I can't use libraries. I once spent three days trying to use Eigen in a project and failed, proving my incompetence). I had to switch to a language I am more familiar with: Rust. This is the beginning of all evil...

= A Path That Seems Simple

Currently, Rust does not have an automatic differentiation library that can compute second-order Hessians (at least I didn't find one on crates.io).
SymPy currently cannot generate Rust code (it can, but there are bugs).
Considering the difficulty of implementation, I chose the latter first: generating Rust code from SymPy expressions. Thus, #link("https://github.com/Da1sypetals/Symars", "Symars") was born.
#linebreak()

The data structure provided by SymPy for accessing symbolic expressions is in the form of a tree, where node types are operator types (`Add`, `Mul`, `Div`, `Sin`, etc.) or constants/symbols, and the children of the nodes are operands. The idea of implementing code generation is to traverse the tree depth-first, get the expressions of the children, and then get the expression of the current node based on the node type. The boundary condition is when the current node is a constant or a symbol.
#linebreak()

After implementation, I used the generated derivatives to write a simple implicit spring-mass system; but I still spent a lot of time debugging index errors when assembling the Hessian.

= Trying the Untrodden Path Again

To solve the above problem, I decided to try the path I had abandoned before: automatic differentiation. The plan was to use TinyAD in Rust.

== Two Ways to Walk the Same Path

At first, I thought of two methods: since I don't know C++, it might be more realistic to make a set of FFI than to understand the entire TinyAD codebase.
#linebreak()

But I found that after cloning the project, I couldn't even pull dependencies or compile it (what a cyber cripple).
#linebreak()

Then I re-examined the TinyAD codebase and found that the core logic is about ~1000 lines of code, which seems not impossible to replicate without running the project. So I went ahead and created #link("https://github.com/Da1sypetals/raddy", "Raddy"):

== The Correct Way to Walk

Having found the correct way to walk, I started coding. Some implementation details:
- Each scalar value on the differentiation chain carries a gradient and Hessian relative to the variable, so the memory overhead is visibly severe; a way to remind users is not to implement the `Copy` trait, and to `explicit clone` when a copy is needed.
- There are many operator traits that need to be implemented between `(&)Type` and `(&)Type`, with `2 * 2 = 4` combinations, meaning the same code has to be written 4 times. So I considered introducing some metaprogramming methods:
  - Use macros;
  - Use Python scripts for code generation.

#linebreak()
Considering that macros would make (part of) `rust-analyzer` stop working, but I can't live without LSP, I chose the latter. The specific code is in the `meta/` directory, and it's really nothing technical, just string concatenation.

#linebreak()
- Testing: How do I verify that the derivatives I computed are correct? The first idea was to use the `symars` I wrote earlier, generate symbolic `grad` and `hessian` code for each test expression, and then cross-validate with the differentiation results, making sure these test expressions cover all implemented methods as much as possible.
  - `symars` actually performed quite well, stable and without bugs.

== The Sparse Path

Dense matrices represent adjacent values in a contiguous memory space; sparse matrices with tens of thousands of sides (hundreds of millions of total elements `numel`) do not allow this. So I separately implemented the Hessian assembly process for sparse matrices:

#linebreak()
- Define a problem, i.e., implement an `Objective<N>` trait, which requires:
  - Determine the problem size `N` (this is a compiler requirement that const generics must be compile-time constants)
  - Implement the computation logic
  - For example: the logic of a spring-mass system (essentially Hooke's law from high school, $E=1/2 k x^2$):
    ```rust
    impl Objective<4> for SpringEnergy {
        type EvalArgs = f64; // restlength

        fn eval(&self, variables: &advec<4, 4>, restlen: &Self::EvalArgs) -> Ad<4> {
            // extract node positions from problem input:
            let p1 = advec::<4, 2>::new(variables[0].clone(), variables[1].clone());
            let p2 = advec::<4, 2>::new(variables[2].clone(), variables[3].clone());

            let len = (p2 - p1).norm();
            let e = make::val(0.5 * self.k) * (len - make::val(*restlen)).powi(2);

            e
        }
    }
    ```

- Define which components in this sparse vector need to be inputs to this problem (provide their indices, `&[[usize; N]]`).
- AD automatically assembles `grad` and `hess` (sparse), involving index map issues;
- Finally, the user manually sums multiple `grad` and `hess`. This step no longer has index map issues, it's just simple matrix addition (triplet matrix is even simpler, just concatenate multiple triplet vectors).
#linebreak()

Before adding tests, there were 2.2k lines of code; after adding tests, the total code volume of the project expanded to 18k lines, proving once again that counting LOC is a rather useless thing.

#linebreak()
Finally, after a lot of lengthy tests, I wrote a demo to entertain myself, and also as an example:
#image("spring.gif")

= Conclusion

Gains:
- Familiarity with automatic differentiation
- First time using AI to write documentation (it currently can't read my code, or rather, it can't read Rust well, so the tests it wrote have many syntax issues)
- Happiness!