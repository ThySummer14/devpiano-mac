# devpiano-mac

**macOS 原生构建版 devpiano** — 基于 [0xnayuta/devpiano](https://github.com/0xnayuta/devpiano)（AGPL-3.0）移植到 Apple Silicon Mac，用电脑键盘学琴、演奏。

中文 | [English](README_en.md)

---

## 🍎 macOS 快速开始

### 环境要求

- macOS 12+（Apple Silicon 原生 arm64，Intel 需改 `CMAKE_OSX_ARCHITECTURES`）
- Xcode Command Line Tools（`xcode-select --install`）
- CMake ≥ 3.22 与 Ninja：`brew install cmake ninja`

### 首次克隆（还原子模块）

```bash
git clone --recurse-submodules <本仓库地址>
cd devpiano-mac
# 若忘记 --recurse-submodules：
git submodule update --init --recursive
```

> ⚠️ **JUCE 版本注意**：JIVE 声明式 UI 框架尚未适配 JUCE 9（`Drawable` 在 JUCE 9 中不再继承 `Component`），因此本仓库将 JUCE 固定在 **8.0.15**。请勿升级到 JUCE 9，除非先移植 JIVE。

### 一键构建

```bash
./scripts/build_macos.sh              # Release 构建（默认 arm64）
./scripts/build_macos.sh --open       # 构建完成后直接启动
./scripts/build_macos.sh --debug      # Debug 构建
./scripts/build_macos.sh --clean      # 全量重建
```

产物：`build-mac-release/devpiano_artefacts/Release/DevPiano.app`（CMake Preset 名：`macos-clang-release` / `macos-clang-debug`）。

### 默认弹奏键位（36 键 / 4 个八度）

```text
[数字行]  1=C6 2=D6 3=E6 4=F6 5=G6 6=A6 7=B6 8=C7 9=D7 0=E7
[ Q 行 ]  Q=C5 W=D5 E=E5 R=F5 T=G5 Y=A5 U=B5 I=C6 O=D6 P=E6
[ A 行 ]  A=中央C(C4) S=D4 D=E4 F=F4 G=G4 H=A4 J=B4 K=C5 L=D5
[ Z 行 ]  Z=C3 X=D3 C=E3 V=F3 B=G3 N=A3 M=B3
空格 = 延音踏板（CC64）    F1-F12 = 切换演奏预设
```

### 界面语言（中/英）

- **首次启动跟随 macOS 系统语言**：中文系统自动进入简体中文界面，其余默认英文；
- **随时在设置里切换**：打开「设置（Settings）」窗口 → 「Language:」下拉框 → `English` / `简体中文`，即时生效并记住选择；
- 中文语言包随 App 二进制内嵌（`zh_CN.loc`，211+ 词条），无需外部文件。

### macOS 移植说明（相对上游的改动）

| 改动 | 原因 |
| --- | --- |
| `CMakeLists.txt`：APPLE 平台跳过 PCH | CMake 的 PCH 以纯 C++ 模式生成，套用到 JUCE 的 `.mm`（Objective-C++）翻译单元报错 |
| JUCE 子模块固定 8.0.15 | 上游 `develop` 已推进到 JUCE 9，与 JIVE 不兼容 |
| 默认 UI 语言跟随系统语言（`SettingsModel.h`） | 上游写死 `"en"`；本仓库首次启动按 `SystemStats::getDisplayLanguage()` 选择中文/英文，设置中仍可切换 |
| 补全 zh_CN 语言包缺失词条（5 条） | 对照全部 `TRANS()` 字符串查漏：无音频设备 / 移调 / 预设保存删除重命名提示 |
| 新增 `macos-clang-release/debug` CMake Preset | 与 Windows/Linux Preset 对等的 macOS 入口 |
| 新增 `scripts/build_macos.sh` | 一键环境自检 + 构建 + 启动 |

音频后端经 CoreAudio 输出（WASAPI/ASIO 选项在 macOS 上自动不可见），VST3 插件宿主在 macOS 上同样可用（扫描 `/Library/Audio/Plug-Ins/VST3` 等）。

---

以下为上游原版 README（功能特性与架构说明，双平台通用）。

---

**devpiano** 是一款基于 JUCE 框架的现代电脑键盘钢琴应用，聚焦电脑软件键盘演奏、高保真物理建模音源与 MIDI 文件处理。

应用内置自主研发、覆盖 **7 大声学子系统** 的纯 C++ 物理建模钢琴音源（`PianoSynthVoice`），同时提供 **VST3 插件宿主** 支持，结合标准 88 键虚拟键盘、16 通道 MIDI 路由矩阵、JIVE 声明式 UI 以及完整的演奏录制、回放、持久化与离线音频渲染工作流。

项目定位、核心能力与明确非目标详见 [`docs/reference/project-scope.md`](docs/reference/project-scope.md)。

---

## 核心特性矩阵

```text
               ┌────────────────────────────────────────────────────────┐
               │              devpiano v1.0.0 Architecture              │
               └───────────────────────────┬────────────────────────────┘
                                           │
         ┌─────────────────────────────────┼────────────────────────────────┐
         ▼                                 ▼                                ▼
┌──────────────────┐             ┌──────────────────┐             ┌──────────────────┐
│   发声与插件引擎  │             │   输入与路由矩阵  │             │  录制回放与渲染  │
│ 7大声学系统物理建模│             │ 稳定按键映射+88键│             │ 实时无锁采集+Take│
│ VST3 宿主与 Editor│             │ 16通道矩阵+调号  │             │ 离线多线程WAV导出│
└──────────────────┘             └──────────────────┘             └──────────────────┘
```

### 🎹 高保真物理建模钢琴音源（Physical Modeling Piano Engine）
- **7 大声学物理子系统**：覆盖琴槌（Hammer）、琴弦（String）、琴桥（Bridge）、音板（Soundboard）、琴体（Cabinet）、空气（Air）与空间（Room）；
- **88 键连续物理参数映射**：基于 Bensa et al. (2003) 与 Steinway B 实测标定，连续插值琴弦刚度 $B$、击弦比 $d/L$、阻尼常数与 1/2/3 弦物理分区（`Piano88KeyTable.h`）；
- **非线性打击与动力学绽放**：三层毛毡动力学压实、动态接触时间 $T_c$、击弦点几何梳状陷波、3ms 高频瞬态裂音（HF Crack）、泛音时间滞后膨胀绽放（Harmonic Blooming）与强击软饱和；
- **真实共鸣与空间辐射**：16 峰正交云杉木物理音板模态、4.2kHz 云杉木高频粘滞吸收低通滤波、琴桥立体声空间辐射、同音三弦 Mid-Side 差分展开与非对称拍频；
- **机械与踏板交感拟真**：CC64 全局交感共鸣弦池、未踩踏板单键开放弦交感、琴盖开合度声学传递函数（Full/Half/Closed）与制音器落弦低频闷击（Damper Felt Fall）；
- **硬实时性能保证**：Magic Circle 二阶递归振荡器，逐采样**零三角函数调用（零 `std::sin`）**，8 复音齐奏单核 CPU 负载 $\le 0.7\%$，实时音频路径严格**零堆分配、零锁**；支持与内置正弦波（`SineSynthVoice`）平滑对比切换。

### 🔌 VST3 插件宿主系统（VST3 Plugin Hosting）
- **安全生命周期管理**：支持默认及自定义多目录扫描、异步分片扫描（Chunked Scan）、XML 缓存恢复与失败文件追踪；
- **插件加载与 Editor 托管**：支持加载 VST3 乐器插件并参与实时音频处理，具备独立 Editor 窗口生命周期管理与异常安全隔离。

### ⌨️ 电脑键盘演奏与 88 键虚拟键盘（Keyboard Input & Keybed）
- **稳定按键映射**：基于稳定 key code 路由，消除字符输入法与 CapsLock 状态干扰；具备严格成对的 note on/off 跟踪与焦点丢失 panic 自动清理；
- **标准 88 键大三角钢琴键盘**：覆盖 A0～C8（MIDI 21～108）完整音域，支持宽屏动态对称居中与毛毡条自适应；
- **局部脏矩形快速渲染**：虚拟键盘引入 `repaintKey()` 与视口相交裁剪，彻底消除密集 MIDI 回放时的全量重绘，UI 渲染零掉帧；
- **多样化可视化定制**：支持 3 种按键着色模式（Classic / Channel / Velocity）与 3 种音符标注模式（DoReMi / FixedDo / NoteName）。

### 🎛️ 16 通道 MIDI 矩阵与实时移调（16-Channel MIDI Matrix & Transposition）
- **16 通道独立矩阵**：每通道支持独立半音移调、八度偏移、力度覆盖、音色选择、音色库切换与按键跟随（`followKey`）；
- **全局调号控制**：支持 -7..+7 半音全局调号切换，配备 General MIDI (GM) 通道 10 打击乐直通保护。

### 🎙️ 演奏录制、回放与数据持久化（Recording, Playback & Persistence）
- **实时无锁采集**：音频线程无锁采集生成不可变 `RecordingTake` 数据结构；
- **多倍速回放控制**：支持 0.5x–2.0x 实时原子倍速平滑调节与 Back 从头回放；
- **原生演奏持久化**：支持 `.devpiano` 原生演奏文件格式（v2 JSON + Base64 编码 + `juce::TemporaryFile` 原子写入）；
- **标准 MIDI 文件支持**：支持导出标准 Type 1 MIDI 文件（960 PPQ），支持导入标准 `.mid` 文件并自动智能选轨与多控制量解析；
- **Performance Preset 预设系统**：预设 CRUD 编排、F1-F12 快捷键切换、录制中自动切调记录以及同名覆盖确认（`PresetConfirmDialog`）。

### 📦 离线高保真 WAV 导出（Offline WAV Export Pipeline）
- **多线程离线渲染管线**：`WavExportTask` 独立后台线程执行非实时渲染，统一由 `RenderPipeline` 处理时间线缩放、事件排序与尾部 panic 注入；
- **双引擎渲染支持**：无插件时自动由内置物理建模引擎渲染，有插件时独立创建离线 VST3 实例渲染；
- **现代化暗黑进度弹窗**：支持实时进度展示、随时取消并自动清理残留文件。

### 🎨 JIVE 声明式 UI 与设计系统（Declarative UI & Theming）
- **声明式 UI 架构**：全应用主界面、设置面板与弹窗全面统一至 JIVE 框架（`juce::ValueTree` 布局 + JSON 样式表 + Flex/Grid 自适应），消灭手工坐标排版；
- **现代化暗黑主题**：基于 `DevPianoLookAndFeel` 的旋钮化 ADSR/音量调节、3 列对称居中状态栏（实时 MIDI 活动灯、插件/预设名称、音频指标与调号）；
- **绿色单文件资产内嵌**：设计 Token（`design_tokens.json`）、样式表（`style_sheets.json`）与中文语言包（`zh_CN.loc`）由 CMake 编译期二进制静态内嵌，单文件绿色分发零外部文件依赖。

### 🌐 运行时国际化（Runtime i18n）
- **中英文即时切换**：基于 JUCE `Translation` 与 `LocaleManager`，支持简体中文与英文运行时无缝即时切换。

---

## 模块分层与代码架构

```text
source/
├── Main.cpp / MainComponent.*     # 应用生命周期与主装配协调层
├── Audio/                         # 音频引擎、PianoSynthVoice 物理建模与 SineSynthVoice
├── Input/                         # 电脑键盘事件捕获与稳定键位 MIDI 映射
├── Midi/                          # 16 通道 MIDI 矩阵路由与实时移调映射
├── Plugin/                        # VST3 插件扫描、加载、生命周期与 Editor 托管
├── Recording/                     # 演奏录制、回放、MIDI 导入导出与公共离线渲染管线
├── Export/                        # WAV 离线导出后台任务与选项构建
├── Layout/                        # Performance Preset 预设数据模型与 CRUD 编排
├── Settings/                      # 设置模型、持久化存储、独立窗口与 JIVE 声明式设置面板
├── UI/                            # JIVE 布局模型、设计 Token、声明式弹窗体系与 Native 原生组件
├── Locale/                        # 语言管理器与编译期内嵌语言包
├── Diagnostics/                   # 结构化日志系统、MidiTrace 与调试输出
└── Core/                          # 核心数据结构与轻量强类型定义（AppState, KeyMapTypes）
```

---

## 开发工作流（WSL + Windows MSVC 混合环境）

开发环境推荐采用：**WSL 主工作树 + Windows 镜像树 + CMake + Ninja + Windows/MSVC 验证构建**。

### 常用开发命令（`./scripts/dev.sh`）

```bash
# 1. 环境自检
./scripts/dev.sh self-check

# 2. 代码格式化（基于 WebKit 规范）
./scripts/dev.sh format               # 一键格式化 source/ 下所有 .cpp/.h
./scripts/dev.sh format --check       # 检查格式合规（CI 模式）

# 3. 静态检查（clang-tidy）
./scripts/dev.sh tidy                 # 增量检查未提交的改动文件
./scripts/dev.sh tidy --all           # 全量静态检查（迭代边界门禁）

# 4. 刷新 WSL 编译数据库（供 clangd/LSP 使用）
./scripts/dev.sh wsl-build --configure-only

# 5. 运行全量单元测试（60 个测试套件，11989+ 断言）
./scripts/dev.sh test

# 6. Windows MSVC 验证构建（内置代码智能同步）
./scripts/dev.sh win-build            # Debug 验证构建（日常开发）
./scripts/dev.sh win-build --release  # Release 构建（发布准备）

# 7. 编译耗时性能剖析（-ftime-trace，分析最耗时文件/头文件/模板）
./scripts/dev.sh time-trace           # 增量分析最新构建热点
./scripts/dev.sh time-trace --clean   # 清理后全量剖析并导出 Perfetto 火焰图

# 8. 正式发布打包（生成 Windows x64 zip 与 SHA256 校验和）
./scripts/dev.sh package              # 自动提取版本并打包
./scripts/dev.sh package --version 1.0.0
```

### 工程质量三闸门

每次关键修改提交前，必须满足以下三道质量门禁：
1. **代码格式**：`./scripts/dev.sh format --check` 零违规；
2. **单元测试**：`./scripts/dev.sh test` 全量测试套件 100% 通过；
3. **构建验证**：WSL 配置 `wsl-build --configure-only` + Windows 镜像 `./scripts/dev.sh win-build` 编译成功。

---

## 构建产物路径

- **WSL Debug**：`build-wsl-clang/devpiano_artefacts/Debug/DevPiano`
- **WSL Release**：`build-wsl-clang-release/devpiano_artefacts/Release/DevPiano`
- **Windows Debug**：`<WIN_MIRROR_DIR>\build-win-msvc\devpiano_artefacts\Debug\DevPiano.exe`
- **Windows Release**：`<WIN_MIRROR_DIR>\build-win-msvc-release\devpiano_artefacts\Release\DevPiano.exe`
- **发布分发包**：`<WIN_MIRROR_DIR>\dist\v<VERSION>\DevPiano-v<VERSION>-win-x64.zip`

---

## 外部子模块（`submodules/`）

项目依赖的第三方框架均以 Git Submodule 形式引入，**禁止直接修改子模块中的任何代码**：
- `submodules/JUCE/`：JUCE 跨平台音频/GUI 框架（AGPLv3 / 商业许可）；
- `submodules/JIVE/`：JIVE 声明式 UI 框架（MIT）；
- `submodules/melatonin_inspector/`：运行时 Component 检查器（MIT）。

---

## 文档中心与推荐阅读

完整文档索引见：[`docs/README.md`](docs/README.md)。

- **新开发者上手**：
  - 快速环境恢复：[`docs/guides/quickstart.md`](docs/guides/quickstart.md)
  - 混合工作流详解：[`docs/guides/wsl-windows-msvc-workflow.md`](docs/guides/wsl-windows-msvc-workflow.md)
  - 项目定位与非目标：[`docs/reference/project-scope.md`](docs/reference/project-scope.md)
  - 系统架构与模块设计：[`docs/reference/architecture.md`](docs/reference/architecture.md)
- **核心特性参考**：
  - 物理建模钢琴音源：[`docs/reference/features/builtin-piano-synthesis.md`](docs/reference/features/builtin-piano-synthesis.md)
  - VST3 插件宿主：[`docs/reference/features/plugin-hosting.md`](docs/reference/features/plugin-hosting.md)
  - 键盘映射与 88 键虚拟键盘：[`docs/reference/features/keyboard-mapping.md`](docs/reference/features/keyboard-mapping.md)
  - 16 通道 MIDI 矩阵：[`docs/reference/features/midi-channel-matrix.md`](docs/reference/features/midi-channel-matrix.md)
  - 录制、回放与导出：[`docs/reference/features/recording-playback.md`](docs/reference/features/recording-playback.md)
  - JIVE 声明式 UI 与设计 Token：[`docs/reference/features/declarative-ui-and-theming.md`](docs/reference/features/declarative-ui-and-theming.md)
- **质量与版本**：
  - 路线图与阶段状态：[`docs/roadmap/roadmap.md`](docs/roadmap/roadmap.md)
  - 阶段验收标准：[`docs/reference/acceptance.md`](docs/reference/acceptance.md)
  - 正式发布打包指南：[`docs/guides/release-workflow.md`](docs/guides/release-workflow.md)
  - 已知问题与回归线索：[`docs/issues/known-issues.md`](docs/issues/known-issues.md)

---

## 开源协议

本项目采用 **AGPLv3** 开源协议，第三方依赖与致谢详见 [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md)。
