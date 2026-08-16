import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class SettingsService {
  static const _providersKey = 'providers';
  static const _activeProviderKey = 'activeProvider';
  // 🔥 NEW: Key for auto-send logs
  static const _autoSendLogsKey = 'autoSendLogs';

  Future<List<AIProviderConfig>> loadProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_providersKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => AIProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProviders(List<AIProviderConfig> providers) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      providers.map((p) => p.toJson()).toList(),
    );
    await prefs.setString(_providersKey, jsonString);
  }

  Future<String?> getActiveProviderName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProviderKey);
  }

  Future<void> setActiveProvider(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProviderKey, name);
  }

  // 🔥 NEW: Auto-send logs methods
  Future<bool> getAutoSendLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSendLogsKey) ?? false;
  }

  Future<void> setAutoSendLogs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSendLogsKey, value);
  }
}
