"""
紅色風暴 戰鬥配樂產生器（純 numpy 程序合成，原創、無授權問題）

設計目標（玩家回饋「音樂有點煩躁」）：
  - 偏暗、柔和：所有聲部都經過低通，沒有刺耳的高頻 hi-hat，頻譜重心約 1 kHz
  - 長度約 3 分鐘、段落有起伏（前奏 → 主段 → 間奏 → 高潮 → 尾聲），三首輪播不會一直重複
  - 44.1 kHz 立體聲，輸出 WAV 後由 ffmpeg 轉成 OGG（每首約 2～3 MB）

用法：python tools/music_generator.py      → 產生 audio/music/battle_1..3.ogg
"""

import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "music")


def midi(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def lowpass(sig, fc, order=2):
    """頻域巴特沃斯式低通（整段處理，避免逐樣本迴圈）"""
    n = len(sig)
    sp = np.fft.rfft(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    sp *= 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))
    return np.fft.irfft(sp, n)


def highpass(sig, fc, order=2):
    n = len(sig)
    sp = np.fft.rfft(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-6
    sp *= 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order))
    return np.fft.irfft(sp, n)


def env(n, a, r, sustain=1.0):
    """attack / release 秒數的包絡"""
    e = np.full(n, sustain, dtype=np.float64)
    na = min(n, int(a * SR))
    nr = min(n - na, int(r * SR))
    if na > 0:
        e[:na] = np.linspace(0, sustain, na)
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def saw(freq, n, phase=0.0):
    t = np.arange(n) / SR
    return 2.0 * ((t * freq + phase) % 1.0) - 1.0


def tri(freq, n):
    return 2.0 * np.abs(saw(freq, n)) - 1.0


def sine(freq, n):
    return np.sin(2 * np.pi * freq * np.arange(n) / SR)


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.bus = {k: np.zeros((self.n, 2)) for k in ["pad", "bass", "drum", "arp", "lead"]}

    def add(self, bus, start, sig, pan=0.0):
        i = int(start * SR)
        if i >= self.n:
            return
        sig = sig[: self.n - i]
        l = np.cos((pan + 1) * np.pi / 4)
        r = np.sin((pan + 1) * np.pi / 4)
        self.bus[bus][i:i + len(sig), 0] += sig * l
        self.bus[bus][i:i + len(sig), 1] += sig * r


# ───────────────────────── 樂器 ─────────────────────────
def pad_chord(notes, dur):
    n = int(dur * SR)
    out = np.zeros(n)
    for m in notes:
        f = midi(m)
        for det in (-0.006, 0.0, 0.007):
            out += saw(f * (1 + det), n, phase=np.random.rand()) * 0.33
        out += sine(f / 2, n) * 0.25
    return out * env(n, 1.6, 2.2) / len(notes)


def bass_note(m, dur):
    n = int(dur * SR)
    f = midi(m)
    s = sine(f, n) + 0.35 * saw(f, n) + 0.3 * sine(f / 2, n)
    return s * env(n, 0.01, dur * 0.6) * np.exp(-np.arange(n) / SR * 2.0)


def kick(dur=0.45):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 46 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7.5)


def snare(dur=0.28):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = np.random.randn(n)
    body = sine(180, n) * np.exp(-t * 30)
    return (noise * np.exp(-t * 16) * 0.5 + body * 0.6) * 0.55


def tom(m, dur=0.7):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi(m) * (1 + 0.4 * np.exp(-t * 18))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 4.5)


def pluck(m, dur):
    n = int(dur * SR)
    f = midi(m)
    s = tri(f, n) * 0.7 + sine(f * 2, n) * 0.15
    return s * env(n, 0.005, dur * 0.8) * np.exp(-np.arange(n) / SR * 3.0)


