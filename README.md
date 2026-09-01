# MemWatch

按 **App 维度**查看内存占用的 macOS 原生小工具，支持一键关闭进程。

## 为什么写它

活动监视器按**进程**列出内存，像 `node`、`Code Helper (Renderer)`、`WindowServer` 这类进程名
看不出属于哪个 App。24G 内存的开发机上，光 Dia / Lark / VS Code 的辅助进程就能吃掉好几个 G，
你却很难一眼看出是谁。

MemWatch 把同一 `.app` 下的所有进程**聚合**成一行，显示总内存 + 进程数 + 一键关闭。

## 功能

- **App 维度聚合** — 按 `.app` bundle 归组，显示该 App 所有进程的内存总和
- **进程数** — 一眼看出哪个 App 偷偷开了一堆辅助进程（Dia 29 个、VS Code 16 个…）
- **一键关闭** — 三级关闭策略（见下）
- **展开明细** — 点行展开，看每个进程的 PID / 名称 / 路径 / 内存，可单独杀
- **系统内存总览** — 顶部显示总内存、已用/可用、活跃/联动/压缩分布
- **搜索** — 按 App 名、Bundle ID、进程名、可执行路径过滤
- **只看 App** — 过滤掉系统进程，专注你能关的东西
- **自动刷新** — 默认 2 秒一次，可关

## 关闭策略（重要）

点「关闭」不是直接 `kill -9`，而是三级降级，尽量不丢数据：

1. **优雅退出** — 通过 bundle ID 发 Apple Event `tell application id "..." to quit`，
   让 App 自己走正常退出流程（会弹保存提示）
2. **SIGTERM** — 1.5 秒后还活着的，发终止信号，允许清理
3. **SIGKILL** — 再 1.5 秒还活着的，强杀

系统进程（没有 bundle ID 的）跳过第 1 步，直接 SIGTERM → SIGKILL。

如果最终还有进程存活（通常是 root 进程），会提示你可能需要管理员权限。

## 构建

```bash
cd /Users/macongcong/MemWatch
./Scripts/build.sh
```

产物：`/Users/macongcong/MemWatch/MemWatch.app`

或手动：

```bash
swift build -c release --disable-sandbox
open MemWatch.app
```

> 注意：本环境 SPM 沙箱不可用，必须带 `--disable-sandbox`。

## 技术要点

进程数据全部走 **libproc**（`proc_listpids` + `proc_pidinfo(PROC_PIDTASKALLINFO)` +
`proc_pidpath`），不 shell 出去调 `ps`：

- `ps` 在 macOS Sequoia 上受 TCC 限制，经常 `Operation not permitted`
- libproc 更快，一次 `PROC_PIDTASKALLINFO` 同时拿到进程名 + RSS

**App 归属判定**：拿到可执行文件路径后，向上找第一个 `.app` 结尾的路径组件。
找不到 `.app` 的（系统守护进程、独立二进制）按可执行文件名归到「xxx · 系统进程」桶里。

**关于 `proc_taskinfo` 结构体**：Swift 重声明时必须和 C 的 `sys/proc_info.h` 逐字节对齐，
字段数对不上会导致 `proc_pidinfo` 返回 0（表现为所有进程内存都是 0）。
定长 `char` 数组要用 **Int8 元组**表示，用 `[Int8]` 会变成堆引用、内存布局就错了。

## 目录结构

```
MemWatch/
├── Package.swift
├── Resources/Info.plist
├── Scripts/
│   ├── build.sh            # 构建 + 打包 .app
│   ├── make_icon.swift     # 生成 AppIcon.icns
│   └── poc.swift           # libproc 验证脚本
└── Sources/MemWatch/
    ├── MemWatchApp.swift        # @main 入口
    ├── ContentView.swift        # 主界面
    ├── ProcessMonitor.swift     # 扫描 + 归组 + 刷新循环
    ├── ProcessKiller.swift      # 三级关闭
    ├── AppBundleResolver.swift  # .app 路径 / 名称 / 图标
    ├── BundleInfoCache.swift    # 线程安全的 bundle 元数据缓存
    ├── LibProc.swift            # libproc C 结构体绑定
    ├── Models.swift
    ├── MemoryFormatter.swift
    └── Views/
        ├── AppRowView.swift
        ├── ProcessDetailView.swift
        └── SummaryHeaderView.swift
```
