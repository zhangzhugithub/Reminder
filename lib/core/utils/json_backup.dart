import 'dart:convert';

import '../models/settings.dart';
import '../models/task.dart';

/// 本地备份文件格式（版本化信封）。
///
/// 备份仅存本机，不自动上传（需求 5.2）。
class BackupEnvelope {
  BackupEnvelope._();

  static const appId = 'offline_voice_reminder';
  static const version = 1;

  static Map<String, dynamic> encode(
      List<Task> tasks, ReminderSettings settings) {
    return {
      'app': appId,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'taskCount': tasks.length,
      'tasks': [for (final t in tasks) t.toJson()],
      'settings': settings.toJson(),
    };
  }

  /// 解析并校验备份文件；格式不符抛 [FormatException]。
  static BackupData decode(String jsonString) {
    final dynamic raw;
    try {
      raw = jsonDecode(jsonString);
    } catch (e) {
      throw FormatException('JSON 解析失败：$e');
    }
    if (raw is! Map || raw['app'] != appId) {
      throw const FormatException('不是本应用的备份文件');
    }
    final tasks = <Task>[];
    for (final t in (raw['tasks'] as List? ?? const [])) {
      if (t is Map) {
        try {
          tasks.add(Task.fromJson(t.cast<String, dynamic>()));
        } catch (_) {
          // 单条损坏跳过，不阻塞整份恢复
        }
      }
    }
    ReminderSettings settings;
    try {
      settings = ReminderSettings.fromJson(
          (raw['settings'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{});
    } catch (_) {
      settings = ReminderSettings();
    }
    return BackupData(
      tasks: tasks,
      settings: settings,
      exportedAt: raw['exportedAt'] as String?,
    );
  }
}

/// 解析后的备份数据。
class BackupData {
  const BackupData({
    required this.tasks,
    required this.settings,
    this.exportedAt,
  });

  final List<Task> tasks;
  final ReminderSettings settings;
  final String? exportedAt;
}
