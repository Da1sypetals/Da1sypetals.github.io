#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = ["watchdog"]
# ///

"""
Tufted Blog 构建脚本

将 content/ 下的 Typst (.typ) 源文件编译为 HTML（部分文件名含 "pdf" 的同时编译为 PDF），
并将静态资源复制到 _site/ 输出目录。

特性
----
- 增量编译：根据文件修改时间只重新编译变更的页面
- 自动生成分类首页：扫描 content/<section>/ 下所有文章子目录的元数据，
  在内存中拼出该分类的首页 typst 源码并直接编译到 _site/<section>/index.html，
  不在文件系统中留下中间产物
- 自动生成 sitemap.xml / robots.txt / RSS feed
- 预览服务器集成 watchdog：保存源文件后自动增量重建并触发 livereload 刷新

用法
----
    uv run blog.py build                  # 完整构建（HTML + PDF + 资源 + 分类页 + sitemap/RSS）
    uv run blog.py build --force          # 强制全量重建（先 clean 再 build）
    uv run blog.py html                   # 仅编译 HTML
    uv run blog.py pdf                    # 仅编译 PDF
    uv run blog.py assets                 # 仅复制静态资源
    uv run blog.py clean                  # 清理 _site/

    uv run blog.py preview                # 启动本地预览服务器 + 文件监视（默认端口 8000）
    uv run blog.py preview -p 3000        # 自定义端口
    uv run blog.py preview --no-open      # 不自动打开浏览器

    uv run blog.py new <section> <title words...>
        # 在 content/<section>/ 下新建一篇文章。section 必须已存在（不会创建新分类）。
        # 文章目录名为 YYYY-MM-DD-<slug>，date 自动填今天。
        # 示例：uv run blog.py new art this is my title

也可以直接使用 Python 运行（脚本会通过 PEP 723 头自动安装依赖；用 python 运行时
需自行确保 watchdog 已安装）：
    python blog.py build
    python blog.py preview -p 3000
"""

import argparse
import http.server
import io
import os
import queue
import re
import shutil
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from typing import Literal

# ============================================================================
# 配置
# ============================================================================

CONTENT_DIR = Path("content")  # 源文件目录
SITE_DIR = Path("_site")  # 输出目录
ASSETS_DIR = Path("assets")  # 静态资源目录
CONFIG_FILE = Path("config.typ")  # 全局配置文件


@dataclass
class BuildStats:
    """构建统计信息"""

    success: int = 0
    skipped: int = 0
    failed: int = 0

    def format_summary(self) -> str:
        """格式化统计摘要"""
        parts = []
        if self.success > 0:
            parts.append(f"编译: {self.success}")
        if self.skipped > 0:
            parts.append(f"跳过: {self.skipped}")
        if self.failed > 0:
            parts.append(f"失败: {self.failed}")
        return ", ".join(parts) if parts else "无文件需要处理"

    @property
    def has_failures(self) -> bool:
        """是否存在失败"""
        return self.failed > 0


class HTMLMetadataParser(HTMLParser):
    """
    从 HTML 文件中提取元数据的解析器。

    解析以下元数据：
    - lang: 从 <html lang="..."> 属性获取
    - title: 从 <title> 标签获取
    - link: 从 <link rel="canonical" href="..."> 获取
    - date: 从 <meta name="date" content="..."> 获取
    - nav_links: 从 <nav class="site-nav"><a href="..">显示名</a>...</nav> 获取
      列表元素形如 (href, display_name)
    """

    def __init__(self):
        super().__init__()
        self.metadata = {"title": "", "nav_links": []}
        self._in_title = False
        self._in_site_nav = False
        self._current_nav_href: str | None = None
        self._current_nav_text = ""

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]):
        attrs_dict = {k: v for k, v in attrs if v}

        match tag:
            case "html":
                self.metadata["lang"] = attrs_dict.get("lang", "")
            case "title":
                self._in_title = True
            case "meta":
                if attrs_dict.get("name") == "date":
                    self.metadata["date"] = attrs_dict.get("content", "")
            case "link":
                if attrs_dict.get("rel") == "canonical":
                    self.metadata["link"] = attrs_dict.get("href", "")
            case "nav":
                if "site-nav" in attrs_dict.get("class", ""):
                    self._in_site_nav = True
            case "a":
                if self._in_site_nav:
                    self._current_nav_href = attrs_dict.get("href", "")
                    self._current_nav_text = ""

    def handle_endtag(self, tag: str):
        if tag == "title":
            self._in_title = False
        elif tag == "a" and self._in_site_nav and self._current_nav_href is not None:
            self.metadata["nav_links"].append(
                (self._current_nav_href, self._current_nav_text)
            )
            self._current_nav_href = None
        elif tag == "nav" and self._in_site_nav:
            self._in_site_nav = False

    def handle_data(self, data: str):
        if self._in_title:
            self.metadata["title"] += data
        elif self._in_site_nav and self._current_nav_href is not None:
            self._current_nav_text += data


# ============================================================================
# 增量编译辅助函数
# ============================================================================


def get_file_mtime(path: Path) -> float:
    """
    获取文件的修改时间戳。

    参数:
        path: 文件路径

    返回:
        float: 修改时间戳，文件不存在返回 0
    """
    try:
        return path.stat().st_mtime
    except (OSError, FileNotFoundError):
        return 0.0


