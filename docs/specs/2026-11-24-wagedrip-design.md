# WageDrip Design Spec

Date: 2026-11-24
Status: Pending review

## 1. Intent

WageDrip (Chinese name: 窝囊费, roughly "the pittance you put up with") is a salary ticker that lets you watch the money go up. The owner enters their pay and working hours, and the app continuously shows how much has been earned today, this month and this year on the Lock Screen, the Home Screen, the menu bar and inside the app. The tone is self-deprecating but polished: the name is a joke at the user's own expense, and the interface is a receipt that never stops printing.

For now it is for personal use only; the future goal is to ship on the App Store.

## 2. Goals, non-goals, anti-goals

### Goals

- iPhone first, with iPad and Mac covered by the same codebase.
- Target only the current latest systems (iOS / iPadOS / macOS 27, Xcode 27.2), with no backward-compatibility work at all.
- Always-on display of the earned amount on the Lock Screen.
- Support three ways of entering pay: annual salary, monthly salary, hourly wage.
- Support two ways of distributing pay within a day: fixed hours and "flexible hours".
- Support currency conversion, equivalents and milestones.
- Chinese (Simplified) and English.
- No account, no backend; data is stored on the device only.

### Non-goals (not in the first version)

- Live stock prices, stock vesting schedules.
- Exact income tax and social insurance calculation.
- Overtime multipliers, weekend overtime.
- Slacking-off timer, privacy masking, automatic start/stop by location or Focus mode.
- iCloud sync, push server.
- Apple Watch.
- In-year raise history ("earned this year" is back-calculated from the current pay).

### Anti-goals (it counts as a failure if it turns out like this)

- Amounts are computed wrong, or the month-end total does not equal the monthly salary.
- The Lock Screen shows a clearly stale number without knowing it.
- The interface looks like a generic bookkeeping app and loses the distinctiveness of the receipt.
- The user has to sign up or be online to use it.

## 3. Constraints

### Platform limits (researched, 2026-11)

- In Apple's ActivityKit and WidgetKit release notes, the latest entry is from June 2025; there is no API that lets a number in a Live Activity tick on its own or that pre-schedules future content.
- The only things in a Live Activity that the system can drive second by second are timer text (`Text(timerInterval:)`) and the timer progress bar.
- A Live Activity is active for at most 8 hours, and after it ends it stays on the Lock Screen for at most 4 more hours.
- Content updates for a Live Activity can only come from the app itself (in the foreground or when it gets a chance to run in the background) or from push. An Apple engineer stated clearly on the developer forums that a push every 3 seconds would exhaust the budget quickly.
- Widgets (WidgetKit) support submitting a timestamped timeline in advance; the system switches entries on time without the app running.
- Since June 2025, Live Activities on iPhone automatically appear in the Mac menu bar; and `request(...start:)` was added for starting a Live Activity at a scheduled time.

### Account limits

The owner has no paid Apple Developer account, so the first version is signed with a free personal team:

- An app installed on a real device expires every 7 days and has to be reinstalled.
- iCloud / CloudKit cannot be used: each of the three devices keeps its own settings, with no sync.
- Push cannot be used: the Live Activity amount cannot be reliably updated every minute.

### Other

- The git identity is set to `AndyUneducated <AndyUneducated@users.noreply.github.com>` in this repository only; the global configuration is not changed.
- `gh` is not installed on this machine, so the GitHub remote repository is not created for now.

## 4. Options compared: always-on Lock Screen display

| Option | Approach | Pros | Cost |
|---|---|---|---|
| A: widgets only | Lock Screen and Home Screen widgets, with a timeline pre-scheduled per minute | No server, always there, no duration limit | No "music player style" large card and no Dynamic Island |
| B: widgets + best-effort Live Activity | Everything in A, plus a Live Activity: the countdown is advanced second by second by the system, and the amount is refreshed whenever the app gets a chance to run | No server, both forms available | The amount on the Live Activity may lag |
| C: go straight to push | Everything in B, plus a push service so the Live Activity amount updates every minute | The Live Activity amount is reliable | Requires a paid account and a backend, which conflicts with the "no backend" goal |

**Chosen: B.** C is left until before the App Store release. The owner has confirmed: per-minute updates are acceptable, a countdown is wanted (fixed hours mode only), and no progress bar.

