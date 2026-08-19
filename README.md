# 离线语音提醒（Reminder）

**完全离线**的语音定时提醒 App（Flutter，Android + iOS，中文 UI）。

- 🎙️ 语音录入 → 本地离线识别（sherpa-onnx，模型随 App 打包）→ 本地规则引擎解析时间 → 一键创建提醒
- 🔕 本地定时通知（Android AlarmManager 精确闹钟 / iOS UserNotifications）
- 📅 任务自动同步到系统日历（专属日历「离线语音提醒」，双向绑定）
- 📦 全部数据本地存储（Hive），支持 JSON 本地备份/恢复
- 🚫 **零网络**：不声明任何网络权限、无统计/广告/埋点 SDK、不采集上传任何数据

## 环境要求

- Flutter **stable ≥ 3.44.7**（`record` 7.x 要求；Dart ≥ 3.12）
- Android：JDK 17+、Android SDK（compileSdk 36）
- iOS：Xcode 14+、CocoaPods

## 快速开始

### 0. 一次性脚手架补全（仅首次需要）

仓库为纯代码交付，个别**二进制/生成文件**（Gradle wrapper jar、iOS Xcode 工程 `Runner.xcodeproj` 等）无法随代码入库。首次构建前在项目根目录执行一次（**不会覆盖已有文件**）：

```bash
flutter create --project-name reminder --org com.offlinereminder --platforms android,ios .
```

> 若提示 `android/gradle/wrapper/gradle-wrapper.jar` 缺失，同样由该命令补齐。

### 1. 下载离线语音模型（约 159 MB）

```bash
bash tool/download_model.sh          # macOS / Linux / Git Bash
# Windows PowerShell:
# powershell -ExecutionPolicy Bypass -File tool\download_model.ps1
```

脚本依次尝试 GitHub Release → HuggingFace → hf-mirror（国内镜像），下载
`sherpa-onnx-streaming-zipformer-zh-int8-2025-06-30`（普通话流式识别，int8 量化）
并解压到 `assets/models/`（已 gitignore）。随后随 App 打包，首次启动时拷贝到应用私有目录。

### 2. 获取依赖与构建

```bash
flutter pub get
flutter test        # NLP 解析器、重复规则、Hive 往返等单元测试
flutter analyze

# Android（split-per-abi 减小安装包体积）
flutter build apk --release --split-per-abi

# iOS
flutter build ios --release   # 或使用 Xcode 打开 ios/Runner.xcworkspace
```

### 3. 离线合规自检（发布前必做）

```bash
# 断言最终 APK 不包含 INTERNET 权限（硬性要求）
aapt dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# 输出中不得出现 android.permission.INTERNET
```

## 离线设计说明

- **INTERNET 权限已从三处清单移除**：`android/app/src/main|debug|profile/AndroidManifest.xml`
  （Flutter 模板默认在 debug/profile 清单声明 INTERNET，本项目已删除）。
  USB 调试热重载走 `adb reverse` 本地端口转发，无需网络权限；个别设备异常时可用
  `flutter run --release` 调试。
- 不集成任何第三方统计、广告、埋点 SDK；未声明通讯录/位置/短信等无关权限。
- 录音与缓存文件仅存于应用私有目录；备份文件由用户手动选择存放位置（SAF，免存储权限）。

## 已知系统限制

- **iOS 最多保留 64 条待处理通知**：循环任务预排未来数期，App 打开/恢复时自动补排。
- **Android 厂商后台查杀**：部分定制系统（MIUI/EMUI/ColorOS 等）可能拦截闹钟，
  App 内「设置 → 权限管理」提供电池优化白名单引导；行业通用限制，无法 100% 保证后台唤醒。
- Android 12+ 精确闹钟为可撤销权限；被系统回收后 App 自动降级为非精确提醒并提示用户。
- 日历同步为**单向**（App 为主数据源）：在系统日历中手动修改事件，App 内不会反向更新，
  避免循环冲突。

## 项目结构

```
lib/
  main.dart / app.dart              # 入口与根组件
  l10n/strings.dart                 # 全部中文文案
  core/
    db/                             # Hive 初始化、任务/设置仓储
    models/                         # Task / RepeatRule / ReminderSettings / Meta
    nlp/                            # 纯 Dart 中文时间解析引擎（无 Flutter 依赖）
    time/                           # 时区初始化、中文日期格式化
    utils/                          # JSON 备份、通知 ID 分配
  services/
    asr/                            # 模型管理、sherpa-onnx 引擎、录音编排
    notifications/                  # 通知初始化、调度器（预排/补排/上限分配）
    calendar/                       # 系统日历同步
    backup/                         # 备份导出/恢复
  features/
    home/ edit/ voice/ detail/ settings/
  state/                            # Provider 状态
test/
  nlp/                              # NLP 解析器单测（可独立 dart test）
tool/
  download_model.sh/.ps1            # 模型下载脚本
  gen_icons.ps1                     # 占位图标生成（正式发布前替换）
```

## 功能验收清单（真机自测）

安装 `app-arm64-v8a-release.apk`（或 Xcode 运行 iOS）后逐项验证：

1. **权限**：设置 → 权限管理，逐项开启麦克风 / 日历 / 通知 / 精确闹钟 / 电池白名单
2. **文本录入**：首页右上角键盘图标 → 输入「明天下午三点开会，提醒提前15分钟」
   → 解析预览正确（明天 15:00、提前 15 分钟）→ 保存
3. **语音录入**：首页麦克风 → 授权 → 说出「每周五晚上8点健身，持续1小时」
   → 实时识别文本 → 自动进入编辑页 → 保存
4. **三处一致**：保存后检查 ① 任务列表出现该任务 ② 通知按提前量定时触发
   （可新建 1 分钟后的任务验证）③ 系统日历「离线语音提醒」中出现对应事件与提醒
5. **日历双向**：编辑任务改时间 → 日历事件同步更新；删除任务勾选「同时删除日历事件」
   → 事件消失；关闭任务 → 弹出保留/删除日历事件选项
6. **循环任务**：新建「每月31号」任务 → 列表显示 8月31日，后续月份自动钳制（4月→30日）
7. **重启验证**：重启设备 → 等待下一个提醒时间，通知仍触发
8. **通知点击**：点击通知 → 直接打开对应任务详情页
9. **精确闹钟降级**：系统设置关闭本应用「闹钟与提醒」权限 → 权限中心显示未开启，
   提醒降级为非精确模式并提示
10. **备份**：设置 → 备份与恢复 → 导出 JSON → 重置应用 → 导入 JSON → 任务恢复、
    重复任务跳过
11. **离线合规**：系统流量统计中本应用数据用量为 0（无网络权限，物理上无法联网）

## 说明

- 图标为脚本生成的占位图（`tool/gen_icons.ps1`），正式发布前请替换
  `android/app/src/main/res/mipmap-*/ic_launcher.png` 与
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/icon-1024.png`。
- 发布签名：当前 release 使用 debug 签名便于侧载测试，正式发布请在
  `android/app/build.gradle.kts` 配置正式签名。
- 若开启 R8 压缩（`isMinifyEnabled = true`），务必保留 `proguard-rules.pro` 中
  device_calendar 的 keep 规则，否则日历功能运行时崩溃。
- 循环任务的通知采用「预排未来数期 + 打开/恢复 App 时补排」实现（Android 每任务
  10 期 / iOS 3 期，全局预算 Android 400 / iOS 60），等价于「触发后自动注册下一期」；
  不引入 workmanager 包：flutter_local_notifications 原生管理 AlarmManager，
  `inexactAllowWhileIdle` 即平台认可的降级路径。
