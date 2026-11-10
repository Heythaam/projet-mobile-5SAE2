import 'package:shared_preferences/shared_preferences.dart';

/// The dark/light choice from Settings. Only saved for now; the app does not
/// change its look from it yet.
class ThemePreference {
  static const darkKey = 'theme.dark';

  static Future<bool> loadDark() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(darkKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveDark(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(darkKey, value);
    } catch (_) {}
  }
}