def is_dep_file(path: Path) -> bool:
    """
    判断一个文件是否被追踪为依赖）。

    content/ 下的普通页面文件不被视为模板文件，因为它们是独立的页面，
    不应该相互依赖。

    参数:
        path: 文件路径

    返回:
        bool: 是否是依赖文件
    """
    try:
        resolved_path = path.resolve()
        project_root = Path(__file__).parent.resolve()
        content_dir = (project_root / CONTENT_DIR).resolve()

        # config.typ 是依赖文件
        if resolved_path == (project_root / CONFIG_FILE).resolve():
            return True

        # 检查是否在 content/ 目录下
        try:
            relative_to_content = resolved_path.relative_to(content_dir)
            # content/_* 目录下的文件视为依赖文件
            parts = relative_to_content.parts
            if len(parts) > 0 and parts[0].startswith("_"):
                return True
            # content/ 下的其他文件不是依赖文件
            return False
        except ValueError:
            # 不在 content/ 目录下，视为依赖文件（如 config.typ）
            return True

    except Exception:
        return True


def find_typ_dependencies(typ_file: Path) -> set[Path]:
    """
    解析 .typ 文件中的依赖（通过 #import 和 #include 导入的文件）。

    只追踪 .typ 文件的依赖，忽略 content/ 下的普通页面文件。
    其他资源文件（如 .md, .bib, 图片等）通过 copy_content_assets 处理。

    参数:
        typ_file: .typ 文件路径

    返回:
        set[Path]: 依赖的 .typ 文件路径集合
    """
    dependencies: set[Path] = set()

    try:
        content = typ_file.read_text(encoding="utf-8")
    except Exception:
        return dependencies

    # 获取文件所在目录，用于解析相对路径
    base_dir = typ_file.parent

    patterns = [
        r'#import\s+"([^"]+)"',
        r"#import\s+'([^']+)'",
        r'#include\s+"([^"]+)"',
        r"#include\s+'([^']+)'",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, content):
            dep_path_str = match.group(1)

            # 跳过包导入（如 @preview/xxx）
            if dep_path_str.startswith("@"):
                continue

            # 解析相对路径
            if dep_path_str.startswith("/"):
                # 相对于项目根目录的路径
                dep_path = Path(dep_path_str.lstrip("/"))
            else:
                # 相对于当前文件的路径
                dep_path = base_dir / dep_path_str

            # 规范化路径，只追踪 .typ 文件
            try:
                dep_path = dep_path.resolve()
                if dep_path.exists() and dep_path.suffix == ".typ" and is_dep_file(dep_path):
                    dependencies.add(dep_path)
            except Exception:
                pass

    return dependencies


def get_all_dependencies(typ_file: Path, visited: set[Path] | None = None) -> set[Path]:
    """
    递归获取 .typ 文件的所有依赖（包括传递依赖）。

    参数:
        typ_file: .typ 文件路径
        visited: 已访问的文件集合（用于避免循环依赖）

    返回:
        set[Path]: 所有依赖文件路径集合
    """
    if visited is None:
        visited = set()

    # 避免循环依赖
    abs_path = typ_file.resolve()
    if abs_path in visited:
        return set()
    visited.add(abs_path)

    all_deps: set[Path] = set()
    direct_deps = find_typ_dependencies(typ_file)

    for dep in direct_deps:
        all_deps.add(dep)
        # 只对 .typ 文件递归查找依赖
        if dep.suffix == ".typ":
            all_deps.update(get_all_dependencies(dep, visited))

    return all_deps


def needs_rebuild(source: Path, target: Path, extra_deps: list[Path] | None = None) -> bool:
    """
    判断是否需要重新构建。

    当以下任一条件满足时需要重建：
    1. 目标文件不存在
    2. 源文件比目标文件新
    3. 任何额外依赖文件比目标文件新
    4. 源文件的任何导入依赖比目标文件新
    5. 源文件同目录下的任何非 .typ 文件比目标文件新（如 .md, .bib, 图片等）

    参数:
        source: 源文件路径
        target: 目标文件路径
        extra_deps: 额外的依赖文件列表（如 config.typ）

    返回:
        bool: 是否需要重新构建
    """
    # 目标不存在，需要构建
    if not target.exists():
        return True

    target_mtime = get_file_mtime(target)

    # 源文件更新了
    if get_file_mtime(source) > target_mtime:
        return True

    # 检查额外依赖
    if extra_deps:
        for dep in extra_deps:
            if dep.exists() and get_file_mtime(dep) > target_mtime:
                return True

    # 检查源文件的导入依赖
    for dep in get_all_dependencies(source):
        if get_file_mtime(dep) > target_mtime:
            return True

    # 检查源文件同目录下的非 .typ 资源文件（如 .md, .bib, 图片等）
    # 只检查同一目录，不递归子目录，避免过度重编译
    source_dir = source.parent
    for item in source_dir.iterdir():
        if item.is_file() and item.suffix != ".typ":
            if get_file_mtime(item) > target_mtime:
                return True

    return False


def find_common_dependencies() -> list[Path]:
    """
    查找所有文件的公共依赖（如 config.typ）。

    返回:
        list[Path]: 公共依赖文件路径列表
    """
    common_deps = []

    # config.typ 是全局配置，修改后所有页面都需要重建
    if CONFIG_FILE.exists():
        common_deps.append(CONFIG_FILE)

    # 可以在这里添加其他公共依赖
    # 例如：查找 content/_* 目录下的模板文件
    if CONTENT_DIR.exists():
        for item in CONTENT_DIR.iterdir():
            if item.is_dir() and item.name.startswith("_"):
                for typ_file in item.rglob("*.typ"):
                    common_deps.append(typ_file)

    return common_deps


# ============================================================================
# 辅助函数
# ============================================================================


def find_typ_files() -> list[Path]:
    """
    查找 content/ 目录下所有 .typ 文件，排除路径中包含以下划线开头的目录的文件。

    返回:
        list[Path]: .typ 文件路径列表
    """
    typ_files = []
    for typ_file in CONTENT_DIR.rglob("*.typ"):
        # 检查路径中是否有以下划线开头的目录
        parts = typ_file.relative_to(CONTENT_DIR).parts
        if not any(part.startswith("_") for part in parts):
            typ_files.append(typ_file)
    return typ_files


