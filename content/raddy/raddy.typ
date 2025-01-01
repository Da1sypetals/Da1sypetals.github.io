
#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")

_2024.12.29_

= #link("https://github.com/Da1sypetals/Raddy", "Raddy") Devlog
带着自己的理解，尝试用Rust写一遍#link("https://github.com/patr-schm/TinyAD", "TinyAD")，学习一下前向自动求导。

#text(size: 12pt)[- 我曾经在大一暑假的作业中被按着头学会了怎么写反向自动求导...]

= 理解

+ 泛型的N是指*求导自变量的维度数*。
+ 整个求导过程中含有自变量的向量只能被创建一次，只能求对于这个自变量的grad&hess，而且导数和函数值是被一起计算的。

= 实现
- 实现链式法则chain函数；
- 实现各种基本初等函数。
- 其中比较有考量的是API：
    - $N$自变量维度数，$L$是向量维度数（中间任何一个向量）
    - 常量创建的时候N和L可以不同
    - 自变量创建时$N=L$
- 还实现了稀疏问题的求导：
    - 定义问题：
        - $N$: 问题自变量维度数（例如弹簧能量是$2 D, D$是空间未读数）
        - 一个用于计算目标函数的定义（用实现trait+泛型的方式来实现）
    - 返回的矩阵是稀疏COO（Triplet）形式

= Note

+ 你可以任意reshape，切分，clone，等操作矩阵，只要保证整个求导过程中含有自变量的向量只被创建一次。

