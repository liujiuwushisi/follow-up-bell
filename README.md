# FollowUpBell｜任务跟进小组件

一个常驻 macOS 桌面与菜单栏的任务跟进工具。它按项目分组展示进度，并在每天 11:00、15:00、20:00 逐条提醒需要跟进的项目。

## 功能

- 从 JSON 或 CSV 一次导入全部项目
- 按分组展示项目、当前进度、负责人和最近跟进时间
- 项目与小分组直接新增并就地改名，无需弹窗
- 拖动项目时显示半透明行虚影和目标插入线，可调整顺序或移动到同一大分组下的其他小分组
- 点击大分组与小分组名称直接修改
- 大分组支持确认后永久删除
- 看板隐藏滚动条，保留滚轮与触控板滚动
- 每天 11:00、15:00、20:00 自动提醒
- 点击“有了有了”记录跟进时间并切换下一项
- 菜单栏常驻，可随时手动触发提醒
- 下班倒计时、里程碑进度、小车动画与 25/45 分钟番茄钟
- 数据仅保存在本机

## 下载体验

1. 下载并解压 `FollowUpBell-macOS-arm64.zip`。
2. 双击“任务跟进小组件.app”。
3. 如果 macOS 阻止首次打开，请在 Finder 中右键应用并选择“打开”。
4. 使用“载入示例”体验，或导入仓库中的 `outputs/示例项目.json`。

当前构建适用于 Apple 芯片 Mac，最低系统版本为 macOS 13。

## 从源码构建

```sh
mkdir -p .build/module-cache
xcrun swiftc \
  -module-cache-path .build/module-cache \
  -framework Cocoa \
  outputs/FollowUpBell.swift \
  -o outputs/任务跟进小组件.app/Contents/MacOS/FollowUpBell
```

## 项目文件

- `outputs/FollowUpBell.swift`：AppKit 源码
- `outputs/任务跟进小组件.app`：本地可运行应用
- `outputs/示例项目.json`：导入示例
- `outputs/产品方案与数据结构.md`：产品规则和数据格式

## 已知限制

- 应用需要保持运行才能按时触发提醒。
- 当前下载包仅编译了 Apple 芯片版本。
- 当前版本未签名、未公证，因此首次启动可能出现 macOS 安全提示。
