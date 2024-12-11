#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")
 
= `cargo` 

#set heading(numbering: "1.")

= VSCode 如何测试的时候开启 stdout
- 默认是不立刻输出的，因为并行测试：
- 解决方法：修改 `settings.json`:
  ```json
  "rust-analyzer.runnables.extraTestBinaryArgs": [
      "--nocapture"
  ],
  ```
= `cargo publish` 网络连不上：
  - `cargo publish --registry crates-io`
  - 把代理关了即可