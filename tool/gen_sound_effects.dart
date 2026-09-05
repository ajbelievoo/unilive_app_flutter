// One-off generator: synthesizes short WAV sound effects + ambient loops
// into assets/sounds/. Run with: dart run tool/gen_sound_effects.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

void writeWav(String path, List<double> samples) {
  final data = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data[i] = v;
  }
  final byteData = data.buffer.asUint8List();
  final header = ByteData(44);
  // RIFF header
  header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); // RIFF
  header.setUint32(4, 36 + byteData.length, Endian.little);
  header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); // WAVE
  header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20); // fmt
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits
  header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61); // data
  header.setUint32(40, byteData.length, Endian.little);
  File(path).writeAsBytesSync([
    ...header.buffer.asUint8List(),
    ...byteData,
  ]);
  stdout.writeln('wrote $path (${samples.length} samples)');
}

double _noise(Random r) => r.nextDouble() * 2 - 1;

/// Exponential decay envelope.
double _decay(double t, double halfLife) => pow(0.5, t / halfLife).toDouble();

List<double> _silence(double seconds) => List.filled((seconds * sampleRate).round(), 0.0);

void _mixInto(List<double> dst, List<double> src, double startSeconds, [double gain = 1.0]) {
  final start = (startSeconds * sampleRate).round();
  for (var i = 0; i < src.length && start + i < dst.length; i++) {
    dst[start + i] += src[i] * gain;
  }
}

/// A short filtered noise "clap".
List<double> _clap(Random r) {
  final len = (0.12 * sampleRate).round();
  final out = List<double>.filled(len, 0);
  var lp = 0.0;
  for (var i = 0; i < len; i++) {
    final t = i / sampleRate;
    lp = lp * 0.7 + _noise(r) * 0.3; // crude lowpass
    out[i] = lp * 2.2 * _decay(t, 0.03);
  }
  return out;
}

List<double> genApplause() {
  final r = Random(7);
  final out = _silence(1.6);
  var t = 0.0;
  while (t < 1.5) {
    _mixInto(out, _clap(r), t, 0.5 + r.nextDouble() * 0.5);
    t += 0.03 + r.nextDouble() * 0.07;
  }
  return out;
}

List<double> genLaughter() {
  // "ha-ha-ha" — descending square-ish pulses.
  final out = _silence(1.2);
  var t = 0.0;
  var freq = 340.0;
  for (var p = 0; p < 5; p++) {
    final len = (0.14 * sampleRate).round();
    final pulse = List<double>.filled(len, 0);
    for (var i = 0; i < len; i++) {
      final tt = i / sampleRate;
      final s = sin(2 * pi * freq * tt) + 0.5 * sin(2 * pi * freq * 2 * tt);
      pulse[i] = (s > 0 ? 0.5 : -0.5) * 0.55 * _decay(tt, 0.09) * (0.6 + 0.4 * sin(2 * pi * 9 * tt));
    }
    _mixInto(out, pulse, t);
    t += 0.19;
    freq *= 0.9;
  }
  return out;
}

List<double> genDrumRoll() {
  final r = Random(3);
  final out = _silence(1.4);
  var t = 0.0;
  var gap = 0.09;
  while (t < 1.25) {
    final len = (0.09 * sampleRate).round();
    final thump = List<double>.filled(len, 0);
    for (var i = 0; i < len; i++) {
      final tt = i / sampleRate;
      final f = 110 - 60 * (tt / 0.09);
      thump[i] = sin(2 * pi * f * tt) * _decay(tt, 0.025) + _noise(r) * 0.08 * _decay(tt, 0.01);
    }
    _mixInto(out, thump, t, 0.9);
    t += gap;
    gap = max(0.028, gap * 0.88);
  }
  return out;
}

List<double> genWhistle() {
  // Referee whistle: ~2.6kHz with trill modulation, two blasts.
  final out = _silence(1.0);
  for (var blast = 0; blast < 2; blast++) {
    final start = blast * 0.5;
    final len = (0.4 * sampleRate).round();
    for (var i = 0; i < len && (start * sampleRate).round() + i < out.length; i++) {
      final t = i / sampleRate;
      final trill = 1 + 0.25 * sin(2 * pi * 28 * t);
      final env = min(1.0, t / 0.02) * _decay(t, 0.30);
      out[(start * sampleRate).round() + i] += sin(2 * pi * 2600 * trill * t) * 0.6 * env;
    }
  }
  return out;
}

List<double> genCricket() {
  // Chirp pulses at ~4.5kHz.
  final out = _silence(1.4);
  var t = 0.0;
  while (t < 1.3) {
    final len = (0.05 * sampleRate).round();
    final chirp = List<double>.filled(len, 0);
    for (var i = 0; i < len; i++) {
      final tt = i / sampleRate;
      final f = 4200 + 600 * sin(2 * pi * 30 * tt);
      chirp[i] = sin(2 * pi * f * tt) * 0.4 * sin(pi * tt / 0.05);
    }
    _mixInto(out, chirp, t);
    t += 0.11;
  }
  return out;
}

List<double> genTada() {
  // Rising major arpeggio: C5 E5 G5 C6 with shimmer.
  final out = _silence(1.3);
  const notes = [523.25, 659.25, 783.99, 1046.5];
  for (var n = 0; n < notes.length; n++) {
    final start = n * 0.16;
    final len = (0.7 * sampleRate).round();
    final note = List<double>.filled(len, 0);
    for (var i = 0; i < len; i++) {
      final t = i / sampleRate;
      note[i] = (sin(2 * pi * notes[n] * t) * 0.5 +
              sin(2 * pi * notes[n] * 2 * t) * 0.2 +
              sin(2 * pi * notes[n] * 3 * t) * 0.08) *
          _decay(t, 0.22);
    }
    _mixInto(out, note, start, 0.55);
  }
  return out;
}

