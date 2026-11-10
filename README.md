# LyricsFlow

Apple Music 的全屏逐字歌词。读取“音乐”App 正在播放的歌曲，从多个来源匹配歌词，逐字扫描高亮，背景随封面取色。只读取播放信息，不会控制播放。

## 安装

1. 打开 `LyricsFlow-x.y.z.dmg`，按窗口提示把 LyricsFlow 拖进“应用程序”文件夹。窗口下方也写了打不开时怎么办，和下面一致。
2. 首次打开会被系统拦下（应用没有经过 Apple 公证），按下面任一方式放行，只需做一次：

   **方式 A：隐私与安全性（推荐）**
   1. 双击 LyricsFlow，出现“无法打开”的提示后点“完成”。
   2. 打开“系统设置 → 隐私与安全性”，滚动到底部的“安全性”。
   3. 找到“已阻止使用 LyricsFlow”，点“仍要打开”，再输入密码或指纹确认。

   **方式 B：终端**
   ```
   xattr -dr com.apple.quarantine /Applications/LyricsFlow.app
   ```
   如果提示“已损坏，无法打开”，用这个方式。

3. 第一次运行会弹出“LyricsFlow 想要控制‘音乐’”，点“好”。如果误点了不允许：
   “系统设置 → 隐私与安全性 → 自动化”，勾选 LyricsFlow 下的“音乐”。

## 使用

- 在“音乐”App 里播放歌曲，LyricsFlow 会自动匹配歌词。
- 歌词不对时，用菜单栏图标打开歌词搜索窗口，选一条正确的，之后同一首歌会记住这个选择。
- 菜单栏“显示 → 图标”可以换 Dock 图标。默认“跟随封面”，图标颜色随正在播放的封面渐变；也可以固定成极光、海洋、日落、Music 红或黑白（黑白可跟随系统深浅色）。只在运行时生效，Finder 里的图标不变。
- 窗口宽就是横屏布局，窄就是竖屏布局，可以全屏。

## 系统要求

macOS 14 或更高，已安装“音乐”App。

## 从源码构建

需要 Swift 6.2+，只装 Command Line Tools 即可。

```
scripts/bundle.sh                # build/LyricsFlow.app
VERSION=0.1.0 scripts/make_dmg.sh   # build/LyricsFlow-0.1.0.dmg（arm64 + x86_64，需在登录的桌面会话里运行）
swift scripts/make_icon.swift . pngs   # 重绘 assets/icons/*.png（运行时可选图标）
swift scripts/make_icon.swift . iconset aurora && iconutil -c icns build/AppIcon.iconset -o assets/AppIcon.icns   # 默认图标
```
