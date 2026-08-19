#!/usr/bin/env bash
# 下载离线语音识别模型（普通话流式识别，int8 量化，约 159MB）
# 依次尝试 GitHub Release → HuggingFace → hf-mirror（国内镜像）
# 解压到 assets/models/（已 gitignore，随 App 打包）
set -euo pipefail

MODEL="sherpa-onnx-streaming-zipformer-zh-int8-2025-06-30"
FILE="$MODEL.tar.bz2"
URLS=(
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$FILE"
  "https://huggingface.co/csukuangfj/$MODEL/resolve/main/$FILE"
  "https://hf-mirror.com/csukuangfj/$MODEL/resolve/main/$FILE"
)

cd "$(dirname "$0")/.."
mkdir -p assets/models tmp_model

downloaded=0
for url in "${URLS[@]}"; do
  echo "尝试下载: $url"
  if curl -L --fail --connect-timeout 20 -o "tmp_model/$FILE" "$url"; then
    downloaded=1
    break
  fi
  echo "该源失败，尝试下一个…"
done

if [ "$downloaded" -ne 1 ]; then
  echo "错误：全部下载源均失败，请检查网络后重试。" >&2
  rm -rf tmp_model
  exit 1
fi

echo "解压中…"
tar -xjf "tmp_model/$FILE" -C tmp_model

# 拷贝模型文件（目录结构兼容两种解压布局）
if [ -d "tmp_model/$MODEL" ]; then
  cp "tmp_model/$MODEL"/* assets/models/
else
  cp tmp_model/* assets/models/
fi

rm -rf tmp_model
echo "完成：assets/models/ 内容如下"
ls -la assets/models/
