import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import 'app_database.dart';

/// 设置仓储：单例设置 + ChangeNotifier 驱动 UI 更新。
class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this.db) {
    final stored = db.settings.get(AppDatabase.settingsKey);
    _settings = stored ?? ReminderSettings();
  }

  final AppDatabase db;

  ReminderSettings _settings;
  ReminderSettings get settings => _settings;

  /// 修改设置并持久化。
  Future<void> update(void Function(ReminderSettings s) mutate) async {
    mutate(_settings);
    await db.settings.put(AppDatabase.settingsKey, _settings);
    notifyListeners();
  }
}
