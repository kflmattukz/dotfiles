# RIFE AI motion interpolation for mpv (loaded by the [rife] profile in mpv.conf).
# Plugin: styler00dollar/VapourSynth-RIFE-ncnn-Vulkan, installed by `mpv-rife-setup`
# into ~/.local/lib/vapoursynth-flatpak/rife/ (librife.so + models/).
import os
import vapoursynth as vs

core = vs.core

# ---------- settings ----------
MODEL = 70          # 70 = v4.25-lite (fastest), 65 = v4.22-lite, 23 = v4.6 (classic realtime pick)
TARGET_FPS = 0      # 0 = match the display refresh (60 on the laptop panel, 144 on a 144 Hz screen); or e.g. 144
MAX_HEIGHT = 540    # RIFE runs at most at this height, mpv upscales after (the iGPU can't do 1080p). 0 = native
UHD = False         # RIFE's own half-res flow: faster, a bit less accurate. Try True before lowering MAX_HEIGHT
GPU_THREADS = 2
SCENE_CUT = 0.12    # skip interpolating across cuts when luma diff > this (0 = off)
# ------------------------------

PLUGIN = os.path.expanduser("~/.local/lib/vapoursynth-flatpak/rife/librife.so")


def fraction(fps):
    for num, den in ((24000, 1001), (30000, 1001), (60000, 1001)):
        if abs(fps - num / den) < 0.01:
            return num, den
    if abs(fps - round(fps)) < 0.05:  # e.g. a 60.02 Hz panel -> 60
        return round(fps), 1
    return round(fps * 1000), 1000


clip = video_in  # noqa: F821 (globals injected by mpv)
src_fps = container_fps if container_fps > 0 else 24000 / 1001  # noqa: F821
target = TARGET_FPS or display_fps or 60  # noqa: F821

src_num, src_den = fraction(src_fps)
clip = core.std.AssumeFPS(clip, fpsnum=src_num, fpsden=src_den)

if src_fps * 1.2 >= target:
    clip.set_output()  # already near/above the target rate: nothing to do
else:
    if not hasattr(core, "rife"):
        core.std.LoadPlugin(PLUGIN)

    matrix = "709" if clip.height >= 720 else "170m"
    w, h = clip.width, clip.height
    if MAX_HEIGHT and h > MAX_HEIGHT:
        w, h = round(w * MAX_HEIGHT / h / 2) * 2, MAX_HEIGHT

    rgb = core.resize.Bicubic(clip, width=w, height=h, format=vs.RGBS, matrix_in_s=matrix)

    sc = False
    if SCENE_CUT > 0:
        tiny = core.resize.Bilinear(clip, 64, 36, format=vs.GRAYS, matrix_in_s=matrix)
        stats = core.std.PlaneStats(tiny, tiny[1:] + tiny[-1])  # diff vs. next frame

        def mark(n, f):
            out = f.copy()
            out.props["_SceneChangeNext"] = int(f.props["PlaneStatsDiff"] > SCENE_CUT)
            return out

        flags = core.std.ModifyFrame(stats, stats, mark)
        rgb = core.std.CopyFrameProps(rgb, flags, props=["_SceneChangeNext"])
        sc = True

    tgt_num, tgt_den = fraction(target)
    rgb = core.rife.RIFE(rgb, model=MODEL, fps_num=tgt_num, fps_den=tgt_den,
                         gpu_thread=GPU_THREADS, uhd=UHD, sc=sc)

    core.resize.Bicubic(rgb, format=vs.YUV420P10, matrix_s=matrix).set_output()
