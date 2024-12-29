
#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")

_2024.12.29_

= #link("https://github.com/Da1sypetals/Raddy", "Raddy") Devlog
带着自己的理解，尝试用Rust写一遍#link("https://github.com/patr-schm/TinyAD", "TinyAD")，学习一下前向自动求导。

#text(size: 12pt)[- 我曾经在大一暑假的作业中被按着头学会了怎么写反向自动求导...]

= 理解

+ 泛型的N是指*求导自变量的维度数*。
+ 整个求导过程中含有自变量的向量只能被创建一次，只能求对于这个自变量的grad&hess，而且导数和函数值是被一起计算的。

= Note

+ 你可以任意reshape，切分，clone，等操作矩阵，只要保证整个求导过程中含有自变量的向量只被创建一次。

= TODO
+ 如何*正确地*实现`nalgebra`的一个`Scalar`？
    - 编译器要求我实现`ComplexField` trait，但是我点进去之后发现里面的方法不太可能是我能实现得完的
    - 目前的权宜之计是把常用的且需要`ComplexField` trait的矩阵操作自己写一遍。
+ 如何设置一个选项让用户把hessian分配在堆上？
+ Sparse
