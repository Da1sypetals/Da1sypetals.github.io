#import "tufted-lib/tufted.typ" as tufted

#let template = tufted.tufted-web.with(
  header-links: (
    "/posts/": "知识",
    "/art/": "文化",
    "/english-post/": "English",
    "/documents/": "文档",
    "/": "About",
  ),

  website-title: "Da1sypetals",
  author: "Da1sypetals",
  description: "Da1sypetals 的个人博客",
  website-url: "https://blog.petals.top",
  lang: "zh",
  feed-dir: ("/posts/", "/english-post/"),

  header-elements: (
    [Da1sypetals],
  ),
  footer-elements: (
    "© 2026 Da1sypetals",
  ),
)
