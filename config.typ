#import "tufted-lib/tufted.typ" as tufted

#let template = tufted.tufted-web.with(
  header-links: (
    "/": "Home",
    "/posts/": "知识",
    "/art/": "文化",
    "/english-post/": "en-Posts",
    "/documents/": "文档",
    "/about": "关于我",
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
