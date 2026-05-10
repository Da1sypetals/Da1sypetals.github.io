#import "/config.typ": template, tufted
#show: template.with(
  title: "我的萝卜头像",
  description: "胡萝卜头像素材",
  date: datetime(year: 2025, month: 10, day: 12),
)

= 我的萝卜头像

== 矢量图

#figure(image("carrot.svg"))

== 位图，hires

#figure(image("carrot_padded.png"))

== 位图，lowres

#figure(image("carrot_540.png"))
