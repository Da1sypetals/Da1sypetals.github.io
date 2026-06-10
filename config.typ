#import "tufted-lib/tufted.typ" as tufted

#let template = tufted.tufted-web.with(
  header-links: (
    "/posts/": "知识",
    "/art/": "文化",
    "/documents/": "文档",
    "/llm-chats/": "精选LLM对话",
    "/": "About",
  ),

  website-title: "Da1sypetals",
  author: "Da1sypetals",
  website-url: "https://blog.petals.top",
  lang: "zh",

  header-elements: (
    [Da1sypetals],
  ),
  footer-elements: (
    "© 2026 Da1sypetals",
  ),
)
