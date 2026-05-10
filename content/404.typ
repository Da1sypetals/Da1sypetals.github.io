#import "/config.typ": template, tufted
#show: template.with(
  title: "404 - 页面未找到",
  description: "页面未找到",
)

#html.div(
  style: "text-align: center; padding: 4rem 1rem;",
  {
    html.div(
      style: "font-size: 6rem; font-weight: bold; line-height: 1; margin-bottom: 1rem; opacity: 0.7;",
      "404",
    )
    html.div(
      style: "font-size: 1.5rem; margin: 2rem 0; letter-spacing: 0.1em;",
      "行到水穷处，坐看云起时",
    )
    html.div(
      style: "margin-top: 2.5rem;",
      html.a(
        href: "/",
        style: "display: inline-block; padding: 0.6rem 1.5rem; border: 1px solid currentColor; border-radius: 4px; text-decoration: none;",
        "返回首页",
      ),
    )
  },
)
