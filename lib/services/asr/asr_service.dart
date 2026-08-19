import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../../core/db/settings_repository.dart';
import 'model_manager.dart';
import 'sherpa_engine.dart';

/// 识别失败分类（与需求 1.2 一致）。
enum AsrError { none, micPermissionDenied, modelMissing, noSpeech, noisy }

/// 语音录入会话阶段。
enum AsrPhase { idle, preparing, recording, finished, error }

/// 离线语音录入编排服务：麦克风 PCM 流 → sherpa 流式识别 → 实时部分结果。
///
/// 生命周期与语音录入页绑定；仅 App 前台使用（需求：后台禁止录音）。
class AsrService extends ChangeNotifier {
  AsrService({required this.settingsRepository});

  final SettingsRepository settingsRepository;

  final AudioRecorder _recorder = AudioRecorder();
  final SherpaEngine _engine = SherpaEngine();

  StreamSubscription<Uint8List>? _pcmSub;
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _tickTimer;
  Timer? _silenceTimer;
  Timer? _maxTimer;

  AsrPhase _phase = AsrPhase.idle;
  AsrError _error = AsrError.none;
  String _partialText = '';
  String _finalText = '';
  Duration _elapsed = Duration.zero;
  double _amplitude = 0;
  DateTime? _lastTextChange;
  bool _finished = false;

  AsrPhase get phase => _phase;
  AsrError get error => _error;
  String get partialText => _partialText;
  String get finalText => _finalText;
  Duration get elapsed => _elapsed;

  /// 归一化音量（0..1，波形展示用）。
  double get amplitude => _amplitude;

  // ---- 会话控制 ----

  /// 开始录音与识别。
  Future<void> start() async {
    if (_phase == AsrPhase.recording || _phase == AsrPhase.preparing) return;
    _resetState();
    _setPhase(AsrPhase.preparing);

    // 1. 模型就绪检查
    ModelStatus modelStatus;
    try {
      await ModelManager.ensureExtracted();
      modelStatus = ModelStatus.ready;
    } catch (_) {
      modelStatus = ModelStatus.missing;
    }
    if (modelStatus == ModelStatus.missing) {
      _error = AsrError.modelMissing;
      _setPhase(AsrPhase.error);
      return;
    }

    // 2. 麦克风权限
    if (!await _recorder.hasPermission()) {
      _error = AsrError.micPermissionDenied;
      _setPhase(AsrPhase.error);
      return;
    }

    // 3. 初始化引擎并开流
    try {
      if (!_engine.isReady) {
        await _engine.init(await ModelManager.modelDirPath());
      }
      _engine.startStream();
    } catch (_) {
      _error = AsrError.modelMissing;
      _setPhase(AsrPhase.error);
      return;
    }

    // 4. 开始录音（PCM16 流）
    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: SherpaEngine.sampleRate,
          numChannels: 1,
          autoGain: true,
        ),
      );
      _pcmSub = stream.listen(_onPcm, onError: (_) => _fail(AsrError.noisy));
      // 振幅流（波形展示；dBFS → 0..1 归一化）
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final db = amp.current;
        _amplitude = ((db + 60) / 60).clamp(0.0, 1.0);
      });
    } catch (_) {
      _error = AsrError.noisy;
      _setPhase(AsrPhase.error);
      return;
    }

    _setPhase(AsrPhase.recording);
    _startTimers();
  }

  /// 手动停止（正常结束：完成解码输出最终文本）。
  Future<void> stop() async {
    if (_phase != AsrPhase.recording) return;
    await _finishRecording();
  }

  /// 取消（丢弃结果）。
  Future<void> cancel() async {
    await _teardown();
    _resetState();
    _setPhase(AsrPhase.idle);
  }

  // ---- 内部 ----

  void _onPcm(Uint8List bytes) {
    if (_finished) return;
    _engine.acceptWaveform(_pcmToFloat32(bytes));
    final text = _engine.partialText;
    if (text != _partialText) {
      _partialText = text;
      _lastTextChange = DateTime.now();
      notifyListeners();
    }
    // sherpa 端点检测：静默自动结束
    if (_engine.isEndpoint && _lastTextChange != null) {
      _finishRecording();
    }
  }

  Float32List _pcmToFloat32(Uint8List bytes) {
    final samples = Float32List(bytes.length ~/ 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  void _startTimers() {
    final settings = settingsRepository.settings;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      notifyListeners();
    });
    // 静默超时自动结束（自最后一次新文本起算）
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final last = _lastTextChange;
      if (last != null &&
          DateTime.now().difference(last).inSeconds >=
              settings.asrSilenceSeconds) {
        _finishRecording();
      }
    });
    _maxTimer = Timer(
        Duration(seconds: settings.asrMaxRecordSeconds), _finishRecording);
  }

  Future<void> _finishRecording() async {
    if (_finished || _phase != AsrPhase.recording) return;
    _finished = true;
    _finalText = _engine.finish().trim();
    await _teardown();
    if (_finalText.isEmpty) {
      // 收音环境噪音过大 / 未识别到有效语音：简单区分——录音过短视为无语音
      _error = _elapsed.inSeconds < 2 ? AsrError.noSpeech : AsrError.noisy;
      _setPhase(AsrPhase.error);
    } else {
      _error = AsrError.none;
      _setPhase(AsrPhase.finished);
    }
  }

  Future<void> _teardown() async {
    _tickTimer?.cancel();
    _silenceTimer?.cancel();
    _maxTimer?.cancel();
    _tickTimer = _silenceTimer = _maxTimer = null;
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    _engine.dispose();
  }

  void _fail(AsrError e) {
    _error = e;
    _setPhase(AsrPhase.error);
    _teardown();
  }

  void _resetState() {
    _partialText = '';
    _finalText = '';
    _error = AsrError.none;
    _elapsed = Duration.zero;
    _amplitude = 0;
    _lastTextChange = null;
    _finished = false;
  }

  void _setPhase(AsrPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }
}
