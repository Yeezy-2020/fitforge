import '../../data/models/user_profile.dart';

class NutritionCalculator {
  const NutritionCalculator();

  // ---- Core formulas ----
  double bmr(UserProfile p) {
    if (p.gender == Gender.male) {
      return 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + 5;
    }
    return 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age - 161;
  }

  double tdee(double bmr, double activityFactor) => bmr * activityFactor;

  double tef(double tdee) => tdee * 0.1;

  static const Map<String, double> activityFactors = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
  };

  // ---- Macro split ----
  ({double protein, double carbs, double fat}) split(double kcal, double pctP, double pctC, double pctF) {
    return (
      protein: (kcal * pctP / 4).roundToDouble(),
      carbs: (kcal * pctC / 4).roundToDouble(),
      fat: (kcal * pctF / 9).roundToDouble(),
    );
  }

  // ---- Carb Cycling (Renaissance Periodization / Israetel) ----
  ({double cals, double protein, double carbs, double fat}) carbCycleDay(
    UserProfile p, String dayType, double activityFactor, double deficit) {
    final b = bmr(p);
    final t = tdee(b, activityFactor);
    final tf = tef(t);
    final targetKcal = t + tf - deficit;

    double pctP = 0.30;
    double pctC, pctF;

    switch (dayType) {
      case 'high':
        pctC = 0.50; pctF = 0.20;
      case 'medium':
        pctC = 0.35; pctF = 0.35;
      case 'low':
      default:
        pctC = 0.15; pctF = 0.55;
    }

    final s = split(targetKcal, pctP, pctC, pctF);
    // Clamp protein to ISSN range 1.6-2.2 g/kg
    final protein = (p.weightKg * 1.8).clamp(p.weightKg * 1.6, p.weightKg * 2.2);
    return (cals: targetKcal, protein: protein, carbs: s.carbs, fat: s.fat);
  }

  // ---- Linear Carb Taper (Helms) ----
  ({double cals, double protein, double carbs, double fat}) carbTaper(
    UserProfile p, double activityFactor, double deficit, double carbGPerKg, double fatGPerKg) {
    final b = bmr(p);
    final t = tdee(b, activityFactor);
    final tf = tef(t);
    final targetKcal = t + tf - deficit;
    final protein = (p.weightKg * 2.3).clamp(p.weightKg * 2.0, p.weightKg * 2.5);
    final carbs = p.weightKg * carbGPerKg;
    final fat = p.weightKg * fatGPerKg;
    return (cals: targetKcal, protein: protein, carbs: carbs, fat: fat);
  }

  // ---- Bulk (Slater 2019) ----
  ({double cals, double protein, double carbs, double fat}) bulk(
    UserProfile p, double activityFactor, int surplus, String experienceLevel) {
    final b = bmr(p);
    final t = tdee(b, activityFactor);
    final tf = tef(t);
    final targetKcal = t + tf + surplus;

    double pctP, pctC, pctF;
    switch (experienceLevel) {
      case 'beginner':
        pctP = 0.25; pctC = 0.50; pctF = 0.25;
      case 'intermediate':
        pctP = 0.28; pctC = 0.47; pctF = 0.25;
      case 'advanced':
      default:
        pctP = 0.30; pctC = 0.45; pctF = 0.25;
    }

    final s = split(targetKcal, pctP, pctC, pctF);
    return (cals: targetKcal, protein: s.protein, carbs: s.carbs, fat: s.fat);
  }

  // ---- Legacy (keep compatibility) ----
  ({double tdee, double protein, double carbs, double fat}) calculateLegacy(UserProfile profile) {
    final b = bmr(profile);
    final t = tdee(b, 1.55);

    double protein, fat, carbs;
    switch (profile.goal) {
      case FitnessGoal.loseFat:
        final tc = t * 0.8;
        protein = profile.weightKg * 2.2;
        fat = profile.weightKg * 0.8;
        carbs = (tc - protein * 4 - fat * 9) / 4;
        return (tdee: tc, protein: protein, carbs: carbs.clamp(50, 300), fat: fat);
      case FitnessGoal.buildMuscle:
        final tc = t * 1.15;
        protein = profile.weightKg * 2.0;
        fat = profile.weightKg * 0.9;
        carbs = (tc - protein * 4 - fat * 9) / 4;
        return (tdee: tc, protein: protein, carbs: carbs.clamp(100, 500), fat: fat);
      case FitnessGoal.maintain:
        protein = profile.weightKg * 1.6;
        fat = profile.weightKg * 0.9;
        carbs = (t - protein * 4 - fat * 9) / 4;
        return (tdee: t, protein: protein, carbs: carbs.clamp(100, 400), fat: fat);
    }
  }
}
