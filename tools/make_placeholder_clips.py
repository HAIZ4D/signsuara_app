"""Makes tiny PLACEHOLDER sign clips for the tests (test/fixtures/signs/). They are moving dots,
not signs: real clips come from the avatar (README "Signer").

Same format as the real clips: animated WebP with a transparent background.
Run from the project folder:  python tools/make_placeholder_clips.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path('test/fixtures/signs')
SIZE = 48


def frame(x: int, colour: tuple) -> Image.Image:
    image = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))  # transparent: the stage shows through
    ImageDraw.Draw(image).ellipse((x, 18, x + 12, 30), fill=colour)
    return image


def save(name: str, frames: list, ms: int) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    frames[0].save(OUT / f'{name}.webp', save_all=True, append_images=frames[1:], duration=ms, loop=0,
                   lossless=True)
    print(name, len(frames), 'frames of', ms, 'ms')


save('placeholder_a', [frame(x, (0, 164, 180, 255)) for x in (6, 18, 30)], 40)  # 3 frames
save('placeholder_b', [frame(x, (255, 200, 45, 255)) for x in (30, 6)], 60)  # 2 frames
save('placeholder_still', [frame(18, (255, 255, 255, 255))], 0)  # one still frame
