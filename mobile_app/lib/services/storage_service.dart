import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_model.dart';

class StorageService {
  static const String keyMinTemp = 'min_temp_limit';
  static const String keyMaxTemp = 'max_temp_limit';
  static const String keyAlertHistory = 'alert_history';

  // Save temperature thresholds locally
  static Future<void> saveLimits(double minTemp, double maxTemp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyMinTemp, minTemp);
    await prefs.setDouble(keyMaxTemp, maxTemp);
  }

  // Get saved Min Temp threshold (default 2.0 °C)
  static Future<double> getMinTemp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(keyMinTemp) ?? 2.0;
  }

  // Get saved Max Temp threshold (default 8.0 °C)
  static Future<double> getMaxTemp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(keyMaxTemp) ?? 8.0;
  }

  // Save an alert record to local history
  static Future<void> addAlertRecord(AlertRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<AlertRecord> currentHistory = await getAlertHistory();
    currentHistory.insert(0, record); // prepend newest first

    // Keep maximum 50 records
    if (currentHistory.length > 50) {
      currentHistory.removeLast();
    }

    final List<String> encodedList =
        currentHistory.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(keyAlertHistory, encodedList);
  }

  // Retrieve alert history log
  static Future<List<AlertRecord>> getAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? encodedList = prefs.getStringList(keyAlertHistory);
    if (encodedList == null) return [];

    return encodedList
        .map((str) => AlertRecord.fromJson(jsonDecode(str)))
        .toList();
  }

  // Clear history log
  static Future<void> clearAlertHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAlertHistory);
  }
}