List<double> genBoo() {
  // Low descending "boo" — two saw-ish tones.
  final out = _silence(1.1);
  final len = (1.0 * sampleRate).round();
  for (var i = 0; i < len; i++) {
    final t = i / sampleRate;
    final f = 220 - 90 * t;
    final s = (2 * (t * f - (t * f).floorToDouble()) - 1); // saw
    out[i] = s * 0.35 * min(1.0, t / 0.05) * _decay(t, 0.6);
  }
  return out;
}

List<double> genCheer() {
  // Crowd swell: noise with rising/falling envelope + high sparkle.
  final r = Random(11);
  final len = (1.5 * sampleRate).round();
  final out = List<double>.filled(len, 0);
  var lp = 0.0;
  for (var i = 0; i < len; i++) {
    final t = i / sampleRate;
    lp = lp * 0.85 + _noise(r) * 0.15;
    final env = sin(pi * (t / 1.5)).clamp(0.0, 1.0);
    out[i] = (lp * 2.4 + _noise(r) * 0.12) * env * 0.8;
  }
  return out;
}

List<double> _loopableNoise(Random r, double seconds, double lpFactor) {
  final len = (seconds * sampleRate).round();
  final out = List<double>.filled(len, 0);
  var lp = 0.0;
  for (var i = 0; i < len; i++) {
    lp = lp * lpFactor + _noise(r) * (1 - lpFactor);
    out[i] = lp;
  }
  // Crossfade the tail into the head for seamless looping.
  final fade = (0.3 * sampleRate).round();
  for (var i = 0; i < fade; i++) {
    final a = i / fade;
    out[i] = out[i] * a + out[len - fade + i] * (1 - a);
  }
  return out.sublist(0, len - fade);
}

List<double> genRain() => _loopableNoise(Random(21), 3.0, 0.90).map((v) => v * 1.6).toList();

List<double> genCafe() => _loopableNoise(Random(22), 3.0, 0.985).map((v) => v * 3.0).toList();

List<double> genOcean() {
  final base = _loopableNoise(Random(23), 6.0, 0.95);
  for (var i = 0; i < base.length; i++) {
    final t = i / sampleRate;
    base[i] = base[i] * 1.8 * (0.55 + 0.45 * sin(2 * pi * 0.14 * t));
  }
  return base;
}

List<double> genForest() {
  final r = Random(24);
  final base = _loopableNoise(r, 5.0, 0.97).map((v) => v * 1.4).toList();
  // Sprinkle bird chirps.
  var t = 0.2;
  while (t < 4.4) {
    final len = (0.12 * sampleRate).round();
    final chirp = List<double>.filled(len, 0);
    final f0 = 2400 + r.nextDouble() * 1600;
    for (var i = 0; i < len; i++) {
      final tt = i / sampleRate;
      final f = f0 + 500 * sin(2 * pi * 18 * tt);
      chirp[i] = sin(2 * pi * f * tt) * 0.14 * sin(pi * tt / 0.12);
    }
    _mixInto(base, chirp, t);
    t += 0.5 + r.nextDouble() * 0.9;
  }
  return base;
}

List<double> genCampfire() {
  final r = Random(25);
  final base = _loopableNoise(r, 4.0, 0.96).map((v) => v * 1.8).toList();
  // Crackle impulses.
  for (var i = 0; i < base.length; i++) {
    if (r.nextDouble() < 0.0006) {
      final crackleLen = min(60, base.length - i);
      for (var j = 0; j < crackleLen; j++) {
        base[i + j] += _noise(r) * 0.5 * _decay(j / sampleRate, 0.0012);
      }
    }
  }
  return base;
}

List<double> genNight() {
  final base = _loopableNoise(Random(26), 4.0, 0.985).map((v) => v * 2.2).toList();
  var t = 0.0;
  final r = Random(27);
  while (t < 3.5) {
    final len = (0.05 * sampleRate).round();
    final chirp = List<double>.filled(len, 0);
    for (var i = 0; i < len; i++) {
      final tt = i / sampleRate;
      chirp[i] = sin(2 * pi * 4300 * tt) * 0.10 * sin(pi * tt / 0.05);
    }
    _mixInto(base, chirp, t);
    t += 0.13 + r.nextDouble() * 0.25;
  }
  return base;
}

void main() {
  Directory('assets/sounds').createSync(recursive: true);
  writeWav('assets/sounds/fx_applause.wav', genApplause());
  writeWav('assets/sounds/fx_laughter.wav', genLaughter());
  writeWav('assets/sounds/fx_drums.wav', genDrumRoll());
  writeWav('assets/sounds/fx_whistle.wav', genWhistle());
  writeWav('assets/sounds/fx_cricket.wav', genCricket());
  writeWav('assets/sounds/fx_tada.wav', genTada());
  writeWav('assets/sounds/fx_boo.wav', genBoo());
  writeWav('assets/sounds/fx_cheer.wav', genCheer());
  writeWav('assets/sounds/amb_rain.wav', genRain());
  writeWav('assets/sounds/amb_cafe.wav', genCafe());
  writeWav('assets/sounds/amb_ocean.wav', genOcean());
  writeWav('assets/sounds/amb_forest.wav', genForest());
  writeWav('assets/sounds/amb_campfire.wav', genCampfire());
  writeWav('assets/sounds/amb_night.wav', genNight());
}
