import sys
import numpy as np
import soundfile as sf

input_path = "/Users/daisy/Library/Application Support/AudioKit/audio/timbre/jiajia-1.wav"
output_path = "/Users/daisy/Audio/jiajia-1.wav"

db_change = -6.0
gain = 10 ** (db_change / 20.0)

info = sf.info(input_path)
data, samplerate = sf.read(input_path, dtype="float64", always_2d=True)
data = data * gain

sf.write(output_path, data, samplerate, subtype=info.subtype)

print(f"写入 {output_path}")
print(f"采样率 {samplerate}, 声道数 {data.shape[1]}, 子格式 {info.subtype}, 增益 {gain:.6f} ({db_change} dB)")
