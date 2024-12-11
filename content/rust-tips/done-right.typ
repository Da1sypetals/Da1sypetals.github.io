#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")
 
= Done Right



#let hline = align(center, line(length: 100%))

#show outline.entry: it => {
  if it.level == 1 {
    v(12pt, weak: true)
    strong(it)
  } else {
    let sz = 13pt - it.level * 0.5pt;
    let indent = "";
    let counter = 1;
    while counter < it.level {
      indent += $"    "$;
      counter += 1;
    }
    indent + text(size: sz)[#it]

   

  }
}

#outline()


#set heading(numbering: "1.")

= 运行时初始化全局`const`：
- 请使用`LazyCell<T>`.
  - `OnceCell<T>` 不是用在这里的。
- 如果存在并发，使用`LazyLock<T>`.
```rust
use std::cell::LazyCell;
fn main() {
  let lazy: LazyCell<i32> = LazyCell::new(|| {
      println!("initializing");
      2992
  });
  println!("ready");
  println!("{}", *lazy); // prints initialization message
  println!("{}", *lazy);
}
```
- 注：这里可以类比 `RefCell<T>` 和 `RwLock<T>`.

#v(2em) #hline #v(2em) 


= 错误处理
== 中心思想：
- 如果一个错误的发生意味着代码实现存在错误，或者未预料的非法行为，使用 panic；
- 如果一个错误的发生是意料之中的，或者只为了传递某种信息，使用 ?向上传播。

== 解释：
+ 实现存在错误
  - Internal unexcpected：一个文件只由这个程序维护，而在读取文件的时候遇到了*和写入不一致的格式*
+ Invariant that cannot be enforced by language：一个函数 g 被上级函数 f 调用，传入的参数应是正的浮点数（由 f 的逻辑保证），但是实际却传入了负数。
    - 例子：`sqrt`, `ln`（我认为正确的行为）
  - 待补充：...

+ 意料之中
  - 传递某种信息
    - 在编写解释器的时候，如果需要提前返回，就将 Return 作为 Error 的一个 variant，然后一路向上传播，直到传播到 call stack 的上一层，进行处理（获取到返回值）。

  - 意料之中的用户错误
    - 用户输入的配置项不符合格式：此时应该处理这种错误，然后用 std::process::exit优雅退出。
    - 动态大小的矩阵进行乘法，`(m,n)` 和 `(p,q)`相乘，`n != p`的情况，应返回 `IncompatibleSizeError` variant 并交给用户处理。


