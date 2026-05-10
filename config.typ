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
  website-url: "https://da1sypetals.github.io",
  lang: "zh",

  header-elements: (
    [Da1sypetals],
  ),
  footer-elements: (
    "© 2026 Da1sypetals",
  ),
)
