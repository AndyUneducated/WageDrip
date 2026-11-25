# 窝囊费 / WageDrip

一个"看着钱在涨"的工资计时器。填入薪酬和上下班时间，它会在 App、小组件、实时活动和 Mac 菜单栏里持续显示你今天、本月、今年已经赚到的钱。界面是一张不断打印的工资小票。

支持 iPhone、iPad 和 Mac（均为 27 系统），中文和英文。数据只保存在本机，没有账号和后端。

## 功能

- 年薪（底薪、奖金、股票可分别开关）、月薪、时薪三种输入方式。
- 按当月实际工作日分摊，月底累计恰好等于月薪。支持中国法定节假日与调休、美国联邦假日，以及手动标记某天上班或休息。
- 非固定工时模式：上下班之间拿到大部分日薪，其余在下班后到午夜之间计入，比例可调。
- 税后显示（自定扣除比例）、货币换算（每日自动汇率或手动汇率）。
- 等价换算（"折合多少杯咖啡"）和里程碑（"已赚回午饭"），可带通知。
- 桌面与锁屏小组件、实时活动与灵动岛、Mac 菜单栏。

## 运行

需要 Xcode 27 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。工程文件由 `project.yml` 生成，不入库。

```bash
DEVELOPMENT_TEAM=<你的团队 ID> xcodegen generate
```

```bash
open WageDrip.xcodeproj
```

团队 ID 在 Xcode › Settings › Accounts 里查看。首次在某个团队下构建时，需要在 Xcode 的 Signing & Capabilities 里为 `WageDrip` 和 `WageDripWidgets` 两个目标各登记一次 App Group `group.com.andyuneducated.wagedrip`，命令行无法完成这一步。

计算核心是独立的 Swift 包，可以单独测试：

```bash
swift test --package-path Packages/WageDripCore
```

## 结构

| 目录 | 内容 |
|---|---|
| `Packages/WageDripCore` | 全部计算逻辑与数据模型，纯 Swift，带单元测试 |
| `WageDrip` | App：小票界面、引导、设置、实时活动控制、通知 |
| `WageDripWidgets` | 小组件与实时活动界面 |
| `Shared` | App 与扩展共用的代码（共享存储、主题、诊断日志） |
| `docs/specs` | 设计文档，含真机实验结果 |
| `docs/plans` | 实施计划 |
| `tools/make-icon.swift` | 生成 App 图标的绘图脚本 |

## 已知限制

- **实时活动的金额不是实时的。** 没有推送服务时，它只在 App 有机会运行时刷新（实测约每 7 到 9 分钟一次），卡片上的"截至"时间表示数字的新旧。要每分钟准确的金额请用小组件。
- **每日自动出现需要偶尔打开 App。** 实时活动只能在前台启动，所以每次打开 App 会预约之后 2 个工作日；连续超过 2 个工作日不打开，自动出现会中断。
- **免费开发者账号**：装到真机的 App 每 7 天过期，每台设备最多同时装 3 个；不能用 iCloud，三台设备的设置不同步；不能用推送。
- "今年已赚"按当前薪酬回推，不记录年内调薪。不支持跨午夜的夜班。

## 诊断

设置里连点"版本"一行五次会出现"诊断"入口，记录小组件每次重载和实时活动每次启动、更新、结束的时间。

## 数据来源

- 中国节假日：[NateScarlet/holiday-cn](https://github.com/NateScarlet/holiday-cn)（来自国务院公告）。
- 汇率：[Frankfurter](https://frankfurter.dev)（欧洲央行每日参考汇率）。
