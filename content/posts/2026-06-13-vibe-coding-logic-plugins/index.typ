#import "/config.typ": template, tufted
#show: template.with(
  title: "搭建一个可以让Agent编写Logic Pro插件的框架",
  date: datetime(year: 2026, month: 6, day: 13),
)

== 框架

框架层自然是选择最成熟的JUCE；但是实际上我没有能力审查C++的代码，而DSP的代码很可能是需要审查的，于是我就用让C++作为

== TODO
