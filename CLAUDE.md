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
- 生成工程：`xcodegen generate`
