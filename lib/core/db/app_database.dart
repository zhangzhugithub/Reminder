import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/settings.dart';
import '../models/task.dart';

/// 本地数据库初始化与 Box 访问。
///
/// Boxes:
/// - `tasks`：任务主数据（Box<Task>）
/// - `settings`：应用设置（Box<ReminderSettings>，单键 'default'）
/// - `meta`：元数据（Box，原始类型 Map 存储：日历 ID、删除墓碑、通知块计数器等）
class AppDatabase {
  static const taskBoxName = 'tasks';
  static const settingsBoxName = 'settings';
  static const metaBoxName = 'meta';

  static const settingsKey = 'default';

  late final Box<Task> tasks;
  late final Box<ReminderSettings> settings;
  late final Box meta;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(ReminderSettingsAdapter());
    tasks = await Hive.openBox<Task>(taskBoxName);
    settings = await Hive.openBox<ReminderSettings>(settingsBoxName);
    meta = await Hive.openBox(metaBoxName);
  }

  /// 元数据读写（Map 存储，避免为内部状态维护额外适配器）。
  Map<String, dynamic> readMeta() =>
      (meta.get('main') as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

  Future<void> writeMeta(Map<String, dynamic> data) async {
    await meta.put('main', data);
  }

  Future<void> updateMeta(void Function(Map<String, dynamic>) mutate) async {
    final data = readMeta();
    mutate(data);
    await meta.put('main', data);
  }

  /// 重置：清空全部本地数据（任务、设置、元数据）。
  Future<void> resetAll() async {
    await tasks.clear();
    await settings.clear();
    await meta.clear();
  }

  Future<void> close() async {
    await tasks.close();
    await settings.close();
    await meta.close();
  }
}
