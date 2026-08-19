import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/settings_repository.dart';
import '../../core/nlp/parser.dart';
import '../../l10n/strings.dart';
import '../../services/asr/asr_service.dart';
import '../../state/task_list_state.dart';
import '../edit/task_edit_page.dart';
import 'asr_permission_page.dart';

/// 语音录入页：一键录音 → 离线识别 → 实时结果 → 解析进入任务编辑。
///
/// 录音仅 App 前台进行；静默超时（设置可配，默认 8 秒）自动结束。
class VoiceInputPage extends StatefulWidget {
  const VoiceInputPage({super.key});

  @override
  State<VoiceInputPage> createState() => _VoiceInputPageState();
}

class _VoiceInputPageState extends State<VoiceInputPage>
    with SingleTickerProviderStateMixin {
  late final AsrService _asr;
  late final AnimationController _idleAnim;

  @override
  void initState() {
    super.initState();
    _asr = AsrService(
      settingsRepository: context.read<SettingsRepository>(),
    );
    _asr.addListener(_onAsrChanged);
    _idleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _asr.removeListener(_onAsrChanged);
    _asr.dispose();
    _idleAnim.dispose();
    super.dispose();
  }

  void _onAsrChanged() {
    if (!mounted) return;
    if (_asr.phase == AsrPhase.finished && !_navigatingToEdit) {
      final autoEdit = _asr.settingsRepository.settings.voiceAutoEdit;
      if (autoEdit) {
        unawaited(_goToEdit());
      }
    }
    setState(() {});
  }

  bool _navigatingToEdit = false;

  Future<void> _goToEdit() async {
    _navigatingToEdit = true;
    final parsed =
        parseNaturalLanguage(_asr.finalText, now: DateTime.now());
    if (mounted && (!parsed.hasTime || !parsed.hasDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!parsed.hasDate && !parsed.hasTime
              ? S.noDateTimeHint
              : S.noTimeHint),
        ),
      );
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TaskEditPage(presets: TaskEditPresets.fromParsed(parsed)),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      context.read<TaskListState>().refresh();
      Navigator.of(context).pop();
    } else {
      _navigatingToEdit = false;
      setState(() {});
    }
  }

  Future<void> _start() async {
    await _asr.start();
    if (!mounted) return;
    if (_asr.error == AsrError.micPermissionDenied) {
      // 麦克风权限未授予 → 引导页
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AsrPermissionPage()),
      );
      if (granted == true && mounted) {
        await _asr.start();
      }
    } else if (_asr.phase == AsrPhase.error &&
        _asr.error == AsrError.modelMissing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(S.asrModelMissing)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.voiceInput)),
      body: Center(
        child: switch (_asr.phase) {
          AsrPhase.idle => _buildIdle(),
          AsrPhase.preparing => _buildPreparing(),
          AsrPhase.recording => _buildRecording(),
          AsrPhase.finished => _buildFinished(),
          AsrPhase.error => _buildError(),
        },
      ),
    );
  }

  // ---- 各阶段视图 ----

  Widget _buildIdle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.voiceIdleHint, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        _MicButton(onPressed: _start),
      ],
    );
  }

  Widget _buildPreparing() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(S.voicePreparing),
      ],
    );
  }

  Widget _buildRecording() {
    final partial = _asr.partialText;
    final showMeter = _asr.settingsRepository.settings.voiceVolumeMeter;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(S.voiceRecordingHint,
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        if (showMeter)
          _Waveform(
            amplitude: _asr.amplitude,
            idleAnim: _idleAnim,
          )
        else
          const SizedBox(height: 72),
        const SizedBox(height: 8),
        Text(
          _formatElapsed(_asr.elapsed),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            partial.isEmpty ? S.voiceListening : partial,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              iconSize: 36,
              tooltip: S.cancel,
              onPressed: () => _asr.cancel(),
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: 24),
            IconButton.filled(
              iconSize: 48,
              tooltip: S.voiceStop,
              onPressed: () => _asr.stop(),
              icon: const Icon(Icons.stop),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinished() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 56, color: Colors.green),
        const SizedBox(height: 12),
        Text(S.voiceFinished, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _asr.finalText,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _asr.cancel(),
              icon: const Icon(Icons.refresh),
              label: const Text(S.voiceRetry),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _goToEdit,
              icon: const Icon(Icons.arrow_forward),
              label: const Text(S.voiceNext),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    final (icon, title, detail) = switch (_asr.error) {
      AsrError.micPermissionDenied => (
          Icons.mic_off,
          S.asrErrorMicTitle,
          S.asrErrorMicDetail
        ),
      AsrError.modelMissing => (
          Icons.file_download_off,
          S.asrErrorModelTitle,
          S.asrErrorModelDetail
        ),
      AsrError.noSpeech => (
          Icons.hearing_disabled,
          S.asrErrorNoSpeechTitle,
          S.asrErrorNoSpeechDetail
        ),
      _ => (
          Icons.graphic_eq,
          S.asrErrorNoisyTitle,
          S.asrErrorNoisyDetail
        ),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(detail, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_asr.error == AsrError.micPermissionDenied)
              FilledButton.icon(
                onPressed: () async {
                  final granted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => const AsrPermissionPage()),
                  );
                  if (granted == true) await _asr.start();
                },
                icon: const Icon(Icons.settings),
                label: const Text(S.asrGoPermissions),
              )
            else
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh),
                label: const Text(S.retry),
              ),
          ],
        ),
      ],
    );
  }

  static String _formatElapsed(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onPressed,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          size: 48,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// 简易波形：振幅驱动 + 待机微动。
class _Waveform extends StatelessWidget {
  const _Waveform({required this.amplitude, required this.idleAnim});

  final double amplitude;
  final Animation<double> idleAnim;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: idleAnim,
      builder: (context, _) {
        final color = Theme.of(context).colorScheme.primary;
        return SizedBox(
          height: 72,
          width: 220,
          child: CustomPaint(
            painter: _WaveformPainter(
              color: color,
              amplitude: amplitude,
              idle: idleAnim.value,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.color,
    required this.amplitude,
    required this.idle,
  });

  final Color color;
  final double amplitude;
  final double idle;

  static const _barCount = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final gap = size.width / _barCount;
    for (var i = 0; i < _barCount; i++) {
      // 振幅驱动主高度；无振幅时以相位微动保持「收音中」的视觉反馈
      final phase = (i * 0.9).toDouble();
      final wobble = 0.15 + 0.1 * idle * (0.5 + 0.5 * (phase % 2));
      final h = size.height * (0.08 + 0.8 * amplitude + 0.1 * wobble);
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.amplitude != amplitude || old.idle != idle;
}