How lag in the Live Activity amount is handled: the Live Activity also shows an "as of HH:mm" timestamp; if it has not been updated for longer than a set duration, it enters the stale style via `staleDate` (the amount fades).

## 5. Tech stack and project structure

The following are the designer's decisions; the owner has not confirmed them item by item but has approved the overall direction.

- **SwiftUI multiplatform app**: one app target covers iOS, iPadOS and macOS (native Mac, not Catalyst).
- **WidgetKit extension**: hosts the widgets and the Live Activity UI.
- **Local Swift package `WageDripCore`**: all calculation and data models, pure Swift, no dependency on UI frameworks, unit-tested with Swift Testing. Both the app and the extension depend on it.
- **Amounts always use `Decimal`**, never floating point.
- **Persistence**: one `Codable` settings struct, stored as JSON in the App Group's `UserDefaults`, shared by the app and the extension. SwiftData is not used.
- **Localization**: String Catalog, `zh-Hans` and `en`, following the system language.
- **Bundle ID**: `com.andyuneducated.wagedrip`; the extension uses a child identifier of it.
- **Minimum system version**: iOS / iPadOS / macOS 27.

```
WageDrip/
  WageDrip.xcodeproj
  WageDrip/            App (UI, settings, menu bar, Live Activity control)
  WageDripWidgets/     Widgets and Live Activity UI
  Packages/WageDripCore/
    Sources/WageDripCore/   Models, calculation engine, calendar, exchange rates, formatting
    Tests/WageDripCoreTests/
  docs/
```

## 6. Calculation rules

This is the core of the whole app. All of it lives in `WageDripCore` and must be covered by tests.

### 6.1 Pay input

Three methods; pick one:

- **Annual salary**: base salary is required; cash bonus and stock (or options) each have a toggle and an annualized total. Monthly salary M = sum of the enabled items ÷ 12. Bonus and stock accrue at a constant rate across the whole year, just like base salary.
- **Monthly salary**: enter M directly.
- **Hourly wage**: enter the amount per hour, H.

In addition:

- **Pay currency**: the currency the amounts are entered in.
- **Deduction rate r**: 0% to 100%, set by the user. Four one-tap reference values are provided: China tier-1 cities 22%, China other 18%, US tier-1 cities 32%, US other 25%. The UI labels them "rough reference".
- **Pre-tax / after-tax display toggle**: after-tax amount = pre-tax × (1 − r), applied to every displayed amount.

### 6.2 Workdays

A given day is a workday if and only if:

1. When the user has manually marked that day, the mark wins (working / off);
2. Otherwise, if the holiday calendar marks it as a holiday, it is off; if it marks it as a make-up workday, it is working;
3. Otherwise, Monday to Friday are working and Saturday and Sunday are off.

The holiday calendar is one of three choices by region: China, United States, none.

### 6.3 Daily pay D

- **Annual / monthly salary method**: D = M ÷ number of workdays in the current month. As a result the month-end total equals exactly M. Nothing accrues on holidays and weekends.
- **Hourly wage method**: D = H × scheduled daily hours (end of work − start of work, with the lunch break counted as paid).

Basis: China's statutory conversion is 21.75 days (Ministry of Human Resources and Social Security notice, 2025), and the US convention is 2080 hours / 260 days. The owner chose "spread over the actual workdays of the current month" to guarantee that the month-end number equals the monthly salary.

### 6.4 Intraday distribution f(t)

f(t) is the fraction of D already earned at time t of the day, ranging from 0 to 1.

**Fixed hours (default)**: 0 before the start of work; linear from 0 to 1 between the start and the end of work; 1 after the end of work.

**Flexible hours** (can only be enabled with the annual / monthly salary method; not offered with the hourly wage method):

- 0:00 to the start of work: weight 0.
- Start of work to end of work: weight 80%, linear within the segment.
- End of work to 24:00: weight 20%, linear within the segment.

The two weights are adjustable and must add up to 100%. In this mode the "Until off work" countdown is not shown.

On non-workdays f is always 0, and the UI shows "Day off today".

### 6.5 The three running totals

- **Today** = D × f(t).
- **This month** = number of fully elapsed workdays this month × D + today.
- **This year** = sum of the amounts due for each fully elapsed month this year + this month.

**Start date** (optional): days before the start date do not count. Amount due for the month of the start date = that month's D × number of workdays from the start date onward (D is still computed from the full month's workday count). When the start date is in a previous year or not filled in, counting starts from January 1.

