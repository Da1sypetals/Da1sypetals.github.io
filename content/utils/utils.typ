#import "/book.typ": book-page
#show: book-page.with(title: "Sample Page")
 
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

= 加密音乐格式解密：

https://git.unlock-music.dev/um/web/releases/tag/v1.10.8

用法：
+ 下载legacy的压缩包，unzip
+ 双击`index.html`即可

= 代码仓库备份
从提供的HTML代码中提取出的链接如下：

+ https://bitbucket.org/ (using: https://bitbucket.org/da1sypetals)
+ https://chiselapp.com/
+ https://www.codebasehq.com/
+ https://codeberg.org/
+ https://gitgud.io/
+ https://about.gitlab.com/
+ https://framagit.org/
+ https://foss.heptapod.net/
+ https://ionicframework.com/appflow
+ https://notabug.org/
+ https://osdn.net/
+ https://pagure.io/
+ https://www.perforce.com/products/helix-teamhub
+ https://pijul.com/
+ https://plasticscm.com/
+ https://projectlocker.com/
+ https://rocketgit.com/
+ https://savannah.gnu.org/
+ https://savannah.nongnu.org/+