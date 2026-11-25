# WageDrip / 窝囊费

工资计时器：iOS、iPadOS、macOS 多平台 SwiftUI App，带小组件、实时活动和 Mac 菜单栏。

## 工作约定

- **本项目不使用 superpowers 插件。** 不调用它的任何技能（brainstorming、writing-plans、executing-plans、subagent-driven-development 等），也不按它的流程或目录约定行事。（用户 2026-11-24 明确要求。）
- 用中文与用户沟通。
- 用户要求：在明确说开始之前不要动手执行；讨论阶段多提建议和问题。
- git 提交身份已在仓库内设为 AndyUneducated，不要改全局 git 配置。

## 文档

- 设计文档：`docs/specs/2026-11-24-wagedrip-design.md`
- 实施计划：`docs/plans/2026-11-24-wagedrip-v1.md`

## 常用命令

- 核心测试：`swift test --package-path Packages/WageDripCore`
- 生成工程：`DEVELOPMENT_TEAM=<团队 ID> /opt/homebrew/bin/xcodegen generate`（团队 ID 见 Xcode › Settings › Accounts；不写进仓库）
- 模拟器构建：`xcodebuild -project WageDrip.xcodeproj -scheme WageDrip -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath DerivedData build`
- 本机模拟器没有 iPhone 17 Pro Max，用 iPhone 17；iPad 用 iPad Pro 13-inch (M5)
- 真机日志可直接读取：`xcrun devicectl device copy from --domain-type appGroupDataContainer --domain-identifier group.com.andyuneducated.wagedrip ...`