With the hourly wage method, the amount due for each month = that month's workday count × D.

"This year" is back-calculated from the current pay; in-year raises are not recorded.

### 6.6 Time and day rollover

- The device's current time zone and calendar are always used.
- After the end of work, today's amount stays at D and resets to zero at 0:00 the next day.
- The start of work must be earlier than the end of work; night shifts that cross midnight are not supported (first version).

### 6.7 Precision

- Internally, calculations use `Decimal`.
- In the app and in the Mac menu bar: the number of decimal places can be set from 0 to 8, default 6 (that is, 4 digits finer than cents).
- Widgets and Live Activity: fixed at 2 places, because they only update once a minute.

## 7. Currency and exchange rates

- The **display currency** may differ from the pay currency; all amounts are shown after conversion at the exchange rate.
- **Exchange rate source**, one of two:
  - Automatic: a free daily exchange rate API (European Central Bank data, such as Frankfurter, no key required), fetched at most once a day and cached; when the fetch fails, the last cached value is used, and the rate date is shown in settings.
  - Manual: the user enters a fixed rate.
- Supported currencies include at least CNY, USD, EUR, GBP, JPY, HKD, CAD, AUD, SGD.
- On first use with no cache and no network, automatic mode falls back to 1:1 and says so explicitly, rather than silently showing wrong amounts.

## 8. Holiday data

- **China**: uses the yearly JSON from the open-source project `neolee/holiday-cn` (which scrapes State Council announcements automatically every day), containing both holidays and make-up workdays. The files for the current year and the next year are bundled into the app; it checks online for updates at most once a week. Note the project's own caveat: December dates may appear in the next year's file, so both years must be read together.
- **United States**: the 11 federal holidays are computed in code by rule, including the observance rules (Saturday shifts to Friday, Sunday shifts to Monday).
- **Manual marks**: in settings, any day can be marked as working or off; this has the highest priority.

## 9. Equivalents and milestones

### 9.1 Equivalents

Converts an amount into a quantity of some everyday thing, for example "Equals Milk tea × 49.5". The user picks one item to show at a time and can add, delete and edit items. Defaults are provided by region:

| China | Default price | United States | Default price |
|---|---|---|---|
| Milk tea | ¥15 | Coffee | $5 |
| Coffee | ¥10 | Burrito | $12 |
| Takeout | ¥30 | Burger | $6 |
| Subway ride | ¥4 | Gallon of gas | $3.5 |
| Hot pot | ¥120 | Streaming month | $18 |
| iPhone | ¥7,999 | iPhone | $999 |

Each item has its own currency, and conversion goes through the exchange rate. Prices are rough defaults that the user can change.

### 9.2 Milestones

A milestone = name + amount + currency + the period it belongs to (day / month / year). Defaults are provided by region:

| Period | China | United States |
|---|---|---|
| Day | Lunch ¥30, Commute ¥10 | Lunch $15, Commute $6 |
| Month | Rent ¥5,000 | Rent $2,000 |
| Year | First 10k ¥10,000, First 100k ¥100,000 | First $10k, First $100k |

