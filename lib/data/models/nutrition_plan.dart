class NutritionPlanConfig {
  final String planType; // 'carb_cycle', 'carb_taper', 'bulk'
  final double activityFactor;
  final String experienceLevel; // 'beginner', 'intermediate', 'advanced'
  final int deficit; // 500 default
  final int surplus; // 500 default
  final double currentCarbGPerKg; // for carb taper
  final double fatGPerKg; // for carb taper
  final int refeedIntervalDays; // for carb taper refeed
  final List<String>? cycleTemplate; // for carb cycle ['low','low','medium','low','medium','medium','high']
  final int? planDurationDays; // for carb taper, null = unlimited

  const NutritionPlanConfig({
    required this.planType,
    this.activityFactor = 1.55,
    this.experienceLevel = 'intermediate',
    this.deficit = 500,
    this.surplus = 500,
    this.currentCarbGPerKg = 3.0,
    this.fatGPerKg = 1.0,
    this.refeedIntervalDays = 14,
    this.cycleTemplate,
    this.planDurationDays,
  });

  factory NutritionPlanConfig.fromJson(Map<String, dynamic> json) => NutritionPlanConfig(
    planType: json['planType'] as String,
    activityFactor: (json['activityFactor'] as num).toDouble(),
    experienceLevel: json['experienceLevel'] as String? ?? 'intermediate',
    deficit: json['deficit'] as int? ?? 500,
    surplus: json['surplus'] as int? ?? 500,
    currentCarbGPerKg: (json['currentCarbGPerKg'] as num?)?.toDouble() ?? 3.0,
    fatGPerKg: (json['fatGPerKg'] as num?)?.toDouble() ?? 1.0,
    refeedIntervalDays: json['refeedIntervalDays'] as int? ?? 14,
    cycleTemplate: (json['cycleTemplate'] as List?)?.cast<String>(),
    planDurationDays: json['planDurationDays'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'planType': planType,
    'activityFactor': activityFactor,
    'experienceLevel': experienceLevel,
    'deficit': deficit,
    'surplus': surplus,
    'currentCarbGPerKg': currentCarbGPerKg,
    'fatGPerKg': fatGPerKg,
    'refeedIntervalDays': refeedIntervalDays,
    if (cycleTemplate != null) 'cycleTemplate': cycleTemplate,
    if (planDurationDays != null) 'planDurationDays': planDurationDays,
  };
}