def get_file_output_path(typ_file: Path, type: Literal["pdf", "html"]) -> Path:
    """
    获取 .typ 文件的输出路径。

    参数:
        typ_file: .typ 文件路径 (相对于 content/)

    返回:
        Path: 文件输出路径 (在 _site/ 目录下)
    """
    relative_path = typ_file.relative_to(CONTENT_DIR)
    return SITE_DIR / relative_path.with_suffix(f".{type}")


def run_typst_command(args: list[str]) -> bool:
    """
    运行 typst 命令。

    参数:
        args: typst 命令参数列表

    返回:
        bool: 命令是否成功执行
    """
    try:
        result = subprocess.run(["typst"] + args, capture_output=True, text=True, encoding="utf-8")
        if result.returncode != 0:
            print(f"  ❌ Typst 错误: {result.stderr.strip()}")
            return False
        return True
    except FileNotFoundError:
        print("  ❌ 错误: 未找到 typst 命令。请确保已安装 Typst 并添加到 PATH 环境变量中。")
        print("  📝 安装说明: https://typst.app/open-source/#download")
        return False
    except Exception as e:
        print(f"  ❌ 执行 typst 命令时出错: {e}")
        return False


# ============================================================================
# 构建命令
# ============================================================================


def _compile_files(
    files: list[Path],
    force: bool,
    common_deps: list[Path],
    get_output_path_func,
    build_args_func,
) -> BuildStats:
    """
    通用文件编译函数，减少重复代码。

    参数:
        files: 要编译的文件列表
        force: 是否强制重建
        common_deps: 公共依赖列表
        get_output_path_func: 获取输出路径的函数
        build_args_func: 构建编译参数的函数

    返回:
        BuildStats: 构建统计信息
    """
    stats = BuildStats()

    for typ_file in files:
        output_path = get_output_path_func(typ_file)

        # 增量编译检查
        if not force and not needs_rebuild(typ_file, output_path, common_deps):
            stats.skipped += 1
            continue

        output_path.parent.mkdir(parents=True, exist_ok=True)

        # 构建编译参数
        args = build_args_func(typ_file, output_path)

        if run_typst_command(args):
            stats.success += 1
        else:
            print(f"  ❌ {typ_file} 编译失败")
            stats.failed += 1

    return stats


def build_html(force: bool = False) -> bool:
    """
    编译所有 .typ 文件为 HTML（文件名中包含 PDF 的除外）。

    参数:
        force: 是否强制重建所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    typ_files = find_typ_files()

    # 排除标记为 PDF 的文件
    html_files = [f for f in typ_files if "pdf" not in f.stem.lower()]

    if not html_files:
        print("  ⚠️ 未找到任何 HTML 文件。")
        return True

    print("正在构建 HTML 文件...")

    # 获取公共依赖
    common_deps = find_common_dependencies()

    def build_html_args(typ_file: Path, output_path: Path) -> list[str]:
        """构建 HTML 编译参数"""
        try:
            rel_path = typ_file.relative_to(CONTENT_DIR)

            if rel_path.name == "index.typ":
                # index.typ uses the parent directory name as the path
                # content/Blog/index.typ -> "Blog"
                # content/index.typ -> "" (Homepage)
                page_path = rel_path.parent.as_posix()
                if page_path == ".":
                    page_path = ""
            else:
                # Common files use the filename as the path
                # content/about.typ -> "about"
                page_path = rel_path.with_suffix("").as_posix()
        except ValueError:
            page_path = ""

        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            "--features",
            "html",
            "--format",
            "html",
            "--input",
            f"page-path={page_path}",
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        html_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "html"),
        build_html_args,
    )

    print(f"✅ HTML 构建完成。{stats.format_summary()}")
    return not stats.has_failures


def build_pdf(force: bool = False) -> bool:
    """
    编译文件名包含 "PDF" 的 .typ 文件为 PDF。

    参数:
        force: 是否强制重建所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    typ_files = find_typ_files()
    pdf_files = [f for f in typ_files if "pdf" in f.stem.lower()]

    if not pdf_files:
        return True

    print("正在构建 PDF 文件...")

    # 获取公共依赖
    common_deps = find_common_dependencies()

    def build_pdf_args(typ_file: Path, output_path: Path) -> list[str]:
        """构建 PDF 编译参数"""
        return [
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            str(typ_file),
            str(output_path),
        ]

    stats = _compile_files(
        pdf_files,
        force,
        common_deps,
        lambda typ_file: get_file_output_path(typ_file, "pdf"),
        build_pdf_args,
    )

    print(f"✅ PDF 构建完成。{stats.format_summary()}")
    return not stats.has_failures


def copy_assets() -> bool:
    """
    复制静态资源到输出目录。
    """
    if not ASSETS_DIR.exists():
        print(f"  ⚠ 静态资源目录 {ASSETS_DIR} 不存在。")
        return True

    SITE_DIR.mkdir(parents=True, exist_ok=True)
    target_dir = SITE_DIR / "assets"

    try:
        if target_dir.exists():
            shutil.rmtree(target_dir)
        shutil.copytree(ASSETS_DIR, target_dir)
        return True
    except Exception as e:
        print(f"  ❌ 复制静态资源失败: {e}")
        return False