How reaching a milestone is determined (the designer's decision): the comparison uses **the amount shown in the UI**, that is, if after-tax display is on, the after-tax amount is used. The milestone amount is first converted to the display currency at the exchange rate and then compared. Whenever the deduction rate, the pre-tax / after-tax toggle, the exchange rate, the pay or the working hours change, the crossing times are recomputed and the notifications rescheduled.

- The main screen shows the milestones already reached within the current period.
- **Reminders** (can be turned off): because the income curve is deterministic, the crossing time can be computed ahead of time and a local notification scheduled, with no need to run in the background. Notification permission is requested the first time this is turned on.
- Milestones can be added, deleted and edited.

## 10. Display surfaces

Which periods are shown (today / this month / this year) is determined by one global setting, with at least one selected. How each surface follows it (the designer's decision):

- **Multi-line surfaces** (main screen, the mini receipt that pops up from the menu bar, medium widget, the Live Activity Lock Screen card and the expanded Dynamic Island): show all selected periods, one line per period.
- **Single-value surfaces** (small Home Screen widget, the three kinds of Lock Screen widget): each widget instance has its own "period" parameter, chosen in the system's widget editing UI, defaulting to today. This lets the user place a "today" widget and a "this month" widget side by side.
- **Surfaces fixed to today**: the Mac menu bar title and the compact Dynamic Island. They only have room for one number and do not change with the setting.

| Surface | How it updates | Content |
|---|---|---|
| App main screen | Per frame (`TimelineView`) | Full receipt |
| Mac menu bar | Every second | Title: today's amount; click to open the mini receipt |
| Medium Home Screen widget | Pre-scheduled timeline, one entry per minute | Amounts for the selected periods, equivalents |
| Small Home Screen widget | Same as above | Amount for the configured period |
| Lock Screen widgets (rectangular, inline, circular) | Same as above | Amount for the configured period |
| Live Activity: Lock Screen card | Updated when the app gets a chance | Amounts for the selected periods, as-of time, countdown |
| Live Activity: Dynamic Island | Same as above | Compact: today's amount; expanded: same as the Lock Screen card |

### 10.1 Widget timeline

One entry per minute during working hours; outside working hours the amount does not change, so only a few entries are needed. Each reload covers up to the next natural breakpoint (end of work, midnight). The system has a budget for the number of reloads; the exact number of entries and the reload strategy are left for the implementer to tune on a real device.

### 10.2 Live Activity

- **Start**: a manual button in the app; plus a setting, "start automatically when the app is opened during working hours".
- **Scheduled start**: evaluate using `request(...start:)` to schedule an automatic start at the next start of work; if that API is unavailable with a free account or in the local scenario, drop it, with no effect on other features.
- **Content and hierarchy** (explicitly required by the owner): the current amount is the most important and most prominent element, with the largest type and the first position. "As of HH:mm" and the countdown until off work (`Text(timerInterval:)`, fixed hours only) are secondary information. No progress bar.
- **The Live Activity stays in the first version** (the owner's decision): even if the real-device experiment shows that background updates are sparse, it is not cut and not changed to be countdown-first. The implementation should do its best to raise the amount's refresh frequency, trying each of these in the experiment: background task scheduling, `NSSupportsLiveActivitiesFrequentUpdates`, scheduled start, and updates in each of the app lifecycle callbacks. When the amount lags, the "as of" timestamp and the stale style tell the truth about it.
- **Update**: when the app returns to the foreground; when the system gives a background task a chance to run.
- **End**: with fixed hours, it ends at the end of work and shows the day's total. With flexible hours the paid period can reach 15 hours, which exceeds the system's 8-hour limit, so the activity will be ended by the system and the user has to open the app again to restart it; the UI explains this.
- **Stale**: after more than 15 minutes without an update, it enters the stale style.

### 10.3 Real-device experiment

Early in implementation, run a one-off real-device experiment to measure the actual frequency of local Live Activity updates and the actual behavior of the per-minute widget timeline. The results are used to tune the parameters in 10.1 and 10.2; the experiment code is not kept.

Devices and division of labor: the owner has an iPhone 17 Pro Max (with a Dynamic Island, so the Dynamic Island UI can be verified on a real device) and an iPad, plus the Mac used for development. Operations on the real devices (connecting, trusting, turning on Developer Mode, installing, day-to-day observation) are done by the owner under guidance. Developer Mode is not yet turned on on the iPhone, and the owner needs to be walked through turning it on before the first real-device install.

## 11. Visual design: the receipt

Out of three directions, the owner chose "A: Receipt".

- **Imagery**: a thermal-printer receipt. Cream paper background, dark gray text, monospaced font, dashed dividers, a centered header and sign-off.
- **Main screen structure** (top to bottom):

```
            WAGE DRIP
   Tue, Nov 24 · On the clock
  - - - - - - - - - - - - - - -
  Earned today
  ¥742.318642
  - - - - - - - - - - - - - - -
  This month         ¥14,105.52
  This year         ¥268,340.17
  - - - - - - - - - - - - - - -
  Equals Milk tea        × 49.5
  Covered         Lunch Commute
  - - - - - - - - - - - - - - -
     Until off work 02:41:07
      Thank you, come again
```

- **Today's amount**: an odometer-style animation that rolls digit by digit (the designer's decision).
- **Dark mode**: a separately designed "night receipt", with a dark background and light text, keeping the dashed lines and the monospaced font, not a simple color inversion (the designer's decision).
- **Status copy**: On the clock, Off work, Day off today, Before work; the sign-off changes with the status and keeps the self-deprecating tone.
- **Widgets and Live Activity** reuse the same paper color, font and dashed lines.
- **iPad and Mac**: the receipt stays narrow and centered and does not stretch with the window.
- **Settings**: use the system's standard form style, not styled as a receipt, to guarantee usability.

## 12. Settings at a glance

- Region (China / United States): determines the holiday calendar, the default currency, the default equivalents and the default milestones. Inferred from the system region on first launch, and can be changed. Changing the region does not overwrite anything the user has already edited.
- Pay method and amount, bonus toggle, stock toggle, pay currency.
- Deduction rate and the four reference values, pre-tax / after-tax display.
- Start of work, end of work.
- Flexible hours toggle and the two weights.
- Start date (optional).
- Holiday calendar (China / United States / none), manually marked days.
- Displayed periods (today / this month / this year, multi-select).
- Number of decimal places.
- Display currency, exchange rate mode, manual exchange rate.
- Equivalents, milestones, milestone reminder toggle.
- Live Activity auto-start toggle.

First launch goes through a short onboarding: region, pay, working hours; three steps and the receipt is on screen.

## 13. Testing

- `WageDripCore` is unit-tested with Swift Testing, with a focus on:
  - The month-end total equals the monthly salary (including months with holidays and make-up workdays, such as February and October 2027).
  - The intraday curves for fixed and flexible hours and each boundary moment.
  - The three start date cases: at the beginning of the year, mid-month, and in a previous year.
  - The observance rules for US federal holidays.
  - Exchange rate conversion and cache fallback.
  - Calculation of milestone crossing times.
- The UI is verified mainly by hand on the simulator and on real devices.

## 14. Left to the implementer

- The number of entries in the widget timeline and the reload strategy.
- The specific way background tasks are scheduled.
- Whether flexible hours is a fixed pair of segments in the data model or a general list of segments (the UI only needs to expose the two weights).
- The specific implementation of the odometer animation.
- How the SwiftUI views are split up and named.

## 15. Later

- A push service so the Live Activity amount updates reliably every minute (requires a paid account).
- iCloud sync of settings.
- The icon, screenshots and privacy disclosures needed for the App Store release.
- Apple Watch complications and a Smart Stack widget (the watch app itself is described in section 18).
- In-year raise history, night shifts.

## 16. Sources

- ActivityKit and WidgetKit release notes, "Displaying live data with Live Activities" (Apple developer documentation).
- Apple Developer Forums thread 797554 (Live Activity update frequency).
- `neolee/holiday-cn`; General Office of the State Council notice on the 2027 holiday schedule (2026-11-05).
- Ministry of Human Resources and Social Security 2025 notice on the number of paid days per month (21.75 days).
- `AndyUneducated/financial-calculators` (the basis for the order of magnitude of the deduction rate reference values).

## 17. Real-device experiment results (2026-11-24)

Device: iPhone 17 Pro Max, iOS 27, signed with a free personal team, not plugged in. Observation lasted about 39 minutes (22:32 to 23:11); the sample is on the small side, and the background frequency numbers should be treated as optimistic estimates. The experiment code is on the branch `spike/device-cadence` and is not merged.

| Item | Result |
|---|---|
| App Group (free account) | Works. It must first be registered once in Xcode's Signing & Capabilities; it cannot be registered from the command line. Reads and writes work in both directions between the app and the widget |
| Per-minute widget timeline | The small Home Screen widget stays roughly in sync with real time; the owner observed deviations of within a few minutes. Lock Screen widgets were not tested |
| Live Activity: just after going to the background | Can still update for about 25 seconds, then the app is suspended |
| Live Activity: background refresh task | Woken up and updated successfully about once every 7 to 9 minutes (three samples: intervals of 7, 9 and 9 minutes) |
| Live Activity: scheduled start `request(...start:)` | Works. Scheduled 120 seconds ahead, it became active on time, with the app in the background and the phone locked; on start, the system wakes the app for about 20 seconds |
| Live Activity: foreground update | Not recorded (a defect in the experiment code); treated as working based on known behavior |

Not tested: Lock Screen widgets, Low Power Mode, scheduled start after swiping the app away from the app switcher, overnight, plugged in.

Parameters settled on this basis:

- Widget timeline: `minuteStep = 1`, `maxEntries = 240`, keeping the original design.
- Live Activity stale threshold: 15 minutes, keeping the original design (the background refresh interval is about half of that).
- The background refresh task is resubmitted after each run, with the earliest begin time set to 5 minutes later.
- Scheduled start is adopted: each time an activity ends, the start of work on the next workday is scheduled; this applies to both fixed hours and flexible hours.
- Without push, the Live Activity amount refreshes about once every 7 to 9 minutes, so the "as of HH:mm" timestamp must stay.

Findings on project configuration: `project.yml` needs to declare the App Groups capability; the development team is passed in through an environment variable (`DEVELOPMENT_TEAM=<team ID> xcodegen generate`) and is not written into the repository; the macOS target must have a development team in order to be signed and built.

### 17.1 Additional findings during the phase 4 implementation (simulator)

- The system caps the number of Live Activities per app: on the simulator, after scheduling 5 scheduled starts, starting the current day's activity fails with "Maximum number of activities for target already exists". So only 2 workdays are scheduled ahead, leaving a slot for the current day's activity.
- Starting a Live Activity must happen in the foreground, so "appears automatically every day" depends on scheduling: each time the app is opened, the next 2 workdays are scheduled. If the app is not opened for more than 2 consecutive workdays, the automatic appearance stops until the next time it is opened.
- The scheduled start API requires an alert configuration to be attached, so there is one alert sound each day when the Live Activity appears at the start of work.
- The simulator does not support background refresh tasks (`BGTaskScheduler`); background updates can only be verified on a real device.

## 18. Apple Watch app (added 2026-11-25)

Apple Watch was a non-goal for the first version. It was added after the Live Activity turned out to be mirrored to a paired watch whether the app wants it or not, where it showed a blank app icon and did nothing when tapped.

### 18.1 Scope

- One screen: the status, the headline amount ticking, the other selected periods, the countdown (fixed hours only) and the sign-off. Night receipt colors always, because the watch has no light appearance.
- No settings on the watch, no network access on the watch, no complications or Smart Stack widget yet.
- Tapping the mirrored Live Activity opens the watch app (`WKSupportsLiveActivityLaunchAttributeTypes`).

### 18.2 Structure

- `WageDripWatch` is a watchOS app target embedded in the iPhone app (`Watch/WageDripWatch.app`); the Mac build leaves it out. Bundle ID `com.andyuneducated.wagedrip.watchkitapp`.
- `WageDripCore` builds for watchOS unchanged, so the watch computes amounts with the same engine as every other surface.
- The watch shares no storage with the phone. The phone sends a `WatchPayload` over WatchConnectivity: the settings, the pay-to-display exchange rate, and any China holiday files downloaded since the app was built.
  - The phone replaces its application context whenever settings change and each time the app comes to the foreground. Only the latest state matters, so nothing is queued.
  - A watch that has never received anything asks the phone with a message; this also wakes the phone app in the background.
  - The watch keeps the last payload in its own defaults and works from that when the phone is out of reach.
- Until the first payload arrives the watch asks the owner to open the iPhone app; if onboarding is not finished it asks for that instead.

### 18.3 Simulator results (2026-11-25, iPhone 17 paired with Apple Watch Ultra 4, watchOS 27.2)

| Checked | Result |
|---|---|
| App icon in the watch's app grid | Shown |
| App icon at the top of the watch face while the Live Activity runs | Shown |
| Live Activity card in the Smart Stack | Shown, using the `.small` layout |
| Tapping the Live Activity indicator on the watch face | Opens the watch app |
| First sync after installing | Amounts on the watch match the phone |
| Changing a setting on the phone (turning on a 22% deduction) | The watch showed the reduced amounts within a few seconds |
| Builds | iOS simulator, iOS device with a free team, and macOS all build; the Mac app contains no watch app |

Not verified: anything on a physical watch; whether the icon and tap problems seen on the owner's watch are gone there; behaviour when the phone is out of range; installing over a free 7-day profile. Tapping the Live Activity card inside the Smart Stack (rather than the indicator on the face) once showed the system's "Open on iPhone" sheet, during a run where the watch was displaying a stale activity; this was not reproduced cleanly either way.

Two things learned along the way: watchOS asset catalogs ignore the dark variants of colors, so the watch's colors are set in code; and XcodeGen embeds the watch app only when the dependency carries `platformFilter: iOS` (`platforms: [iOS]` silently drops it).
