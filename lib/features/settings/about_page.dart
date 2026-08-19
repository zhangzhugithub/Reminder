import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import '../../l10n/strings.dart';
import '../../services/asr/model_manager.dart';
import '../../state/app_state.dart';

/// 关于页（需求 6.6）：离线声明、功能说明、已知限制、重置 App。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  ModelStatus _modelStatus = ModelStatus.unknown;

  @override
  void initState() {
    super.initState();
    ModelManager.status().then((s) {
      if (mounted) setState(() => _modelStatus = s);
    });
  }

  Future<void> _resetApp() async {
    final appState = context.read<AppState>();
    var deleteCalendar = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('重置应用'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('将清除全部本地数据（任务、设置），且无法恢复。建议先导出备份。'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('同时删除系统日历中的专属日历'),
                value: deleteCalendar,
                onChanged: (v) => setState(() => deleteCalendar = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('重置'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    await appState.notificationScheduler.cancelAll();
    if (deleteCalendar) {
      try {
        await appState.calendarService.deleteAppCalendar();
      } catch (_) {}
    }
    await appState.database.resetAll();
    await ModelManager.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置，请重新启动应用')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = sherpaOnnxVersion;
    final modelText = switch (_modelStatus) {
      ModelStatus.ready => '已就绪${version.isEmpty ? '' : '（$version）'}',
      ModelStatus.missing => '缺失',
      _ => '检测中…',
    };
    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsAbout)),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.alarm, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Center(
            child: Text(S.appName, style: TextStyle(fontSize: 20)),
          ),
          const Center(child: Text('版本 1.0.0')),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.cloud_off),
            title: Text('完全离线'),
            subtitle: Text(
              '本应用无任何网络访问：不声明网络权限、无统计/广告/埋点 SDK，'
              '所有运算与存储均在本地完成，不采集、不上传任何数据。',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('离线语音识别'),
            subtitle: Text('本地模型（sherpa-onnx 普通话）：$modelText'),
          ),
          const ListTile(
            leading: Icon(Icons.lightbulb_outline),
            title: Text('功能说明'),
            subtitle: Text(
              '语音/文本录入 → 本地规则解析时间 → 任务保存（本地数据库 + 系统定时通知 + 系统日历同步）。'
              '支持重复任务（每天/每周/每月，月末自动钳制）、提前提醒、JSON 本地备份。',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('已知系统限制'),
            subtitle: Text(
              '· iOS 最多保留 64 条待处理通知，循环任务在打开 App 时自动补排；\n'
              '· 部分 Android 厂商存在后台查杀，无法 100% 保证后台唤醒（行业通用限制）；\n'
              '· Android 12+ 精确闹钟为可撤销权限，被回收后自动降级；\n'
              '· 日历同步为单向（App 为主数据源），系统日历中的手动修改不会反向更新。',
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '清除全部本地数据（重置应用）',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _resetApp,
          ),
        ],
      ),
    );
  }
}

/// sherpa-onnx 版本号（空则未初始化，不显示）。
String get sherpaOnnxVersion {
  try {
    return getVersion();
  } catch (_) {
    return '';
  }
}
