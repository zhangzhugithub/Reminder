import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/strings.dart';
import '../../services/asr/model_manager.dart';
import '../../services/backup/backup_service.dart';
import '../../state/app_state.dart';
import '../../state/task_list_state.dart';

/// 备份与恢复 + 数据管理页（需求 5.2 / 5.3 / 2.4 清理过期任务）。
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  Future<void> _export(BuildContext context) async {
    final backup = context.read<BackupService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await backup.exportToFile();
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text('备份已导出：$path')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final backup = context.read<BackupService>();
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await backup.importFromFile();
      if (result == null) return; // 用户取消
      if (!context.mounted) return; // 期间页面可能已被销毁
      context.read<TaskListState>().refresh();
      messenger.showSnackBar(SnackBar(
        content: Text(
            '恢复完成：导入 ${result.imported} 个任务${result.skipped > 0 ? '，跳过重复 ${result.skipped} 个' : ''}'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('将删除离线语音模型缓存（下次语音录入时自动从安装包恢复），确定清理吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(S.ok),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ModelManager.clearCache();
    messenger.showSnackBar(const SnackBar(content: Text('缓存已清理')));
  }

  Future<void> _clearExpired(BuildContext context) async {
    final appState = context.read<AppState>();
    final count = appState.taskRepository
        .sortedByStart()
        .where((t) => t.isExpiredAt(DateTime.now()))
        .length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已过期的单次任务')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理已过期任务'),
        content: Text('将删除 $count 个已过期的单次任务（重复任务不受影响），确定清理吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(S.ok),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed =
        await appState.taskRepository.clearExpired(DateTime.now());
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已清理 $removed 个任务')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsBackup)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('导出备份'),
            subtitle: const Text('将全部任务导出为 JSON 文件，保存至本机存储'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('恢复备份'),
            subtitle: const Text('选择本地 JSON 文件导入（重复任务自动跳过）'),
            onTap: () => _import(context),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '备份文件仅存本机，不会自动上传。应用卸载会清除全部数据，请提前备份。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清理缓存'),
            subtitle: const Text('清理语音识别模型等临时缓存'),
            onTap: () => _clearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('清理已过期任务'),
            subtitle: const Text('一键删除全部已过期的单次任务'),
            onTap: () => _clearExpired(context),
          ),
        ],
      ),
    );
  }
}
