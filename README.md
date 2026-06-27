# FitForge 🏋️

**健身饮食记录与营养素配比 App** — 跨平台 Flutter 应用，支持训练日志、饮食追踪、碳循环/碳水减降/增肌营养方案、体测记录、中英双语切换。

> Log every rep. Own every meal.

[![Deploy](https://github.com/Yeezy-2020/fitforge/actions/workflows/deploy.yml/badge.svg)](https://github.com/Yeezy-2020/fitforge/actions/workflows/deploy.yml)
[![Tests](https://img.shields.io/badge/tests-88%20passed-brightgreen)]()

## 线上地址

[**https://yeezy-2020.github.io/fitforge**](https://yeezy-2020.github.io/fitforge)

## 技术栈

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x (Dart) |
| 状态管理 | Riverpod 2.6 |
| 路由 | GoRouter |
| 后端 | Supabase (PostgreSQL / Auth / Storage) |
| 本地存储 | Flutter Secure Storage |
| CI/CD | GitHub Actions → GitHub Pages |
| 测试 | flutter_test (88 项) |

## 功能模块

### 训练 (Workout)
- 训练日历 + 拖拽排序，滑动折叠日历
- 29 种动作双语库（中/英），含 Wger 图片、动作要领、常见错误
- 训练模板保存/加载
- 训练计划 MVP：支持练三休一、训练日/休息日、动作处方、今日计划建议
- 渐进超负荷引擎：支持双进阶、线性加重、周期化 MVP，并基于历史训练生成下次建议
- 计划完成推进：保存完整计划训练后自动推进到下一训练日/休息日
- 组间休息计时器（5s–10min CupertinoPicker）
- 训练记录离线缓存 + Supabase 同步

### 饮食 (Diet)
- 6 餐饮食记录（Breakfast / Lunch / Dinner / Snack 1 / Snack 2 / Snack 3）
- 食物数据库（中英文双语） + 自定义食物
- 饮食模板保存/一键加载
- 每日热量/宏量营养素统计

### 营养计划 (Nutrition)
- **碳循环** — 可自定义周期模板（low/medium/high）+ 预设模板（Classic 7-Day, 3-Day Rolling 等）
- **碳水减降** — 线性递减（Helms 公式），含 Refeed 倒计时
- **增肌** — 基于训练经验级别（Beginner/Intermediate/Advanced）调整碳水和热量盈余（Slater 2019）
- Dashboard：Daily Targets 居中展示 + 进度条对比实际摄入
- 基础数据：BMR / TDEE / TEF 实时计算

### 身体数据 (Body)
- 体重/体脂/围度记录
- 体重折线图（fl_chart）

### 账户 & 设置
- 邮箱登录/注册（Supabase Auth）
- Google / Apple 登录（TODO）
- 中英语言切换 + kg/lb、g/oz 单位切换
- 账户管理（个人信息、登出）

## 项目结构

```
lib/
├── app.dart                    # App 入口 + GoRouter 配置
├── main.dart                   # main() 启动
├── core/
│   ├── constants/              # 常量
│   ├── database/               # 本地数据库抽象
│   ├── localization/           # L10n 双语字典 (EN/ZH)
│   ├── services/               # Supabase 服务、同步服务
│   ├── theme/                  # 亮/暗主题
│   └── utils/                  # 营养计算器 (NutritionCalculator)
├── data/
│   ├── models/                 # 数据模型
│   │   ├── exercise.dart       # 动作
│   │   ├── workout_log.dart    # 训练记录
│   │   ├── food.dart           # 食物
│   │   ├── diet_log.dart       # 饮食记录
│   │   ├── user_profile.dart   # 用户资料
│   │   ├── workout_template.dart
│   │   ├── body_measurement.dart
│   │   ├── progression_rule.dart
│   │   ├── training_program.dart # 训练计划/训练日/动作处方/组级记录
│   │   └── nutrition_plan.dart
│   └── repositories/
│       ├── app_database.dart   # 本地持久化 (SecureStorage)
│       └── exercise_library.dart # 29 动作库
├── features/
│   ├── auth/                   # 登录/注册/Onboarding
│   ├── home/                   # 底部导航 Shell
│   ├── workout/                # 训练日历/训练日/模板/动作详情/计时器
│   ├── diet/                   # 饮食记录
│   ├── nutrition_plan/         # 营养方案面板
│   ├── body/                   # 体测记录
│   ├── settings/               # 设置/账户管理
│   └── subscription/           # 付费墙
└── providers/
    ├── app_providers.dart      # 全局 Riverpod Provider
    └── settings_providers.dart # 语言/单位 Provider
```

## 本地开发

### 前置条件

- Flutter SDK ≥ 3.12
- Chrome（Web 开发）

### 启动

```bash
git clone https://github.com/Yeezy-2020/fitforge.git
cd fitforge
flutter pub get
flutter run -d chrome
```

### 运行测试

```bash
# 全部测试
flutter test

# 特定模块
flutter test test/features/all_features_test.dart
flutter test test/screens/nutrition_test.dart

# 死按钮扫描
grep -rn "onPressed: () => {}" lib/ --include="*.dart"
```

### Pre-push 检查

```bash
bash scripts/pre_push.sh
```

执行流程：`flutter analyze` → `flutter test` → widget dump → dead button scan

### 新功能测试要求

**添加新功能时必须同步编写测试**，不允许仅靠线上手动验证。测试金字塔：

| 层级 | 要求 | 示例 |
|------|------|------|
| 单元测试 | 新模型/公式/序列化逻辑 | `planDurationDays` 序列化、BMR 公式 |
| Widget 测试 | 新页面可渲染、无死按钮 | screen 编译不抛异常、`onPressed` 非空 |
| 交互测试 | 核心流程步骤可推进 | onboarding 步骤数、预设值边界 |

测试文件位置：
- 模型逻辑 → `test/features/all_features_test.dart`
- 页面/交互 → `test/screens/<模块>_test.dart`

```bash
# 全量测试（CI 必过）
flutter test

# 新功能专项测试
flutter test test/screens/nutrition_test.dart

# 渐进超负荷 / 训练计划专项测试
flutter test test/features/progression_test.dart
flutter test test/features/training_program_test.dart
```

## 部署

`main` 分支推送后 GitHub Actions 自动构建并部署到 GitHub Pages：

```
.flutter build web --release --base-href /fitforge/
```

## 测试账号

| 邮箱 | 密码 |
|------|------|
| test@fitforge.com | 123456 |

## 部署后验证

每次 `git push` 后**必须**到线上环境验证改动：

1. GitHub Actions 构建完成（约 2-3 分钟）
2. 访问 [https://yeezy-2020.github.io/fitforge](https://yeezy-2020.github.io/fitforge)
3. 使用测试账号登录，逐项检查改动功能
4. 有问题截图提 GitHub Issue

## 营养公式参考

| 方案 | 公式来源 | 说明 |
|------|----------|------|
| 碳循环 | Israetel / RP | 高/中/低碳水日轮换，按训练强度分配 |
| 碳水减降 | Helms | 线性递减碳水，Refeed 每 14 天 |
| 增肌 | Slater 2019 | 基于训练经验的碳水比调整 |
| 基础 BMR | Mifflin-St Jeor | 男: 10W + 6.25H − 5A + 5, 女: 10W + 6.25H − 5A − 161 |
| 蛋白参考 | ISSN 1.6–2.2 g/kg | 按目标动态计算 |

## 开发注意事项

### Pre-push 检查

每次 `git push` 前务必执行（或配置 Git hook 自动运行）：

```bash
bash scripts/pre_push.sh
```

脚本会依次执行：`flutter analyze` → `flutter test`（88 项） → widget dump → dead button scan。**任何一项失败均不允许推送。**

### 死按钮 (Dead Button) 检查

禁止代码中出现空回调 `onPressed: () => {}`。所有按钮必须有实际行为：

```bash
DEAD=$(grep -rn "onPressed: () => {}" lib/ --include="*.dart" | wc -l)
# 结果必须为 0
```

CI 也会执行此项检查。如需占位按钮，请使用条件禁用（`onPressed: condition ? fn : null`）而非空回调。

### flutter analyze 已知警告

以下 8 个 info 级别警告属于已知项，不会阻止构建或测试：

| 文件 | 警告 | 原因 |
|------|------|------|
| `diet_log_screen.dart:106` | `use_build_context_synchronously` | 跨 async 使用 context |
| `settings_screen.dart:45` | `groupValue` deprecated | 等待替换为 RadioGroup |
| `exercise_detail_screen.dart:25` | `unnecessary_underscores` | 待清理 |
| `workout_calendar_screen.dart:173` | `onReorder` deprecated | 待迁移到 onReorderItem |
| `test/dump_test.dart:30-38` | `avoid_print` | 测试用 print，无影响 |

禁止引入新的 error 或 warning 级别问题。

### 网络环境

构建/部署环境可能无法直接访问 `github.com`（TLS 被干扰），需通过代理：

```bash
# V2Ray HTTP 代理示例
git config --local http.proxy http://127.0.0.1:10809
git config --local https.proxy http://127.0.0.1:10809
# 推送完成后建议清除：
git config --local --unset http.proxy
git config --local --unset https.proxy
```

### Supabase 配置

- **项目 URL**: `https://ofkdjqfamtuwfzyfncvt.supabase.co`
- **认证**: Supabase Auth（邮箱密码 + Google/Apple TODO）
- **数据**: 本地优先（SecureStorage），Supabase 仅作同步
- 测试账号：`test@fitforge.com` / `123456`

### 图片反馈流程

UI 问题截图通过 GitHub Issues 提交，附带步骤描述和预期行为，便于复现。

## 近期修复记录

### 2026-06-22 功能更新：渐进超负荷 (Progressive Overload)

- 可为每个动作单独设置渐进超负荷规则，按当前用户本地隔离存储（SecureStorage）。
- 训练时自动读取该动作的上一条训练记录，按规则给出下一次的重量 / 次数 / 组数建议并预填到输入框；没有上次记录时使用规则默认值。
- 支持四种进阶方式：固定加重量 (fixedWeight)、百分比加重量 (percentWeight)、加次数 (reps)、双进阶 (doubleProgression，达到最大次数后加重量并回到最小次数)。
- 支持 `onlyIfCompleted`（仅在达成目标组数/次数时进阶）、默认重量/组数/次数、最小/最大次数等配置；建议值会做合理边界裁剪（重量不小于 0）。
- 用户手动修改训练输入后，不会被异步加载出来的建议覆盖。
- 当前渐进规则仅本地存储，适合开发阶段验证，暂未接入 Supabase 同步。

> 订阅页 (`PaywallScreen`) 的真实购买校验仍属于开发阶段事项，本次未处理，上线前需补齐。

### 2026-06-22 稳定性修复

- 修复 Supabase 训练/饮食日志写入未携带本地 `id` 的问题，改为使用本地 UUID 作为远端主键并通过 `upsert` 写入，保证新增、编辑、删除能定位同一条记录。
- 改进离线同步：训练和饮食日志新增失败会进入待同步队列，删除失败会进入待删除队列；恢复网络后只清理同步成功的项目，避免失败时误清空队列导致数据丢失。
- 修复饮食模板保存和加载的数据结构不一致问题，加载逻辑兼容旧的列表格式和新的 `{ name, items }` 格式。
- 修复训练/饮食编辑、删除流程中未 `await` Supabase 请求的问题，避免异步错误绕过 `try/catch` 后造成本地和远端状态不一致。
- 增加登录态路由保护：未登录用户访问业务页面会回到登录页，已有登录态会直接进入主界面；登出后同步清空本地用户状态。
- 登录页密码可见按钮改为真实切换；Google / Apple 登录按钮当前为开发占位，会明确提示 “coming soon”，不再静默无响应。
- 修复 `scripts/pre_push.sh` 的 `flutter analyze` 检查方式，直接依赖命令退出码，避免 grep 文本导致误判。

> 订阅购买目前仍处于开发占位阶段，`PaywallScreen` 暂未接入真实 App Store / Google Play / RevenueCat 校验，上线前必须补齐真实购买校验和服务端权益校验。

## License

MIT
