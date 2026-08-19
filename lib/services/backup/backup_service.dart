import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/db/app_database.dart';
import '../../core/db/settings_repository.dart';
import '../../core/db/task_repository.dart';
import '../../core/utils/json_backup.dart';
import '../task_coordinator.dart';

/// 恢复结果。
class RestoreResult {
  const RestoreResult({required this.imported, required this.skipped});

  /// 成功导入数量。
  final int imported;

  /// 因 ID 冲突跳过的数量（重复任务判断）。
  final int skipped;
}

/// 本地备份服务：JSON 导出/恢复（SAF 文件选择器，免存储权限，纯本机）。
class BackupService {
  BackupService({
    required this.database,
    required this.taskRepository,
    required this.settingsRepository,
    required this.coordinator,
  });

  final AppDatabase database;
  final TaskRepository taskRepository;
  final SettingsRepository settingsRepository;
  final TaskCoordinator coordinator;

  /// 导出全部任务为 JSON 文件，返回保存路径（取消返回 null）。
  Future<String?> exportToFile() async {
    final json = const JsonEncoder.withIndent('  ').convert(BackupEnvelope.encode(
      taskRepository.all(),
      settingsRepository.settings,
    ));
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return FilePicker.platform.saveFile(
      dialogTitle: '导出备份',
      fileName: '离线语音提醒备份_$stamp.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
  }

  /// 从本地 JSON 文件恢复任务（冲突按 ID 跳过），返回结果；取消返回 null。
  Future<RestoreResult?> importFromFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      dialogTitle: '选择备份文件',
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final data = BackupEnvelope.decode(utf8.decode(bytes));
    var imported = 0;
    var skipped = 0;
    final existingIds = taskRepository.all().map((t) => t.id).toSet();
    for (final task in data.tasks) {
      if (existingIds.contains(task.id)) {
        skipped++;
        continue;
      }
      existingIds.add(task.id);
      // 复用保存管线：写库 + 通知调度 + 日历同步
      await coordinator.save(task);
      imported++;
    }
    // 恢复设置（任务数据不覆盖，设置直接应用）
    await settingsRepository.update((s) {
      s
        ..defaultAdvanceMinutes = data.settings.defaultAdvanceMinutes
        ..calendarSyncEnabled = data.settings.calendarSyncEnabled
        ..notificationSound = data.settings.notificationSound
        ..notificationVibrate = data.settings.notificationVibrate
        ..asrSilenceSeconds = data.settings.asrSilenceSeconds
        ..asrMaxRecordSeconds = data.settings.asrMaxRecordSeconds
        ..deleteCalendarDefault = data.settings.deleteCalendarDefault
        ..voiceAutoEdit = data.settings.voiceAutoEdit
        ..expiredTaskNotify = data.settings.expiredTaskNotify
        ..sortByStartAsc = data.settings.sortByStartAsc;
    });
    return RestoreResult(imported: imported, skipped: skipped);
  }

  /// 备份校验（不导入）：读取文件并统计，供 UI 展示预览。
  static Future<(int taskCount, String? exportedAt)?> peek(String jsonString) {
    try {
      final data = BackupEnvelope.decode(jsonString);
      return Future.value((data.tasks.length, data.exportedAt));
    } catch (_) {
      return Future.value(null);
    }
  }
}