def copy_content_assets(force: bool = False) -> bool:
    """
    复制 content 目录下的非 .typ 文件（如图片）到输出目录。
    支持增量复制：只复制修改过的文件。

    参数:
        force: 是否强制复制所有文件
    """
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    if not CONTENT_DIR.exists():
        print(f"  ⚠ 内容目录 {CONTENT_DIR} 不存在，跳过。")
        return True

    try:
        copy_count = 0
        skip_count = 0

        for item in CONTENT_DIR.rglob("*"):
            # 跳过目录和 .typ 文件
            if item.is_dir() or item.suffix == ".typ":
                continue

            # 跳过以下划线开头的路径
            relative_path = item.relative_to(CONTENT_DIR)
            if any(part.startswith("_") for part in relative_path.parts):
                continue

            # 计算目标路径
            target_path = SITE_DIR / relative_path

            # 增量复制检查
            if not force and target_path.exists():
                if get_file_mtime(item) <= get_file_mtime(target_path):
                    skip_count += 1
                    continue

            # 创建目标目录
            target_path.parent.mkdir(parents=True, exist_ok=True)

            # 复制文件
            shutil.copy2(item, target_path)
            copy_count += 1

        return True
    except Exception as e:
        print(f"  ❌ 复制内容资源文件失败: {e}")
        return False


def clean() -> bool:
    """
    清理生成的文件。
    """
    print("正在清理生成的文件...")

    if not SITE_DIR.exists():
        print(f"  输出目录 {SITE_DIR} 不存在，无需清理。")
        return True

    try:
        # 删除 _site 目录下的所有内容
        for item in SITE_DIR.iterdir():
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()

        print(f"  ✅ 已清理 {SITE_DIR}/ 目录。")
        return True
    except Exception as e:
        print(f"  ❌ 清理失败: {e}")
        return False


# 构建产物中不需要回源检查的路径（相对于 _site/）：
# - assets/: 每次 copy_assets 已 rmtree+重建
# - 顶层生成物：sitemap.xml / robots.txt / feed.xml
# 注意 404.html 是来自 content/404.typ，会走正常回源检查。
_PRUNE_EXEMPT_TOPS: set[str] = {"assets", "sitemap.xml", "robots.txt", "feed.xml"}


def _source_exists_for_output(site_file: Path) -> bool:
    """
    判断 _site/ 中的一个输出文件是否仍对应 content/ 里一个有效源头。

    规则：
    - 直接存在 content/<rel>（图片、PDF 等按原名复制的资源） → 有效
    - rel 是 "<section>/index.html"：
        * content/<section>/index.typ 存在 → 有效（手写的分类页）
        * content/<section>.typ 存在 → 有效（非目录页）
        * content/<section>/ 下有任一带 index.typ 的子目录 → 有效（自动生成的分类页）
    - rel 是 "<path>/index.html"：content/<path>/index.typ 存在 → 有效
    - rel 是 "<path>.html"：content/<path>.typ 存在 → 有效
    - rel 是 "<path>.pdf"：content/<path>.typ 存在 → 有效
    """
    rel = site_file.relative_to(SITE_DIR)
    rel_posix = rel.as_posix()

    # 直接对应 content/ 里的资源（图片等）
    direct = CONTENT_DIR / rel
    if direct.exists():
        return True

    # index.html 的三种来源
    if rel.name == "index.html":
        parent = rel.parent  # 相对于 content/ 的目录
        if parent == Path("."):
            # _site/index.html ← content/index.typ
            return (CONTENT_DIR / "index.typ").exists()

        section_dir = CONTENT_DIR / parent
        if (section_dir / "index.typ").exists():
            return True
        if (CONTENT_DIR / f"{parent}.typ").exists():
            return True
        # 自动生成的分类首页：该目录下还有任一文章
        if section_dir.is_dir():
            for child in section_dir.iterdir():
                if child.is_dir() and (child / "index.typ").exists():
                    return True
        return False

    # 其他 .html / .pdf：对应 content/<stem>.typ
    if rel.suffix in (".html", ".pdf"):
        typ_source = CONTENT_DIR / rel.with_suffix(".typ")
        return typ_source.exists()

    return False


def prune_orphans() -> None:
    """
    删除 _site/ 中源头已消失的产物（增量构建后的垃圾回收）。

    跳过由其他步骤独立管理的文件：assets/、sitemap.xml、robots.txt、feed.xml。
    """
    if not SITE_DIR.exists():
        return

    removed_files = 0
    for path in list(SITE_DIR.rglob("*")):
        if not path.is_file():
            continue

        rel = path.relative_to(SITE_DIR)
        top = rel.parts[0]
        if top in _PRUNE_EXEMPT_TOPS:
            continue

        if _source_exists_for_output(path):
            continue

        path.unlink()
        removed_files += 1

    # 清理空目录（不删 _site/ 本身）
    removed_dirs = 0
    for path in sorted(SITE_DIR.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if not path.is_dir():
            continue
        top = path.relative_to(SITE_DIR).parts[0] if path != SITE_DIR else ""
        if top in _PRUNE_EXEMPT_TOPS:
            continue
        try:
            path.rmdir()
            removed_dirs += 1
        except OSError:
            # 非空目录
            pass

    if removed_files or removed_dirs:
        print(f"🗑️  清理孤立产物: {removed_files} 个文件, {removed_dirs} 个空目录")


class _ReloadBus:
    """SSE 事件总线，负责把 reload 事件推送到所有连接的浏览器。"""

    def __init__(self):
        self._lock = threading.Lock()
        self._subscribers: list[queue.Queue] = []

    def subscribe(self) -> queue.Queue:
        q: queue.Queue = queue.Queue(maxsize=8)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q: queue.Queue) -> None:
        with self._lock:
            if q in self._subscribers:
                self._subscribers.remove(q)

    def broadcast(self, event: str = "reload") -> None:
        with self._lock:
            subs = list(self._subscribers)
        for q in subs:
            try:
                q.put_nowait(event)
            except queue.Full:
                pass


# 注入到 HTML 响应中的 SSE livereload 客户端脚本
_LIVERELOAD_SCRIPT = b"""
<script>
(function() {
  var es = new EventSource('/__reload__');
  es.addEventListener('reload', function() { location.reload(); });
  es.onerror = function() { /* keepalive: browser will auto-reconnect */ };
})();
</script>
"""


