#import "/book.typ": book-page
#show: book-page.with(title: "This is Da1sypetals!")

= ArchLinux 小寄巧

#let mini(x) = text(size: 13pt)[#x]
#set heading(numbering: "1.")

#mini[我不是玩系统高手，也没啥兴趣玩系统QAQ，因为组里的开发机器是ArchLinux所以来学学]

= 我没有`sudo`权限，但是我需要装一个二进制（一个命令等）

- https://archlinux.org/packages 搜索自己需要的包
- 然后在右边侧栏找到 Download From Mirror，下载一个含有binary的包
- `zstd -d <package.tar.zst>`
- `tar -xvf <package.tar>`
- 往里面找到自己想要的binary，`cp` 到一个在`PATH`的目录
  - 例如：`~/bin`