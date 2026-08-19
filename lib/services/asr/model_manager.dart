import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 离线 ASR 模型状态。
enum ModelStatus { unknown, ready, missing, extracting }

/// 离线模型管理：把 assets/models 中的模型文件解压（拷贝）到应用私有目录。
///
/// sherpa-onnx 需要真实文件系统路径加载模型（Flutter assets 压缩打包无法直接使用），
/// 首次运行（或文件缺失时）从 assets 拷贝到 documents/models/。
class ModelManager {
  ModelManager._();

  static const assetDir = 'assets/models';

  /// 模型文件名（与 tool/download_model.* 脚本产物一致）。
  static const modelFiles = [
    'encoder.int8.onnx',
    'decoder.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  ];

  /// 模型文件在应用文档目录中的路径。
  static Future<String> modelDirPath() async =>
      (await ensureExtracted()).path;

  /// 确保模型文件就绪，返回模型目录。
  ///
  /// 任一文件缺失或为空时从 assets 重新拷贝（154MB 主模型，仅首次/修复时执行）。
  static Future<Directory> ensureExtracted() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    var allPresent = true;
    for (final name in modelFiles) {
      final file = File(p.join(dir.path, name));
      if (!file.existsSync() || file.lengthSync() <= 0) {
        allPresent = false;
        break;
      }
    }
    if (!allPresent) {
      for (final name in modelFiles) {
        final data = await rootBundle.load('$assetDir/$name');
        final file = File(p.join(dir.path, name));
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
    }
    return dir;
  }

  /// 当前模型状态（供设置/关于页展示）。
  static Future<ModelStatus> status() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'models'));
      if (!dir.existsSync()) return ModelStatus.missing;
      for (final name in modelFiles) {
        final file = File(p.join(dir.path, name));
        if (!file.existsSync() || file.lengthSync() <= 0) {
          return ModelStatus.missing;
        }
      }
      return ModelStatus.ready;
    } catch (_) {
      return ModelStatus.missing;
    }
  }

  /// 清空模型缓存（设置页「清理缓存」使用；下次语音录入时自动恢复）。
  static Future<void> clearCache() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models'));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