class _PreviewRequestHandler(http.server.SimpleHTTPRequestHandler):
    """
    本地预览 HTTP 请求处理器：
    - 找不到文件时返回 _site/404.html（HTTP 404）
    - 对 HTML 响应注入 livereload 脚本（保存源文件时浏览器自动刷新）
    - 提供 /__reload__ SSE 端点
    """

    # 由 serve() 注入
    site_dir: Path = Path(".")
    reload_bus: "_ReloadBus | None" = None

    # 让 super().__init__ 知道根目录
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.site_dir), **kwargs)

    # 关闭多余日志：只打印错误和重要请求
    def log_message(self, format: str, *args) -> None:
        # 静默正常的 200/304；保留 404/5xx 等异常
        try:
            status = int(args[1])
        except (IndexError, ValueError):
            status = 0
        if status >= 400:
            sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), format % args))

    # SSE livereload 端点
    def do_GET(self) -> None:
        if self.path == "/__reload__":
            self._serve_sse()
            return
        super().do_GET()

    def _serve_sse(self) -> None:
        if self.reload_bus is None:
            self.send_error(503, "reload bus not configured")
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Connection", "keep-alive")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()

        q = self.reload_bus.subscribe()
        try:
            # 立即发送一个 ping 让连接成立
            self.wfile.write(b": connected\n\n")
            self.wfile.flush()
            while True:
                try:
                    event = q.get(timeout=15)
                    payload = f"event: {event}\ndata: 1\n\n".encode("utf-8")
                    self.wfile.write(payload)
                    self.wfile.flush()
                except queue.Empty:
                    # 心跳，防止代理掐连接
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            return
        finally:
            self.reload_bus.unsubscribe(q)

    # 重写 send_head：找不到文件时返回 404.html
    def send_head(self):  # type: ignore[override]
        path = self.translate_path(self.path)
        f = None

        # 处理目录：寻找 index.html
        if os.path.isdir(path):
            parts = urllib.parse.urlsplit(self.path)
            if not parts.path.endswith("/"):
                self.send_response(301)
                new_parts = (parts[0], parts[1], parts[2] + "/", parts[3], parts[4])
                self.send_header("Location", urllib.parse.urlunsplit(new_parts))
                self.send_header("Content-Length", "0")
                self.end_headers()
                return None
            for index in ("index.html", "index.htm"):
                index_path = os.path.join(path, index)
                if os.path.isfile(index_path):
                    path = index_path
                    break
            else:
                # 目录无索引文件 → 404
                return self._serve_404()

        if not os.path.isfile(path):
            return self._serve_404()

        ctype = self.guess_type(path)

        # HTML 响应：读入内存、注入 livereload 脚本
        if ctype.startswith("text/html"):
            try:
                with open(path, "rb") as fp:
                    data = fp.read()
            except OSError:
                return self._serve_404()

            data = self._inject_livereload(data)
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            return io.BytesIO(data)

        # 其他类型走父类标准流程
        try:
            f = open(path, "rb")
        except OSError:
            return self._serve_404()

        try:
            fs = os.fstat(f.fileno())
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(fs[6]))
            self.send_header("Last-Modified", self.date_time_string(fs.st_mtime))
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
            self.end_headers()
            return f
        except Exception:
            f.close()
            raise

    def _serve_404(self):
        not_found = self.site_dir / "404.html"
        if not_found.is_file():
            try:
                data = not_found.read_bytes()
            except OSError:
                data = b"<h1>404 Not Found</h1>"
        else:
            data = b"<h1>404 Not Found</h1>"

        data = self._inject_livereload(data)
        self.send_response(404)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.end_headers()
        return io.BytesIO(data)

    def _inject_livereload(self, data: bytes) -> bytes:
        idx = data.rfind(b"</body>")
        if idx == -1:
            return data + _LIVERELOAD_SCRIPT
        return data[:idx] + _LIVERELOAD_SCRIPT + data[idx:]


class _ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    # 客户端中途断连（浏览器刷新/关闭标签/关闭 SSE 流）会抛出
    # ConnectionResetError / BrokenPipeError / ConnectionAbortedError，
    # 这些都是预期行为，不应打印栈。
    def handle_error(self, request, client_address) -> None:  # type: ignore[override]
        exc = sys.exc_info()[1]
        if isinstance(exc, (ConnectionResetError, BrokenPipeError, ConnectionAbortedError)):
            return
        super().handle_error(request, client_address)


class RebuildHandler:
    """监视源文件变化并触发增量构建，构建完成后通过 SSE 通知浏览器刷新。"""

    def __init__(self, reload_bus: "_ReloadBus | None" = None, debounce_seconds: float = 0.5):
        self.debounce = debounce_seconds
        self._last_build = 0.0
        self._lock = threading.Lock()
        self.reload_bus = reload_bus

    def _should_rebuild(self, path: str) -> bool:
        return path.endswith(
            (".typ", ".css", ".js", ".md", ".bib", ".yml", ".yaml", ".json", ".webp", ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".pdf")
        )

    def dispatch(self, event):
        if event.is_directory:
            return
        if self._should_rebuild(event.src_path):
            self._trigger_build()

    def _trigger_build(self):
        with self._lock:
            now = time.time()
            if now - self._last_build < self.debounce:
                return
            self._last_build = now

        print("\n👀 检测到文件变化，正在重新构建...")
        try:
            build()
            if self.reload_bus is not None:
                self.reload_bus.broadcast("reload")
            print("🔄 构建完成，浏览器已自动刷新。\n")
        except Exception as e:
            print(f"❌ 自动构建失败: {e}\n")


