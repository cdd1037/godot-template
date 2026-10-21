# Godot 4.7.2 .NET 桌面导出模板精简研究

记录日期：2026-10-21。研究对象是本仓库的通用 2D、C#、Release 桌面模板，不是对所有 2D 项目的通用删减建议。

## 1. 结论先行

- 当前采用 **Compatibility / 原生 OpenGL、Release、线程支持、速度优化、完整 LTO**。Windows x64 使用 MSVC，Linux x64 使用固定的官方构建配方，macOS 仅 Apple Silicon，使用原生 Xcode。
- 功能边界比“关闭越多越好”重要。共享 3D/XR API 继续保留，但不需要的实现模块关闭，以减少与官方 GodotSharp 的接口差异。
- 已采用 GDScript、VisualShader、regex、摄像头、Theora、BMP/TGA/HDR/TinyEXR 等删减。Graphite 已恢复；纯 3D 末端节点删减与模块白名单试验未采用。
- RELR 在本地 Linux 产物上实测节省 **2.812431 MiB**，但会引入加载器兼容要求，当前发布版不启用。
- Windows 从本项目的 MinGW 配方切换为 MSVC 后，主模板由 **65.164551 MiB 降至 50.627930 MiB**。这是具体产物的观察，不是“MSVC 对所有项目必然小 22%”的保证。
- 当前统一下载：[4.7.2-slim.2](https://github.com/cdd1037/godot-template/releases/tag/4.7.2-slim.2)。它复用已验证产物，没有因合并 Release 而重编译。

## 2. 范围、证据与比较口径

源代码固定为 [Godot 4.7.2-stable / ed1daf0bf](https://github.com/godotengine/godot/tree/ed1daf0bf001b61586d9930840f2f1394092c079)。当前配置见 [custom.py](../../artifacts/desktop-release-plan/custom.py)，平台脚本见 [构建目录](../../artifacts/desktop-release-plan)。

本文区分三种证据：

1. **实测产物**：文件长度、哈希、ELF/PE/Mach-O 节区与依赖；不等于运行或性能验证。
2. **源码/配置判断**：某开关移除什么 API、实现或依赖；不声称已经逐项功能测试。
3. **待验证方向**：只提出假设，未测量收益，也未纳入当前 Release。

所有 MiB 均为字节数除以 1,048,576。除明确标记 ZIP 外，体积均指单个剥离符号后的可执行文件，不含游戏资源、托管程序集、.NET 运行时、调试资料或控制台包装器。压缩包与裸二进制不能混比；文件体积与运行内存也不能混比。

本次整理重新读取了保留的本地实验产物，核对长度与 SHA256；可机器读取的数据见 [measurements.json](measurements.json)。部分早期实验没有公开构建日志或可下载的实验二进制，因此哈希仅用于标识证据，不能冒充完整的公开可复现发布。公开 Actions/Release 证据见文末。没有为写本文重新编译或运行模板。

## 3. 当前发布产物

| 产物 | 字节 | MiB | 说明 |
|---|---:|---:|---|
| Linux x64 Release | 50,897,816 | 48.539940 | ELF，官方配方 SDK，未启用 RELR |
| Windows x64 MSVC Release | 53,087,232 | 50.627930 | PE 主程序 |
| Windows console 包装器 | 292,864 | 0.279297 | 独立小型启动器，不是另一份引擎 |
| macOS ARM64 ZIP | 16,404,787 | 15.644824 | 发布用压缩包 |
| ZIP 内 macOS ARM64 可执行文件 | 47,477,352 | 45.277931 | 单架构 Mach-O，不是 Universal |

macOS 的“15.64 MiB”主要是 ZIP 打包后的口径，不是证明引擎内置了特殊可执行文件压缩。比较平台原始引擎体积，应使用 **45.28 / 48.54 / 50.63 MiB**，同时承认 CPU 架构、ABI、系统库和编译工具链不同。

Windows GUI 程序的终端附着与输出行为和 Unix 不同，因此额外提供 console 包装器；Linux/macOS 可从终端直接启动对应可执行文件，不必机械复制这一包装方式。使用 Windows 自定义模板时保留两个 EXE，同目录放置，选择不带 `.console` 的主模板。

## 4. 本地 Linux 递进实验

这一组使用同一 Godot 源码、本地 GCC 14.2、Linux x64、`template_release`、`optimize=speed`、`lto=full`、线程支持与 6 个构建作业。它不是当前官方配方 SDK 的发布产物，不能把两者的差值当作单一模块收益。

### 4.1 已采用的递进删减

| 阶段 | 相对上一阶段的变化 | 字节 | MiB | 本阶段节省字节 |
|---|---|---:|---:|---:|
| initial | 已有基础精简配置，不是完整官方模板 | 60,077,624 | 57.294487 | — |
| trim3 | 关闭 VisualShader、regex、camera | 58,209,688 | 55.513084 | 1,867,936 |
| trim4 | 再关闭 GDScript | 56,579,384 | 53.958305 | 1,630,304 |
| trim5 | 再关闭 Theora | 56,390,968 | 53.778618 | 188,416 |
| trim6 | 再关闭 BMP、TGA、HDR、TinyEXR | 56,153,400 | 53.552055 | 237,568 |

trim3 是三个开关一起变动，不应把 1,867,936 字节分别归给每个模块。trim6 是四个图片模块的组合结果，同样没有四份独立的收益结论。initial 到 trim6 累计减少 3,924,224 字节，约 3.742432 MiB。

### 4.2 从 trim6 分叉的实验，不能继续累加

| 实验 | 比较基线 | 字节 | MiB | 节省字节 | 决策 |
|---|---|---:|---:|---:|---|
| 关闭 Graphite | trim6 | 56,022,264 | 53.426994 | 131,136 | 恢复，保留字体能力 |
| 删除 8 个纯 3D 末端类 | trim6，Graphite 已恢复 | 55,715,128 | 53.134087 | 438,272 | 撤销，收益有限 |
| 开启 RELR | trim6 | 53,204,352 | 50.739624 | 2,949,048 | 暂缓，兼容性优先 |
| 等效 23 模块白名单 | trim6 | 56,153,400 | 53.552055 | 0 | 语法本身不减体积 |
| 白名单中再删 4 个模块 | 等效白名单 | 55,849,912 | 53.262627 | 303,488 | 不采用 |

上述行是不同分支，不能把节省量加总成一个已经存在的版本。当前 Release 的功能配置仍以 trim6 为基础。

## 5. 已采用配置：收益之外的代价

| 方向 / 主要开关 | 本项目取舍 | 能力影响与边界 |
|---|---|---|
| `module_mono_enabled=True` | 保留 | .NET 绑定与宿主支持；不意味着模板中打包 .NET 运行时 |
| `opengl3=True`；Vulkan/D3D12/Metal/ANGLE 关闭 | 采用 | 本次目标桌面平台的 Compatibility 使用原生 OpenGL；不能再切换到需要这些后端的 Forward+/Mobile。不能把接口类残留误判为后端仍可用 |
| AccessKit 关闭 | 采用 | 放弃其平台辅助技术集成；对屏幕阅读器等可访问性需求须重新评估，不等于删除 UI |
| VisualShader 关闭 | 采用 | 不再支持 VisualShader 资源/图形节点生成路径；普通文本 Shader 不因此整体消失 |
| regex 关闭 | 采用 | Godot `RegEx`/`RegExMatch` 不可依赖；本项目可在 C# 使用 .NET 正则，但不会自动转换已有 Godot 资源或代码 |
| camera 模块关闭 | 采用 | 去除该模块的摄像头采集实现；不等于删除 Camera2D/Camera3D 场景相机 |
| GDScript 关闭 | 采用 | 不能执行 `.gd` 脚本，依赖 GDScript 的运行时插件/资源也需排查。编辑器仍可使用官方编辑器，但导出内容必须符合模板能力 |
| Theora 关闭 | 采用 | 去除内置 Theora 视频播放路径，不是关闭 Ogg/Vorbis 音频，也不能泛化成所有第三方视频插件均被移除 |
| BMP/TGA/HDR/TinyEXR 关闭 | 采用 | 不再依赖对应运行时图片读写能力。编辑器预先导入的纹理与运行时直接加载原文件不同，须看实际导出格式 |
| ENet/WebRTC/WebSocket/UPnP/Multiplayer/JSONRPC 模块关闭 | 采用 | 不可再依赖相应 Godot 高层通信能力；.NET 自行实现是应用架构决定，不是模块关闭后自动获得的替代品 |
| 2D 物理、2D 导航、常规 UI/文本、常用音频与图片 | 保留 | 面向较通用 2D 的基础能力，不按某一个样例场景进一步裁剪 |

这些方向并非全部有独立对照构建。表 4 中没有单项数字的配置，不给出未经测量的节省值。

PNG/JPG/WebP/SVG 与纹理解码能力不能只按“是否直接打开这个扩展名”决定去留：WebP 可能参与导入纹理的运行时解码；SVG 能力还可能与字体中的 SVG 图形有关；ASTC/BC/ETC 解码及 Basis Universal 转码可能服务于 GPU 格式适配。保留它们是当前功能边界，不是证明每个项目都需要。

## 6. 为什么没有直接关闭整个 3D / XR

目标虽然是 2D，但本项目要求尽量与官方 GodotSharp 绑定兼容。`disable_3d`、`disable_xr`、`disable_navigation_3d`、`disable_physics_3d` 这类核心开关与只关闭实现模块不是同一件事。

源码和早期验证表明，核心裁剪会影响共享绑定接口，例如 Viewport 的 3D 世界相关接口、XR 属性及 World3D 相关服务接口。官方托管绑定可能仍期望这些接口存在。因此当前保留这些核心开关为 `False`，关闭不需要的实现：3D navigation、Godot Physics 3D、Jolt、OpenXR、mobile VR、WebXR，以及 CSG/GridMap、glTF/FBX、lightmapper、raycast 等独立模块。

这并不承诺完整 3D 可用。类/API 存在与后端实现完整是两件事；必要时可能使用 dummy 服务。本方案只是避免为了纯 2D 而无差别切断共享 API。

8 个末端类实验通过构建配置去掉 Sprite3D、AnimatedSprite3D、Label3D、GPUParticles3D、CPUParticles3D、Decal、ReflectionProbe、FogVolume。只节省 438,272 字节（约 0.7805%），增加 API 差异和维护成本，最终撤销。早期有限 C# / headless 冒烟通过，不构成所有游戏或插件兼容保证。

GDExtension 也没有作为普通模块一键关闭：本次源码中未找到可等价使用的标准模块关闭选项，且 Mono 的实例绑定与相关基础设施存在耦合。没有为了体积进行侵入式源码手术；当前保留它，不把“没找到开关”夸大成技术上永远不可能移除。

## 7. Graphite：小收益不抵能力损失

Graphite 是字体智能排版相关技术，与图形渲染器、GPU shader 无关。本次仅改变 `graphite=False`，生成的 Godot 模块清单不变，但底层 Graphite 库及相应 HarfBuzz 集成不再参与构建。

实测节省 131,136 字节，约 0.125061 MiB / 0.2335%。高级文本、HarfBuzz 和 ICU 并未全部移除。考虑通用文字与字体能力，当前恢复 `graphite=True`。未做 Graphite 字体布局回归或性能测试，不声称删掉后所有语言均不受影响。

## 8. RELR：不是删功能，而是重定位表编码

trim6 的 `.rela.dyn` 为 2,970,552 字节，其中大量 `R_X86_64_RELATIVE` 记录可用位图形式的 RELR 表达。链接选项 `-Wl,-z,pack-relative-relocs` 的实测结果：

- 最终文件减少 2,949,048 字节（2.812431 MiB / 5.2518%）。
- `.relr.dyn` 为 18,576 字节，剩余 `.rela.dyn` 为 480 字节。
- `.text` 大小仍为 42,401,326 字节；展开信息节大小没有变化。
- 估算的重定位有效载荷节省与全文件差值略有不同，原因是布局、对齐、元数据，不应要求逐字节相等。

该本地 RELR 产物做过版本、headless 与有限 C# 冒烟。没有跨发行版、完整图形或性能测试，也没有据此声称游戏帧率提高。

兼容性是未采用的原因：glibc 2.36 加入 DT_RELR 支持，GNU 链接器可加入 `GLIBC_ABI_DT_RELR` 依赖。本地构建本来已要求最高数值版本 `GLIBC_2.38`，所以此次没有提高它的数值版本下限；但当前发布 Linux 使用 glibc 2.28 SDK，不能照搬这个结论。Ubuntu 首个带 glibc 2.36 的正式版本是 22.10，首个满足这一条件的 LTS 是 24.04；发行版版本也不能代替具体二进制依赖检查。

RELR 是 ELF 链接/加载机制，不是 Windows PE 或 macOS Mach-O 的通用减体积选项。当前 Release 仍不启用，未来必须先明确最低支持系统。

## 9. 白名单和四模块组合试验

Godot 支持 `modules_enabled_by_default=False`，然后显式开启需要的模块。白名单是控制默认启用集合的方式，不是自动消除所有未使用 API 的链接魔法。

等效配置显式保留 23 个模块：

`astcenc, basis_universal, bcdec, dds, etcpak, freetype, godot_physics_2d, interactive_music, jpg, ktx, mbedtls, meshoptimizer, mono, mp3, msdfgen, navigation_2d, noise, ogg, svg, text_server_adv, vorbis, webp, zip`

生成的模块清单与 trim6 一致，文件长度完全相同。逐字节比较仅 21 处不同：ELF OSABI 字节和 20 字节 BuildID，其余相同。因此应说“功能集合与体积等效”，不能说 SHA256 相同或完全可重现。

再同时删除以下 4 个模块：

| 模块 | 代价 |
|---|---|
| meshoptimizer | 去除相关网格优化/简化实现，影响对应 SurfaceTool 等使用路径 |
| dds | 去除直接 DDS 加载，以及该模块提供的 DDS 保存钩子 |
| ktx | 去除直接 KTX 加载；不代表 Basis Universal 转码整体关闭 |
| interactive_music | 去除 AudioStreamPlaylist、AudioStreamInteractive、AudioStreamSynchronized 及播放实现 |

最终 19 模块版本只小 303,488 字节（296.375 KiB / 0.5405%）。这是组合收益，不是四个模块各自贡献的总表。中途被中断的 DDS/KTX 构建不作为有效测量点。完整候选构建成功且做了静态清单核对，没有运行或性能测试。

最终不采用白名单版，当前仍保留这四项能力。依赖关系也必须显式审查，例如 Vorbis 依赖 Ogg、KTX 依赖 Basis、MSDFgen 依赖 Freetype；不要假设构建系统会自动补齐所有未启用依赖，应检查实际生成的模块清单。

## 10. 工具链与构建选项

### 10.1 不同工具链的产物不可视为纯模块对照

| 产物 | 字节 | MiB | 比较限制 |
|---|---:|---:|---|
| 本地 Linux trim6，GCC 14.2 | 56,153,400 | 53.552055 | 本地工具链，不是发行 SDK |
| 发布 Linux，官方配方 SDK | 50,897,816 | 48.539940 | GCC 13.2 / glibc 2.28，不能把差值当成新裁剪收益 |
| 本地 Windows MinGW GCC 14.2 | 66,711,040 | 63.620605 | 与发布 MinGW 的版本/平台不同 |
| 发布 Windows MinGW 配方 | 68,329,984 | 65.164551 | 历史 slim.1 |
| 发布 Windows MSVC | 53,087,232 | 50.627930 | 当前 slim.2 使用 |

发布 Windows 两版主 EXE 相差 15,242,752 字节（14.536621 MiB / 22.3076%）。功能配置一致，但编译器、链接器、运行库和宿主构建环境一起改变，不能将差异机械归因为单个编译开关。另一个早期旧二进制的模块集也不同，不能用它证明更激进的编译器收益。

“官方工具链”在本文需分平台说明：

- 固定 [build-containers 4.7 提交](https://github.com/godotengine/build-containers/tree/3f3cc50c3f91c2be66e37aece9d9a57284e39db7) 与 [godot-build-scripts 4.7 提交](https://github.com/godotengine/godot-build-scripts/tree/63625f75c0f869dea4a01811522e10fefcd0f322)，不是跟随不断变化的 main。
- Linux 用官方 Dockerfile 配方及 `godot-2023.08.x-4` SDK（GCC 13.2 / glibc 2.28 / binutils 2.40）。配方固定不等于镜像所有包都不可变，Fedora 标签和包源仍可能变化，不能声称与官方发布逐字节一致。
- 官方 4.7 Windows 发布脚本使用 MinGW，不是 MSVC。本仓库为实测体积改用原生 VS 2022，实际记录 toolset 14.44.35207、Windows SDK 10.0.26100.0。
- 官方 macOS 配方是 osxcross 路线；本仓库明确改用 GitHub macOS ARM64 runner + Xcode 26.1.1（17B100）、SDK 26.1，不声称与官方 osxcross 二进制相同。

### 10.2 production、优化、线程与符号

- `production=yes` 是一组构建默认值的集合，不是独立的“最小体积模式”。平台和显式参数仍可能覆盖它。
- 当前显式 `optimize=speed` 与 `lto=full`，避免依赖 `lto=auto` 的平台差异。MSVC 对应 `/O2 /GL /LTCG`，静态 C++ 运行库 `/MT`。
- `threads=True` 表示引擎线程支持；`-jN` 表示并行编译作业。两者不是同一设置。提高并行作业主要影响构建时间与内存压力，不是减小成品体积的开关。
- `size` / `size_extra` 尚未作为当前方案采用。体积优化可能改变代码生成、内联等策略，必须结合实际游戏性能测试；不能只凭名字保证“更小且一样快”。
- Linux/macOS 构建可保留调试资料后另行 strip；MSVC 使用 `debug_symbols=no`、`/DEBUG:NONE` 和独立 `/MAP`，不用 GNU strip 处理 MSVC EXE。
- 无 PDB 不等于 PE 中绝无 debug-directory 元数据；MSVC 的 CoffGrp 元数据不等于携带完整调试符号。
- 当前 Windows 静态导入检查没有发现动态 VCRUNTIME/MSVCP 或 MinGW 运行库依赖，不等于整个程序完全无系统 DLL 依赖。

保留符号和 map 是为了后续定位，发布裸模板不需要把这些大文件一起打包。Actions 证据有保留期限（本次配置 30 天）；长期可追溯性应优先保存小型配置、工具链清单、哈希和摘要，不承诺临时日志永久可下载。

## 11. 从二进制定位大头：哪些推断可靠

trim6 的静态节区分析：

| 节区 | 字节 | 用途/解释 |
|---|---:|---|
| `.text` | 42,401,326 | 机器代码，约占文件 75.51% |
| `.rodata` | 4,207,840 | 只读数据 |
| `.eh_frame` + `.eh_frame_hdr` | 5,332,460 | 展开相关元数据，不应未经验证删除 |
| `.rela.dyn` | 2,970,552 | 重定位表，是 RELR 试验的直接依据 |
| `.data.rel.ro` | 1,154,200 | 重定位后的只读数据 |
| `.bss` | 1,907,816 | NOBITS，属于零初始化内存，不是等量磁盘占用 |

后来保留了 RELR 构建的去符号前 ELF 和 map，发现较大的文件内符号包括 RenderingServer 的绑定注册（148,534 字节）、全局常量注册（145,718）、默认主题（133,963）、压缩证书数据（128,495）、Brotli 字典（122,784）、GLES3 场景渲染函数（110,511）、RenderingDevice 绑定注册（104,029）。这些是特定构建中的符号大小，不是删除整个子系统后可保证回收的体积。

重要限制：

- LTO 会内联、合并和重排，静态库 `.a` / `.o` 中可能是 IR；库文件大小不等于最终可执行代码贡献。
- 大符号、绑定注册和共享渲染接口往往跨 2D/3D，名字含 3D 或 RenderingDevice 不能证明可安全删除。
- `nm` 中 B/b 常是 BSS，不应排在磁盘减重收益榜上。
- 已经 strip 的文件不一定还能再明显减小；去掉展开元数据、ABI 或共享 API 可能破坏诊断、运行库互操作和兼容性。

## 12. 其他可调方向：目前只研究，未采用

| 方向 | 为什么暂不推进 |
|---|---|
| Brotli / WOFF2 | 可能影响字体压缩与解码路径，必须先确认字体格式需求；没有本项目独立收益实测 |
| `deprecated=no` | 可能移除旧兼容 API/绑定，需审查 GodotSharp、插件及旧资源；不是无代价清理 |
| 类级 `build_profile` | 已见末端类收益有限，进一步裁剪共享类的兼容风险更高 |
| 动态链接系统库 / `builtin_*=no` | 可能只是把文件体积转移到外部依赖；应比较完整分发集合与最低系统要求 |
| 移除 Linux X11/Wayland、音频、字体或桌面集成 | 会缩小部署覆盖面，当前面向较通用桌面 2D，保留 |
| Linux speechd / Windows WinRT | 与 TTS 相关，不能因为 AccessKit 关闭就默认一起删除 |
| SCU、缓存、增加 `-j` | 主要是编译效率方向，不应当作已证明的运行性能或体积优化 |
| ICU 大数据裁剪 | 不能假设模板还带完整编辑器 ICU 数据；应先看实际链接数据，避免重复计算不存在的收益 |

后续实验原则：保持源提交、工具链和其他参数不变；每次明确对照基线；保留去符号前文件、map、最终文件、哈希与生成模块清单；把构建成功、静态检查、启动、功能和性能验证分别记录。除有明确兼容目标，不为小体积牺牲当前已决定保留的能力。

## 13. 公开证据与验证范围

- [统一 Release 4.7.2-slim.2](https://github.com/cdd1037/godot-template/releases/tag/4.7.2-slim.2)：四个模板文件及 SHA256SUMS。
- [三平台原始构建 39565398548](https://github.com/cdd1037/godot-template/actions/runs/39565398548)：Linux、macOS、历史 MinGW Windows。
- [MSVC 构建 39571907775](https://github.com/cdd1037/godot-template/actions/runs/39571907775)：当前 Windows 二进制来源。
- [Release 合并 39581568394](https://github.com/cdd1037/godot-template/actions/runs/39581568394)：复用产物、验证固定哈希、上传后下载回验，不是重新构建。
- [当前三平台 workflow](../../.github/workflows/desktop-releases.yml)、[工具链记录](../../artifacts/desktop-release-plan/toolchains.json)、[平台构建说明](../../artifacts/desktop-release-plan/README.md)。
- [GNU ld 手册](https://sourceware.org/binutils/docs/ld.html)：`pack-relative-relocs`。
- [glibc 2.36 发布说明](https://lists.gnu.org/archive/html/info-gnu/2022-08/msg00000.html)、[Ubuntu 22.10](https://documentation.ubuntu.com/release-notes/22.10/)、[Ubuntu 24.04](https://documentation.ubuntu.com/release-notes/24.04/)：RELR/加载器版本背景。

当前发布 Windows 只做构建、PE/依赖和哈希检查，没有运行游戏、Wine 或性能测试；三平台合并也没有增加运行测试。早期 Linux 的有限 headless/C# 冒烟结果，不应移植成“当前三个平台所有删减模块均测试通过”。macOS 调试资料生成中曾出现 LTO 临时对象找不到的警告，完整 dSYM 覆盖不能保证；这与最终模板哈希验证是两项不同结论。

本研究记录的是已经做过的实验与取舍，不承诺任何项目无需验证即可使用精简模板。
