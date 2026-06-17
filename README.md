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

## 部署

`main` 分支推送后 GitHub Actions 自动构建并部署到 GitHub Pages：

```
.flutter build web --release --base-href /fitforge/
```

## 测试账号

| 邮箱 | 密码 |
|------|------|
| test@fitforge.com | 123456 |

## 营养公式参考

| 方案 | 公式来源 | 说明 |
|------|----------|------|
| 碳循环 | Israetel / RP | 高/中/低碳水日轮换，按训练强度分配 |
| 碳水减降 | Helms | 线性递减碳水，Refeed 每 14 天 |
| 增肌 | Slater 2019 | 基于训练经验的碳水比调整 |
| 基础 BMR | Mifflin-St Jeor | 男: 10W + 6.25H − 5A + 5, 女: 10W + 6.25H − 5A − 161 |
| 蛋白参考 | ISSN 1.6–2.2 g/kg | 按目标动态计算 |

## License

MIT
