# SnapShelf · Mac 临时截图

菜单栏截图工具，默认快捷键 **Command+A**。框选后按 **Command+V**，可向支持图片的聊天框、文档粘贴图片，向 Finder 文件夹粘贴 PNG 文件。支持 macOS 13 及以上；当前构建对应此 Mac 的 Apple Silicon 架构。

## 下载应用

在 [Releases](https://github.com/qunqundexiao1/SnapShelf/releases) 下载 `SnapShelf-macOS.zip`，解压后双击 `SnapShelf.app`。本仓库为私有仓库，需要登录有访问权限的 GitHub 账号。

打开后应用驻留在屏幕右上角菜单栏，点击取景框图标 → **截图快捷键** 可修改组合。首次截图需要按系统提示授予屏幕录制权限。

## 使用

1. 打开下载并解压得到的 `SnapShelf.app`，或自行构建的 `build/SnapShelf.app`，菜单栏会出现取景框图标。首次显示说明。
2. 按 Command+A，首次按系统提示授予屏幕录制权限。如果系统要求，请退出并重新打开应用。
3. 拖动选择截图区域，按空格切换窗口截图，按 Esc 取消。
4. 在目标位置按 Command+V。读取、粘贴截图不会主动删除临时文件，可以重复粘贴。
5. 复制新的文字、文件或图片后，应用检测到剪贴板变更，自动删除先前的临时截图。

**Command+A 会占用其他应用的「全选」。** 菜单 → 截图快捷键可改成 Command+Shift+A、Command+Option+A 或 Control+Option+A，设置会保留。快捷键被其他程序占用时会提示，仍可通过菜单截图。

## 临时存储与清理

这里的“虚拟位置”使用私有的本地缓存目录实现，不需要建立虚拟磁盘，也不在桌面留下截图：

```
~/Library/Caches/com.local.snapshelf/Captures/
```

- 剪贴板同时提供 PNG、TIFF 和文件 URL；截图保留在缓存，直到剪贴板被替换、再次截图、手动清除或正常退出。
- 正常运行时每 0.2 秒检测一次剪贴板版本。系统休眠或暂停进程期间无法即时清理，恢复后继续检测。
- 仅删除本应用缓存目录内以 `SnapShelf-` 开头的 PNG；不会删除用户后来复制的源文件，也不会删除已保存到其他位置的副本。
- 正常退出会清除仍由本应用持有的剪贴板及截图，不会清除后来复制的其他内容。异常退出残留在下次启动时清理。
- 使用磁盘缓存而非纯内存虚拟文件；删除是普通文件删除，不保证安全擦除。系统剪贴板历史工具或通用剪贴板保留的副本由对应工具管理。
- 纯文字输入框不接收图片；不同应用对图片、文件附件的选择由其自身实现。特别是异步附件上传，应等目标应用完成读取后再复制其他内容。
- 不上传截图、不提供网络服务、不自动配置开机启动。

## 构建与验证

需要 Xcode 或 Command Line Tools（Swift 5.9+），无第三方依赖。

```sh
swift test
zsh scripts/build-app.sh
open build/SnapShelf.app
```

构建产物：`build/SnapShelf.app`、`build/SnapShelf-macOS.zip`。使用本机 ad-hoc 签名，适合本机运行；向其他 Mac 分发时需要开发者签名与公证，或由接收方按系统提示批准打开。

测试使用独立命名剪贴板，不修改日常系统剪贴板，覆盖图片/文件双格式、文字和文件替换清理、重复截图、无效图片保护、退出保护、缓存清理范围及定时检测。系统权限、交互截图与跨应用粘贴还需要实际交互验证。

## 源码

- `Sources/SnapShelf/AppMain.swift`：菜单栏、使用说明、偏好设置。
- `Sources/SnapShelf/CaptureCoordinator.swift`：调用系统交互截图并处理取消。
- `Sources/SnapShelf/ClipboardStore.swift`：双格式剪贴板与缓存生命周期。
- `Sources/SnapShelf/HotKeyManager.swift`：Carbon 全局快捷键，不需要辅助功能或输入监听权限。
