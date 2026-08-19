import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/settings_repository.dart';
import '../../l10n/strings.dart';

/// 外观设置页（需求 6.4）：浅色/深色模式、任务列表排序方式。
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsRepo = context.watch<SettingsRepository>();
    final s = settingsRepo.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsAppearance)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('主题模式'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('跟随系统')),
                ButtonSegment(value: 1, label: Text('浅色')),
                ButtonSegment(value: 2, label: Text('深色')),
              ],
              selected: {s.themeModeIndex},
              onSelectionChanged: (selection) => settingsRepo
                  .update((s) => s.themeModeIndex = selection.first),
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.sort_by_alpha),
            title: const Text('按开始时间升序排序'),
            subtitle: const Text('关闭后按创建时间倒序排列'),
            value: s.sortByStartAsc,
            onChanged: (v) =>
                settingsRepo.update((s) => s.sortByStartAsc = v),
          ),
        ],
      ),
    );
  }
}