def preview(port: int = 8000, open_browser_flag: bool = True) -> bool:
    """
    启动本地预览服务器：
    - 自给自足的 HTTP server（不依赖 livereload / uvx）
    - 路径未匹配时返回 _site/404.html（HTTP 404），等价于 GitHub Pages 的行为
    - 通过 SSE + 注入脚本实现保存即刷新
    - watchdog 监视源文件变化 → 自动增量构建 → 推送 reload 事件
    """
    import webbrowser

    if not SITE_DIR.exists():
        print(f"  ⚠ 输出目录 {SITE_DIR} 不存在，请先运行 build 命令。")
        return False

    reload_bus = _ReloadBus()

    # 将运行时上下文注入到 handler 类（HTTPServer 用类本身实例化）
    handler_cls = type(
        "_BoundPreviewHandler",
        (_PreviewRequestHandler,),
        {
            "site_dir": SITE_DIR.resolve(),
            "reload_bus": reload_bus,
        },
    )

    try:
        from watchdog.observers import Observer
    except ImportError:
        print("  ❌ 未安装 watchdog。请运行 uv add watchdog 安装。")
        return False

    handler = RebuildHandler(reload_bus=reload_bus)
    observer = Observer()
    watch_paths = [CONTENT_DIR, CONFIG_FILE, Path("tufted-lib"), ASSETS_DIR]
    for path in watch_paths:
        if path.exists():
            observer.schedule(handler, str(path), recursive=True)
    observer.start()
    print("👀 文件监视已启动：content/, config.typ, tufted-lib/, assets/")

    server = _ThreadingHTTPServer(("", port), handler_cls)

    if open_browser_flag:
        def _open():
            time.sleep(0.5)
            webbrowser.open(f"http://localhost:{port}")
        threading.Thread(target=_open, daemon=True).start()

    print(f"🚀 预览服务器已启动: http://localhost:{port} （按 Ctrl+C 停止）\n")
    try:
        server.serve_forever()
        return True
    except KeyboardInterrupt:
        print("\n服务器已停止。")
        return True
    finally:
        try:
            server.shutdown()
        except Exception:
            pass
        server.server_close()
        observer.stop()
        observer.join()


def parse_html_metadata(html_path: Path) -> dict[str, str]:
    """
    解析 HTML 文件并返回元数据解析器实例。

    参数:
        html_path (Path): HTML 文件路径

    返回:
        HTMLMetadataParser: 包含解析结果的解析器实例
    """
    parser = HTMLMetadataParser()
    parser.feed(html_path.read_text(encoding="utf-8"))
    return parser.metadata


def get_site_url() -> str | None:
    """
    从生成的首页 HTML 文件中解析站点 URL。

    功能:
        从 _site/index.html 的 <link rel="canonical" href="..."> 提取 site-url。

    返回:
        str: 站点的根 URL（如 "https://example.com"），末尾不带斜杠。
            如果未配置或解析失败则返回 None。
    """
    index_html = SITE_DIR / "index.html"
    parser = parse_html_metadata(index_html)

    if parser.get("link"):
        return parser["link"].rstrip("/")

    return None


def extract_post_metadata(index_html: Path) -> tuple[str, str, datetime | None]:
    """
    从生成的 HTML 文件中提取文章的元数据信息。

    返回:
        (title, link, date) 三元组。
        date 在 HTML 或文件夹名中都无法推断时为 None。
    """
    parser = parse_html_metadata(index_html)

    title = parser["title"].strip()
    link = parser.get("link", "")
    date_obj = None

    if parser.get("date"):
        try:
            date_obj = datetime.strptime(parser["date"].split("T")[0], "%Y-%m-%d")
            date_obj = date_obj.replace(tzinfo=timezone.utc)
        except Exception:
            pass

    if not date_obj:
        date_match = re.search(r"(\d{4}-\d{2}-\d{2})", index_html.parent.name)
        if date_match:
            try:
                date_obj = datetime.strptime(date_match.group(1), "%Y-%m-%d")
                date_obj = date_obj.replace(tzinfo=timezone.utc)
            except ValueError:
                pass

    return title, link, date_obj


def generate_sitemap(site_url: str) -> bool:
    """
    使用 Python 标准库 xml.etree.ElementTree 生成 sitemap.xml。
    """
    import xml.etree.ElementTree as ET

    sitemap_path = SITE_DIR / "sitemap.xml"
    sitemap_ns = "http://www.sitemaps.org/schemas/sitemap/0.9"

    # 注册默认命名空间
    ET.register_namespace("", sitemap_ns)

    # 创建根元素
    urlset = ET.Element("urlset", xmlns=sitemap_ns)

    # 遍历 _site 目录
    for file_path in sorted(SITE_DIR.rglob("*.html")):
        rel_path = file_path.relative_to(SITE_DIR).as_posix()

        # 确定 URL 路径
        if rel_path == "index.html":
            url_path = ""
        elif rel_path.endswith("/index.html"):
            url_path = rel_path.removesuffix("index.html")
        elif rel_path.endswith(".html"):
            url_path = rel_path.removesuffix(".html") + "/"
        else:
            url_path = rel_path

        full_url = f"{site_url}/{url_path}"

        # 获取最后修改时间
        mtime = file_path.stat().st_mtime
        lastmod = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")

        # 创建 url 元素
        url_elem = ET.SubElement(urlset, "url")
        ET.SubElement(url_elem, "loc").text = full_url
        ET.SubElement(url_elem, "lastmod").text = lastmod

    # 生成 XML 字符串
    ET.indent(urlset, space="  ")
    xml_str = ET.tostring(urlset, encoding="unicode", xml_declaration=False)
    sitemap_content = f'<?xml version="1.0" encoding="UTF-8"?>\n{xml_str}'

    try:
        sitemap_path.write_text(sitemap_content, encoding="utf-8")
        print(f"✅ Sitemap 构建完成: 包含 {len(urlset)} 个页面")
        return True
    except Exception as e:
        print(f"❌ Sitemap 构建失败: {e}")
        return False