def horn(m, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi(m) * (1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t - 0.4, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = (2 * ((ph / (2 * np.pi)) % 1.0) - 1) * 0.6 + np.sin(ph) * 0.4
    return s * env(n, 0.35, 0.8)


# ───────────────────────── 曲目 ─────────────────────────
def compose(seed, root, bpm, prog, scale, arp_pat, lead_motif, sections):
    np.random.seed(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total_bars = sum(b for _, b in sections)
    tr = Track(total_bars * bar + 4.0)
    t0 = 0.0
    bar_i = 0
    for name, nbars in sections:
        for b in range(nbars):
            st = t0 + b * bar
            deg = prog[(bar_i + b) % len(prog)]
            chord_root = root + scale[deg % len(scale)] + 12 * (deg // len(scale))
            third = root + scale[(deg + 2) % len(scale)] + 12 * ((deg + 2) // len(scale))
            fifth = root + scale[(deg + 4) % len(scale)] + 12 * ((deg + 4) // len(scale))
            # 襯底和弦：每小節換和弦（前奏/間奏延長）
            tr.add("pad", st, pad_chord([chord_root + 12, third + 12, fifth + 12], bar + 1.5), pan=0.0)
            if name in ("main", "climax", "build"):
                # 低音：八分音符脈動
                for k in range(8):
                    if k in (0, 3, 4, 6) or name == "climax":
                        tr.add("bass", st + k * beat / 2, bass_note(chord_root - 12, beat / 2 * 0.9))
            if name in ("main", "climax"):
                for k in range(4):
                    if k in (0, 2) or (name == "climax" and k == 3 and b % 2):
                        tr.add("drum", st + k * beat, kick() * 0.9)
                    if k in (1, 3):
                        tr.add("drum", st + k * beat, snare() * (0.5 if name == "main" else 0.65))
            if name == "build":
                tr.add("drum", st, kick() * 0.7)
                tr.add("drum", st + 2 * beat, kick() * 0.6)
            if name in ("intro", "break") and b % 2 == 0:
                tr.add("drum", st, tom(38, 1.6) * 0.7)
            if b == nbars - 1 and name in ("build", "main"):
                # 小節末的鼓組過門
                for k, m in enumerate([45, 43, 41, 40]):
                    tr.add("drum", st + 3 * beat + k * beat / 4, tom(m) * 0.55, pan=-0.3 + k * 0.2)
            if name in ("main", "climax", "break"):
                # 撥弦琶音
                for k, step in enumerate(arp_pat):
                    if step is None:
                        continue
                    m = chord_root + 12 + scale[step % len(scale)] + 12 * (step // len(scale))
                    tr.add("arp", st + k * beat / 2, pluck(m, beat * 0.9) * 0.5, pan=-0.45 if k % 2 else 0.45)
            if name in ("break", "climax") and b % 4 == 0:
                # 主旋律：四小節一句
                tt = st
                for deg_m, beats in lead_motif:
                    m = root + 24 + scale[deg_m % len(scale)] + 12 * (deg_m // len(scale)) - 12
                    tr.add("lead", tt, horn(m, beats * beat * 0.95) * 0.55, pan=0.1)
                    tt += beats * beat
        t0 += nbars * bar
        bar_i += nbars
    return tr


def master(tr, lp):
    mix = np.zeros((tr.n, 2))
    gains = {"pad": 0.55, "bass": 0.7, "drum": 0.85, "arp": 0.35, "lead": 0.45}
    for k, g in gains.items():
        for c in range(2):
            x = tr.bus[k][:, c]
            if k == "pad":
                x = lowpass(x, lp["pad"], 2)
            elif k == "bass":
                x = lowpass(x, 420, 3)
            elif k == "drum":
                x = lowpass(highpass(x, 35), 2600, 2)
            elif k == "arp":
                x = lowpass(x, lp["arp"], 2)
            elif k == "lead":
                x = lowpass(x, 1500, 2)
            mix[:, c] += x * g
    # 殘響：衰減噪音脈衝響應（FFT 摺積）
    ir_n = int(2.4 * SR)
    t = np.arange(ir_n) / SR
    for c in range(2):
        ir = np.random.randn(ir_n) * np.exp(-t * 2.6)
        ir = lowpass(ir, 2500, 2)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(tr.n + ir_n)))
        wet = np.fft.irfft(np.fft.rfft(mix[:, c], size) * np.fft.rfft(ir, size), size)[: tr.n]
        mix[:, c] = mix[:, c] * 0.82 + wet * 0.32
    # 淡入淡出
    fi = int(3.0 * SR)
    fo = int(6.0 * SR)
    mix[:fi] *= np.linspace(0, 1, fi)[:, None]
    mix[-fo:] *= np.linspace(1, 0, fo)[:, None]
    # 音量標準化到 -21 dBFS RMS，軟限幅
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= 10 ** (-21 / 20) / max(rms, 1e-9)
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    return mix


def save(name, mix):
    os.makedirs(OUT, exist_ok=True)
    wav_path = os.path.join(OUT, name + ".tmp.wav")
    with wave.open(wav_path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype("<i2").tobytes())
    ogg_path = os.path.join(OUT, name + ".ogg")
    import imageio_ffmpeg
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", wav_path,
                    "-c:a", "libvorbis", "-q:a", "3", ogg_path], check=True)
    os.remove(wav_path)
    return ogg_path


def analyze(mix):
    mono = mix.mean(1)
    seg = mono[SR * 20: SR * 80]
    sp = np.abs(np.fft.rfft(seg))
    f = np.fft.rfftfreq(len(seg), 1 / SR)
    return (sp * f).sum() / sp.sum(), sp[f > 3000].sum() / sp.sum()


MINOR = [0, 2, 3, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]

TRACKS = [
    # 1：緊繃推進（D 小調，88 BPM）
    dict(seed=11, root=50, bpm=88, prog=[0, 5, 2, 6], scale=MINOR,
         arp_pat=[0, 4, 7, 4, 2, 4, 7, None], lead_motif=[(4, 2), (3, 1), (2, 1), (0, 3), (None, 1)],
         lp={"pad": 1300, "arp": 2200},
         sections=[("intro", 8), ("build", 8), ("main", 16), ("break", 8), ("climax", 16), ("intro", 6)]),
    # 2：戰略沉思（A 小調，72 BPM，較安靜）
    dict(seed=22, root=45, bpm=72, prog=[0, 3, 5, 4], scale=DORIAN,
         arp_pat=[0, None, 4, None, 7, None, 4, 2], lead_motif=[(2, 2), (4, 2), (5, 1), (4, 1), (2, 2)],
         lp={"pad": 1100, "arp": 1800},
         sections=[("intro", 8), ("break", 8), ("main", 12), ("break", 8), ("climax", 12), ("intro", 6)]),
    # 3：鋼鐵進行曲（E 小調，96 BPM）
    dict(seed=33, root=52, bpm=96, prog=[0, 6, 5, 4], scale=MINOR,
         arp_pat=[0, 2, 4, 7, 4, 2, 0, None], lead_motif=[(0, 1), (2, 1), (4, 2), (5, 1), (4, 1), (2, 2)],
         lp={"pad": 1400, "arp": 2400},
         sections=[("intro", 6), ("build", 8), ("main", 16), ("break", 8), ("climax", 20), ("intro", 6)]),
]


def main():
    for i, cfg in enumerate(TRACKS, 1):
        lead = [(d if d is not None else 0, b) for d, b in cfg["lead_motif"]]
        cfg = dict(cfg, lead_motif=lead)
        lp = cfg.pop("lp")
        tr = compose(**cfg)
        mix = master(tr, lp)
        cent, hf = analyze(mix)
        path = save("battle_%d" % i, mix)
        print("battle_%d: %.0fs  centroid=%.0fHz  >3kHz=%.0f%%  %s (%.1f MB)" % (
            i, tr.n / SR, cent, hf * 100, os.path.basename(path), os.path.getsize(path) / 1e6))


if __name__ == "__main__":
    main()
