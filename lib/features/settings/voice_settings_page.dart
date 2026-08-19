import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/settings_repository.dart';
import '../../l10n/strings.dart';

/// 语音设置页（需求 6.1）。
class VoiceSettingsPage extends StatelessWidget {
  const VoiceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsRepo = context.watch<SettingsRepository>();
    final s = settingsRepo.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsVoice)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text('静默自动结束：${s.asrSilenceSeconds} 秒'),
            subtitle: const Text('停止说话超过该时长自动结束录音'),
          ),
          Slider(
            value: s.asrSilenceSeconds.toDouble(),
            min: 3,
            max: 15,
            divisions: 12,
            label: '${s.asrSilenceSeconds} 秒',
            onChanged: (v) => settingsRepo.update(
                (s) => s.asrSilenceSeconds = v.round()),
          ),
          ListTile(
            leading: const Icon(Icons.av_timer),
            title: Text('最长录音：${s.asrMaxRecordSeconds} 秒'),
            subtitle: const Text('到达时长自动结束，防止误触长时间录音'),
          ),
          Slider(
            value: s.asrMaxRecordSeconds.toDouble(),
            min: 15,
            max: 180,
            divisions: 33,
            label: '${s.asrMaxRecordSeconds} 秒',
            onChanged: (v) => settingsRepo.update(
                (s) => s.asrMaxRecordSeconds = v.round()),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.edit_note),
            title: const Text('识别结果自动进入编辑页面'),
            subtitle: const Text('关闭后识别完成停留在结果页，手动确认后再编辑'),
            value: s.voiceAutoEdit,
            onChanged: (v) =>
                settingsRepo.update((s) => s.voiceAutoEdit = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq),
            title: const Text('录音音量提示（波形）'),
            subtitle: const Text('录音时展示音量波形动画'),
            value: s.voiceVolumeMeter,
            onChanged: (v) =>
                settingsRepo.update((s) => s.voiceVolumeMeter = v),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '语音识别使用本地离线模型（sherpa-onnx），全程不联网，'
              '识别结果仅在设备本地处理。',
            ),
          ),
        ],
      ),
    );
  }
}