def generate_robots_txt(site_url: str) -> bool:
    """
    Generate robots.txt pointing to the sitemap.
    """
    robots_content = f"""User-agent: *
Allow: /

Sitemap: {site_url}/sitemap.xml
"""

    try:
        (SITE_DIR / "robots.txt").write_text(robots_content, encoding="utf-8")
        return True
    except Exception as e:
        print(f"❌ 生成 robots.txt 失败: {e}")
        return False


# ============================================================================
# 分类首页自动生成
# ============================================================================


def get_nav_links() -> list[tuple[str, str]]:
    """
    从已编译的 _site/index.html 中解析 header 导航链接。

    返回:
        [(href, display_name), ...]
    """
    index_html = SITE_DIR / "index.html"
    if not index_html.exists():
        return []
    return parse_html_metadata(index_html).get("nav_links", [])


def find_auto_section_dirs() -> list[Path]:
    """
    找出需要自动生成分类首页的分类目录。

    判定规则：`content/<section>/` 是目录，且内部有至少一个带 `index.typ` 的子目录，
    且 `content/<section>/index.typ` 不存在（存在则用户手写，不自动覆盖）。

    返回:
        需要自动生成分类首页的 content 下的分类目录列表。
    """
    if not CONTENT_DIR.is_dir():
        return []

    sections: list[Path] = []
    for section_dir in sorted(CONTENT_DIR.iterdir()):
        if not section_dir.is_dir():
            continue
        if section_dir.name.startswith("_") or section_dir.name.startswith("."):
            continue
        # 用户手写的分类首页：不自动生成
        if (section_dir / "index.typ").exists():
            continue
        # 判断是否有"文章子目录"
        has_article = any(
            child.is_dir() and (child / "index.typ").exists()
            for child in section_dir.iterdir()
        )
        if has_article:
            sections.append(section_dir)
    return sections


