"""Turns the rendered sign frames into the app's clips (README "Signer").

character/renders/<id>/0001.png ... (800 px, transparent, from tools/blender/render_signs.py)
  -> assets/signs/<id>.webp (560 px, 24 fps, transparent; one frame = a still picture)

Run from the project folder:  python tools/make_sign_clips.py [id ...]   (no ids = all)
Only signs checked by a fluent BIM signer should be turned into clips.
"""
import sys
from pathlib import Path

from PIL import Image

RENDERS = Path('character/renders')
OUT = Path('assets/signs')
SIZE = 560
FPS = 24


def make(folder: Path) -> None:
    frames = [Image.open(f).convert('RGBA').resize((SIZE, SIZE), Image.LANCZOS) for f in sorted(folder.glob('*.png'))]
    if not frames:
        print(f'{folder.name}: no frames, skipped')
        return
    target = OUT / f'{folder.name}.webp'
    frames[0].save(target, save_all=len(frames) > 1, append_images=frames[1:], duration=round(1000 / FPS), loop=0,
                   quality=85, method=6)
    print(f'{target}: {len(frames)} frame(s), {target.stat().st_size // 1024} KB')


if __name__ == '__main__':
    wanted = set(sys.argv[1:])
    folders = sorted(p for p in RENDERS.iterdir() if p.is_dir() and (not wanted or p.name in wanted))
    for folder in folders:
        make(folder)
