
#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")

_2024.9.6_

#heading(numbering: none)[Try to implement IPC]
最近尝试入门Rust，就想找点代码写一写。

大部分人写的第一个应用应该都是某种后端服务（把前端发来的http请求，转化为对数据库的CRUD之类的操作，然后返回给前端）。

但是我并没有学过后端服务怎么写（最近想学，如果有比较好的零基础入门资料可以推荐一下），然后就只好捡起最近手边研究的这两篇论文拿来复现一下：

+ #link("https://ipc-sim.github.io/C-IPC", "IPC")
+ #link("https://ipc-sim.github.io/C-IPC/", "C-IPC")  
+ #link("https://arxiv.org/abs/2201.10022", "ABD")


#text(size: 14pt)[注：本文仅复现/讨论IPC族算法，不关心&不讨论任何性能优化/该算法效率是否高/为什么不用xx算法的问题。]

项目地址：#link("https://github.com/Da1sypetals/ip-sim/", "Github")



= Implicit euler
物理模拟其实是一个数值积分过程。

显式积分会爆炸，但是隐式积分又存在“鸡生蛋蛋生鸡”（计算下一秒的位置，需要用到下一秒的速度）的问题，无法显式求解，需要求解一个（可能非凸的）优化问题。

有什么可以是隐式积分？Mass-spring system就可以是隐式积分。但是其实我至今都没写过一个Optimization-based的隐式积分，所以先尝试搓一个mass-spring system。

== What is it?
Implicit euler 对于场景在t时间的dof（自由度，degree of freedom），建立一个IP(incremental potential），然后对其进行最小化($x(t+Delta t)=arg min_x E_"IP"(x(t))$得到$t+Delta t$的位置。

deep learning采取梯度下降法（及其变种），但是graphics里经过大家的验证，梯度下降的性能疑似呃呃。所以我们采取牛顿法。

== Implement
+ 牛顿法比较快，但是这带来了一个问题：需要组装hessian矩阵。

好在incremental potential的每一个组分大多是 ($k n$个dof）的函数，其中n是维度数（我实现的是2），k是一个最多几十的数字。所以对每一个组成大IP的小IP，其Hessian的项数也就数十到数百，可以用稀疏存储的方式，然后组装成整体的hessian。

参考#link("https://zhuanlan.zhihu.com/p/444105016", "教程")，实现了一个顶点挂在墙上的springs。

+ *选包。*
    - 选取macroquad做GUI；
    - 选取nalgebra_glm做小型线性代数；
    - 一开始打算用nalgebra做大型线性代数，但是找了半天好像稀疏矩阵功能不太完善；所以换了faer；
    - 一开始用了argmin做optimization。

== 在contact ip之前的小插曲
rust要编译很久，所以配置几何体的形状显然不应该hardcode。

一开始我造了一种奇怪的文件格式，按照我自己的逻辑写config：



然后让aigc帮我写parser。

后来才发现，用json, toml这些现成的配置格式就有现成的parser，但是已经懒得改了。

= Contact IP
ContactIP简单来说就是：

+ 要求 *来自两个不同body的，靠的足够近（threshold *$hat(d)$*）的 *一对点-边（point-edge）对(aka primitive pair)，按照他们的距离赋予他们能量。

但是为了防止穿模，还有一些要求：

+ 优化课上教过，(damped) newton是一个iter一个iter逼近极值的，每个iter都是一次line search，为了防止穿模，每一个iter的line search的整个中间的过程都必须保证primitive pair不穿模，最终造成所有物体都不穿模的结果。

== procedure
在newton step的每一个line search中，

1. 遍历所有的primitive pair（或者采取某种加速结构，但是我没有实现），找出距离小于threshold的primitive pair;
2. 计算contact IP对一个primitive pair有关的dof的能量值，grad，hessian，并且求解$d=-A^(-1)g$的方程得到search direction；
3. 进行一个名叫ccd的操作，保证这个line search不穿模（设定最大step length）
4. 使用armijo condition进行line search

repeat until 足够接近极小值，视为优化完成。

== implement
+ 每一个步骤都伴随着漫长的debug...
+ grad & hess
    - 2d情形下，每个primitive pair的dof是（一个点2dof）\*（3个点）=6dof；
    - E对dof的grad尚且可以手算（6-dim vector）。但hessian是一个6x6的矩阵；且论文里使用的符号混乱不堪，一会是dyadic product一会变成 kronecker product且不在文章中进行标注：手算已阵亡。
        - 于是我们直接把sympy搬上来做符号计算，然后用codegen生成计算代码。
            \* 可以在`symbolic/`文件夹里找到求导的代码。
        - sympy居然有rust codegen，但是功能是残废的，结果经常不符合rust语法，需要做一些字符替换，且只能生成单表达式，不能生成vector/matrix
        - Note: 后来我自己做了一个生成SymPy->rust的代码生成器，
            - #link("https://github.com/Da1sypetals/Symars", "Symars: Generate Rust code from SymPy expressions")
+ 记得点到线段距离要分类讨论。
+ ccd（accd）需要被集成到优化过程中，所以argmin不好使了，把argmin丢了，手写了 damped newton solver with ACCD and armijo condition.



经过数日的coding and debug，这个demo成功的被端出来：
- 动图：#link("https://github.com/Da1sypetals/ip-sim/blob/master/demo/springs.gif","github上的第一张图")
- 其中约束是弹簧

= ABD
一句话解释ABD：

+ ABD是一种用12-dof代替传统6-dof(translate+rotate)刚体，并对偏离rotation matrix太远的transformation matrix进行强烈惩罚的一种（近）刚体模拟算法。

在2d情形下，一个affine body (ab)是6个dof：$x=A x_0+b$，其形状为A(2,2)，b(2,)，组装成一个dof向量：$q=["flatten"(A), b^T]$

我们知道旋转矩阵R满足$R^T R=I$，ABD采取orthogonal potential能量$kappa v dot"frobnorm"(A^T A-I)$对A进行惩罚以让A近似为旋转矩阵。

== Implement
+ 是能量就要求两次导数。我们同样把sympy搬上来求导。
    - 该项目有数千行代码都是这些数值计算的代码，不要去看他们。
+ affine body同样也要实现contact。
    - 但是区别于一个顶点一个dof的mass-spring system，ab的顶点位置p是dof的函数，contact IP又是顶点位置p的函数。
    - 一个primitive pair有两个body参与，其中一个primitive pair贡献的是一条边（具有两个点p1,p2）。
    - 于是需要对两个q求导。计算图如下：#image("../../assets/ipc/diff.jpg")

        


又经过漫长的debug和调参（主要是$kappa$），模拟终于跑起来了。
- 动图：#link("https://github.com/Da1sypetals/ip-sim/raw/master/demo/affine.gif", "第二张图")

= 最后
写完的代码是名副其实的屎山。

即使我在开始code之前想了很久如何统一接口，最后的接口设计既不OOP也不符合rust风格，且充满了标准不一致的传参。

我不禁开始思考到底是我能力太低，还是代码的复杂性真的不是靠设计可以解决的问题。

比较开心的地方：

+ cargo太好用了，加一个包只要三秒钟，和 `*make` 高下立判；
+ 整个过程中没有遇到任何内存问题（毕竟我不会写也没必要写`unsafe`），使得大部分精力都花在逻辑上。

