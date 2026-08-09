#import "/config.typ": template, tufted
#show: template.with(
  title: "Brew 换源",
  date: datetime(year: 2025, month: 10, day: 23),
)

原文：

- #link("https://mirrors.ustc.edu.cn/help/brew.git.html")
- #link("https://mirrors.ustc.edu.cn/help/homebrew-bottles.html")
- #link("https://mirrors.ustc.edu.cn/help/homebrew-core.git.html")
- #link("https://mirrors.ustc.edu.cn/help/homebrew-cask.git.html")

== 一、设置环境变量（永久生效，针对 fish）

在 fish 中，永久设置环境变量应使用 `set -Ux`（全局、导出、持久化）：

```sh
# Homebrew 主程序仓库
set -Ux HOMEBREW_BREW_GIT_REMOTE https://mirrors.ustc.edu.cn/brew.git

# Homebrew 核心公式仓库
set -Ux HOMEBREW_CORE_GIT_REMOTE https://mirrors.ustc.edu.cn/homebrew-core.git

# 预编译二进制包（bottles）域名
set -Ux HOMEBREW_BOTTLE_DOMAIN https://mirrors.ustc.edu.cn/homebrew-bottles

# 元数据 API 域名（Brew 4.0+ 必需）
set -Ux HOMEBREW_API_DOMAIN https://mirrors.ustc.edu.cn/homebrew-bottles/api
```

== 二、配置 Homebrew Cask 使用镜像

```sh
brew tap --custom-remote homebrew/cask https://mirrors.ustc.edu.cn/homebrew-cask.git
```

> 注意：如果你以后想恢复官方源，可运行：
> ```
> brew tap --custom-remote homebrew/cask https://github.com/Homebrew/homebrew-cask
> ```

== 三、验证设置是否生效

检查环境变量：
```sh
echo $HOMEBREW_BREW_GIT_REMOTE
echo $HOMEBREW_CORE_GIT_REMOTE
echo $HOMEBREW_BOTTLE_DOMAIN
echo $HOMEBREW_API_DOMAIN
```

更新 Homebrew：
```sh
brew update
```

如果下载速度很快（且无 GitHub 超时），说明 bottles 已走镜像。
