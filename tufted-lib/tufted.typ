#import "math.typ": template-math
#import "refs.typ": template-refs
#import "notes.typ": template-notes
#import "figures.typ": template-figures
#import "layout.typ": full-width, margin-note
#import "links.typ": template-links
#import "metadata.typ": metadata

/// Tufted 博客模板的主包装函数。
///
/// 用于生成完整的 HTML 页面结构，包含 SEO 元数据、CSS/JS 资源加载以及页眉页脚布局。
#let tufted-web(
  header-links: (:),

  // Meta data
  title: "",
  author: none,
  lang: "zh",
  date: none,
  website-title: "",
  website-url: none,

  // For SEO
  image-path: none,

  // Custom header and footer
  header-elements: (),
  footer-elements: (),

  // Custom CSS and JS Scripts
  css: ("/assets/custom.css",),
  js-scripts: (),

  content,
) = {
  // Apply styling
  show: template-math
  show: template-refs
  show: template-notes
  show: template-figures
  show: template-links

  set text(lang: lang)

  html.html(
    lang: lang,
    {
      // Head
      html.head({
        // All metadata
        metadata(
          title: title,
          author: author,
          lang: lang,
          date: date,
          website-title: website-title,
          website-url: website-url,
          image-path: image-path,
        )

        // load CSS
        let base-css = (
          "https://cdnjs.cloudflare.com/ajax/libs/tufte-css/1.8.0/tufte.min.css",
          "/assets/tufted.css",
          "/assets/theme.css",
        )
        for (css-link) in (base-css + css).dedup() {
          html.link(rel: "stylesheet", href: css-link)
        }

        // load JS scripts
        let base-js = (
          "/assets/code-blocks.js",
          "/assets/format-headings.js",
          "/assets/theme-toggle.js",
          "/assets/marginnote-toggle.js",
        )
        for (js-src) in (base-js + js-scripts).dedup() {
          html.script(src: js-src)
        }
      })

      // Body
      html.body({
        // Custom header elements (site header, not navigation)
        html.header(
          class: "site-header",
          {
            for (i, element) in header-elements.enumerate() {
              element
              if i < header-elements.len() - 1 {
                html.br()
              }
            }
          },
        )

        // Add website navigation
        html.header(
          class: "site-header",
          if header-links != none and header-links.len() > 0 {
            html.nav(
              class: "site-nav",
              for (href, title) in header-links {
                html.a(href: href, title)
              },
            )
          }
        )

        // Main content: 自动渲染 title + 发布日期，然后是正文
        // 仅文章页（有 date 字段）加 class="post"，触发自动编号样式
        let article-attrs = if date != none { (class: "post",) } else { (:) }
        html.elem(
          "article",
          attrs: article-attrs,
          html.section({
            if title != "" {
              [= #title]
              if date != none {
                let date-text = if type(date) == datetime {
                  date.display("[year]-[month]-[day]")
                } else {
                  str(date)
                }
                html.div(class: "post-date", date-text)
              }
            }
            content
          }),
        )

        // Custom footer elements
        html.footer({
          for (i, element) in footer-elements.enumerate() {
            element
            if i < footer-elements.len() - 1 {
              html.br()
            }
          }
        })
      })
    },
  )
}
