import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart';

/// sherpa-onnx 流式识别引擎封装（离线，主 isolate 运行）。
///
/// FFI 状态为 per-isolate，引擎生命周期与一次录音会话绑定：
/// init → createStream → acceptWaveform 循环 → inputFinished → free。
class SherpaEngine {
  OnlineRecognizer? _recognizer;
  OnlineStream? _stream;

  /// bindings 仅需初始化一次（进程内静态）。
  static bool _bindingsInitialized = false;

  static const sampleRate = 16000;
  static const featureDim = 80;

  /// 初始化识别器（加载模型，约需数百毫秒）。
  Future<void> init(String modelDir) async {
    if (!_bindingsInitialized) {
      // initBindings 会自动加载平台原生库
      initBindings();
      _bindingsInitialized = true;
    }
    _recognizer = OnlineRecognizer(
      OnlineRecognizerConfig(
        feat: const FeatureConfig(
            sampleRate: sampleRate, featureDim: featureDim),
        model: OnlineModelConfig(
          transducer: OnlineTransducerModelConfig(
            encoder: '$modelDir/encoder.int8.onnx',
            decoder: '$modelDir/decoder.onnx',
            joiner: '$modelDir/joiner.int8.onnx',
          ),
          tokens: '$modelDir/tokens.txt',
          modelType: 'zipformer2',
          numThreads: 2,
          provider: 'cpu',
          debug: false,
        ),
        decodingMethod: 'greedy_search',
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20,
      ),
    );
  }

  bool get isReady => _recognizer != null;

  /// 开始新的识别流。
  void startStream() {
    final recognizer = _recognizer;
    if (recognizer == null) {
      throw StateError('SherpaEngine 未初始化');
    }
    _stream = recognizer.createStream();
  }

  /// 喂入 PCM 样本（float32，16kHz），并解码就绪帧。
  void acceptWaveform(Float32List samples) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return;
    stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
  }

  /// 当前部分识别结果（实时展示）。
  String get partialText {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return '';
    return recognizer.getResult(stream).text;
  }

  /// 是否检测到语音端点（静默结束）。
  bool get isEndpoint {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return false;
    return recognizer.isEndpoint(stream);
  }

  /// 通知输入结束并完成剩余解码（停止录音后调用）。
  String finish() {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null) return '';
    stream.inputFinished();
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    return recognizer.getResult(stream).text;
  }

  /// 释放 FFI 资源。
  void dispose() {
    _stream?.free();
    _stream = null;
    _recognizer?.free();
    _recognizer = null;
  }
}
