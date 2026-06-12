import '../../data/models/user_profile.dart';

class NutritionCalculator {
  const NutritionCalculator();

  ({double tdee, double protein, double carbs, double fat}) calculate(
    UserProfile profile,
  ) {
    final bmr = _calculateBMR(profile);
    final tdee = _calculateTDEE(bmr, profile);

    double protein;
    double fat;
    double carbs;

    switch (profile.goal) {
      case FitnessGoal.loseFat:
        final targetCalories = tdee * 0.8;
        protein = profile.weightKg * 2.2;
        fat = profile.weightKg * 0.8;
        carbs = (targetCalories - protein * 4 - fat * 9) / 4;
        return (
          tdee: targetCalories,
          protein: protein,
          carbs: carbs.clamp(50, 300),
          fat: fat,
        );

      case FitnessGoal.buildMuscle:
        final targetCalories = tdee * 1.15;
        protein = profile.weightKg * 2.0;
        fat = profile.weightKg * 0.9;
        carbs = (targetCalories - protein * 4 - fat * 9) / 4;
        return (
          tdee: targetCalories,
          protein: protein,
          carbs: carbs.clamp(100, 500),
          fat: fat,
        );

      case FitnessGoal.maintain:
        protein = profile.weightKg * 1.6;
        fat = profile.weightKg * 0.9;
        carbs = (tdee - protein * 4 - fat * 9) / 4;
        return (
          tdee: tdee,
          protein: protein,
          carbs: carbs.clamp(100, 400),
          fat: fat,
        );
    }
  }

  ({double tdee, double bmr}) getTdeeAndBmr(UserProfile profile) {
    final bmr = _calculateBMR(profile);
    final tdee = _calculateTDEE(bmr, profile);
    return (tdee: tdee, bmr: bmr);
  }

  double _calculateBMR(UserProfile profile) {
    if (profile.gender == Gender.male) {
      return 10 * profile.weightKg +
          6.25 * profile.heightCm -
          5 * profile.age +
          5;
    } else {
      return 10 * profile.weightKg +
          6.25 * profile.heightCm -
          5 * profile.age -
          161;
    }
  }

  double _calculateTDEE(double bmr, UserProfile profile) {
    return bmr * 1.55;
  }
}