def _collect_section_posts(section_dir: Path) -> list[dict]:
    """
    收集分类目录下所有文章的元数据（从已编译的 HTML 解析）。
    """
    site_section = SITE_DIR / section_dir.name
    posts: list[dict] = []
    if not site_section.is_dir():
        return posts

    for item in sorted(site_section.iterdir()):
        if not item.is_dir():
            continue
        index_html = item / "index.html"
        if not index_html.exists():
            continue
        title, _link, date_obj = extract_post_metadata(index_html)
        if not title:
            continue
        posts.append(
            {
                "slug": item.name,
                "title": title,
                "date": date_obj,
            }
        )
    # 按日期降序；没日期的放最后
    posts.sort(
        key=lambda p: p["date"] or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    return posts


def _typst_string_literal(s: str) -> str:
    """将 Python 字符串转义为 Typst 字符串字面量（含引号）。"""
    escaped = s.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def _render_section_typ(
    section_name: str, display_name: str, posts: list[dict]
) -> str:
    """
    生成一段 Typst 源码，用于编译该分类的首页。

    - 文章按年份分组，年份降序，组内日期降序
    - 每篇文章一行：`- #link("<slug>/")[标题]`
    """
    lines: list[str] = []
    lines.append('#import "/config.typ": template, tufted')
    lines.append("#show: template.with(")
    lines.append(f"  title: {_typst_string_literal(display_name)},")
    lines.append(")")
    lines.append("")

    # 按年份分组
    grouped: dict[int | None, list[dict]] = {}
    for p in posts:
        year = p["date"].year if p["date"] else None
        grouped.setdefault(year, []).append(p)

    # 年份降序，None（无日期）放在最前
    def year_key(y: int | None) -> tuple[int, int]:
        return (0, 0) if y is None else (1, -y)

    for year in sorted(grouped.keys(), key=year_key):
        heading = "未注明日期" if year is None else str(year)
        lines.append(f"== {heading}")
        lines.append("")
        for p in grouped[year]:
            href = f"{p['slug']}/"
            title = p["title"]
            lines.append(f"- #link({_typst_string_literal(href)})[{title}]")
        lines.append("")

    return "\n".join(lines)


def build_section_indices() -> bool:
    """
    为所有需要自动生成首页的分类目录编译一份分类首页。

    分类名使用 config.typ 的 header-links 中的中文显示名（目录名无中文映射则使用目录名本身）。
    """
    nav = get_nav_links()
    # 构造 {"posts": "知识", ...}
    display_name_map: dict[str, str] = {}
    for href, name in nav:
        slug = href.strip("/")
        if slug:
            display_name_map[slug] = name

    sections = find_auto_section_dirs()
    if not sections:
        return True

    print("正在生成分类首页...")
    ok = True
    for section_dir in sections:
        section_name = section_dir.name
        display_name = display_name_map.get(section_name, section_name)
        posts = _collect_section_posts(section_dir)

        typ_src = _render_section_typ(section_name, display_name, posts)
        output_path = SITE_DIR / section_name / "index.html"
        output_path.parent.mkdir(parents=True, exist_ok=True)

        args = [
            "typst",
            "compile",
            "--root",
            ".",
            "--font-path",
            str(ASSETS_DIR),
            "--features",
            "html",
            "--format",
            "html",
            "--input",
            f"page-path={section_name}",
            "-",
            str(output_path),
        ]
        result = subprocess.run(
            args,
            input=typ_src,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            print(f"  ❌ 生成 /{section_name}/ 分类首页失败: {result.stderr.strip()}")
            ok = False
        else:
            print(f"  ✅ 生成 /{section_name}/ 分类首页 ({len(posts)} 篇文章)")
    return ok


# ============================================================================
# 新建文章 (new 命令)
# ============================================================================


def slugify(title: str) -> str:
    """
    将标题转换为 slug（用于目录名）。

    规则：小写 + 空格/下划线替换为短划线；仅保留 [a-z0-9\u4e00-\u9fff-] 字符。
    """
    s = title.strip().lower()
    s = re.sub(r"[\s_]+", "-", s)
    s = re.sub(r"[^a-z0-9\u4e00-\u9fff-]", "", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s


def cmd_new(section: str, title: str) -> bool:
    """
    新建一篇文章。

    参数:
        section: 分类目录名（必须已存在于 content/ 下）
        title:   文章标题（原始，空格连接的 argv 剩余部分）
    """
    if not section:
        print("❌ 缺少分类名。")
        return False
    if not title.strip():
        print("❌ 缺少文章标题。")
        return False

    section_dir = CONTENT_DIR / section
    if not section_dir.is_dir():
        print(f"❌ 分类 '{section}' 不存在：{section_dir}")
        print(f"   不自动创建新分类。请先手动创建 {section_dir}/ 或选择已有分类。")
        return False

    slug_body = slugify(title)
    if not slug_body:
        print(f"❌ 无法从标题生成有效 slug: {title!r}")
        return False

    today = datetime.now()
    slug = f"{today:%Y-%m-%d}-{slug_body}"
    article_dir = section_dir / slug
    if article_dir.exists():
        print(f"❌ 目标目录已存在: {article_dir}")
        return False

    article_dir.mkdir(parents=True, exist_ok=False)

    typ_content = (
        '#import "/config.typ": template, tufted\n'
        "#show: template.with(\n"
        f"  title: {_typst_string_literal(title)},\n"
        f"  date: datetime(year: {today.year}, month: {today.month}, day: {today.day}),\n"
        ")\n"
        "\n"
    )
    (article_dir / "index.typ").write_text(typ_content, encoding="utf-8")

    print(f"✅ 已创建: {article_dir / 'index.typ'}")
    return True


def build(force: bool = False) -> bool:
    """
    完整构建：HTML + PDF + 资源。

    参数:
        force: 是否强制重建所有文件
    """
    print("-" * 60)
    if force:
        clean()
        print("🛠️ 开始完整构建...")
    else:
        print("🚀 开始增量构建...")
    print("-" * 60)

    # 确保输出目录存在
    SITE_DIR.mkdir(parents=True, exist_ok=True)

    results = []

    print()
    results.append(build_html(force))
    results.append(build_pdf(force))
    print()

    results.append(copy_assets())
    results.append(copy_content_assets(force))

    prune_orphans()

    if site_url := get_site_url():
        results.append(build_section_indices())
        results.append(generate_sitemap(site_url))
        results.append(generate_robots_txt(site_url))

    print("-" * 60)
    if all(results):
        print("✅ 所有构建任务完成！")
        print(f"  📂 输出目录: {SITE_DIR.absolute()}")
    else:
        print("⚠ 构建完成，但有部分任务失败。")
    print("-" * 60)

    return all(results)


# ============================================================================
# 命令行接口
# ============================================================================


def create_parser() -> argparse.ArgumentParser:
    """
    创建命令行参数解析器。
    """
    parser = argparse.ArgumentParser(
        prog="blog.py",
        description="Tufted Blog 构建脚本 - 将 content 中的 Typst 文件编译为 HTML 和 PDF",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
构建脚本默认只重新编译修改过的文件，可使用 -f/--force 选项强制完整重建：
    uv run blog.py build --force
    或 python blog.py build -f

使用 preview 命令启动本地预览服务器：
    uv run blog.py preview
    或 python blog.py preview -p 3000  # 使用自定义端口

新建文章：
    uv run blog.py new art this is my title

更多信息请参阅 README.md
""",
    )

    subparsers = parser.add_subparsers(dest="command", title="可用命令", metavar="<command>")

    build_parser = subparsers.add_parser("build", help="完整构建 (HTML + PDF + 资源)")
    build_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    html_parser = subparsers.add_parser("html", help="仅构建 HTML 文件")
    html_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    pdf_parser = subparsers.add_parser("pdf", help="仅构建 PDF 文件")
    pdf_parser.add_argument("-f", "--force", action="store_true", help="强制完整重建")

    subparsers.add_parser("assets", help="仅复制静态资源")
    subparsers.add_parser("clean", help="清理生成的文件")

    preview_parser = subparsers.add_parser("preview", help="启动本地预览服务器")
    preview_parser.add_argument(
        "-p", "--port", type=int, default=8000, help="服务器端口号（默认: 8000）"
    )
    preview_parser.add_argument(
        "--no-open", action="store_false", dest="open_browser", help="不自动打开浏览器"
    )
    preview_parser.set_defaults(open_browser=True)

    new_parser = subparsers.add_parser(
        "new",
        help="新建一篇文章：uv run blog.py new <section> <title words...>",
    )
    new_parser.add_argument("section", help="分类名，例如 art / posts / english-post")
    new_parser.add_argument(
        "title",
        nargs=argparse.REMAINDER,
        help="文章标题（用空格分隔的多个词，按原样拼接）",
    )

    return parser


if __name__ == "__main__":
    parser = create_parser()
    args = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    # 确保在项目根目录运行
    script_dir = Path(__file__).parent.absolute()
    os.chdir(script_dir)

    # 获取 force 参数
    force = getattr(args, "force", False)

    # 使用 match-case 执行对应的命令
    match args.command:
        case "build":
            success = build(force)
        case "html":
            success = build_html(force)
        case "pdf":
            success = build_pdf(force)
        case "assets":
            success = copy_assets()
        case "clean":
            success = clean()
        case "preview":
            success = preview(getattr(args, "port", 8000), getattr(args, "open_browser", True))
        case "new":
            title = " ".join(args.title).strip()
            success = cmd_new(args.section, title)
        case _:
            print(f"❌ 未知命令: {args.command}")
            success = False

    sys.exit(0 if success else 1)
