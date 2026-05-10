# Tufted Blog

基于 Typst 的个人博客。

## 前置

- [Typst](https://typst.app/open-source/#download)
- [uv](https://docs.astral.sh/uv/)

## 写作

新建文章：

```bash
uv run blog.py new <section> <标题文字>
```

`<section>` 必须已存在（`posts` / `art` / `english-post` / `documents`）。命令会在该分类下创建 `YYYY-MM-DD-<slug>/index.typ`，`date` 字段自动填今天。

文章的图片和 `index.typ` 放在同一个目录，引用时直接写文件名：

```typst
#figure(image("orchid.gif"))
```

文章头部的 `title` / `description` / `date` 是唯一事实源，分类首页、RSS、sitemap 都从它解析。

删除一篇文章：直接 `rm -rf` 掉它的目录。

## 预览

```bash
uv run blog.py preview
```

默认 8000 端口，自动打开浏览器。保存源文件（`.typ`、图片、`config.typ`、`tufted-lib/`、`assets/`）会自动增量构建并刷新浏览器。不存在的路径会返回 `404.html`。

其他参数：

```bash
uv run blog.py preview -p 3000      # 指定端口
uv run blog.py preview --no-open    # 不自动开浏览器
```

## 构建

```bash
uv run blog.py build          # 增量构建
uv run blog.py build --force  # 全量重建
uv run blog.py clean          # 清理 _site/
```

产物在 `_site/`。

## 部署到 GitHub Pages

1. 仓库 Settings → Pages → Build and deployment → Source 选 "GitHub Actions"。
2. 新建 `.github/workflows/deploy.yml`：

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: typst-community/setup-typst@v3
      - uses: astral-sh/setup-uv@v3
      - run: uv run blog.py build --force
      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

3. 推送到 `main`。Action 跑完后访问 `https://<user>.github.io/<repo>/`。

GitHub Pages 会自动用 `_site/404.html` 作为 404 回退。

## 自定义域名

在 `content/` 下加一个文件 `CNAME`（内容为你的域名），它会作为静态资源被复制到 `_site/`；再在域名 DNS 把记录指向 GitHub Pages。

同时把 `config.typ` 里 `website-url` 改成你的域名，影响生成的 RSS / sitemap / canonical URL。

## 站点配置

改 `config.typ`：站点标题、作者、导航（`header-links`）、RSS 订阅目录（`feed-dir`）、页脚等。导航的 key 是 URL 路径，value 是显示文字。
