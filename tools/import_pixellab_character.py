"""Convert a PixelLab character download (unzipped) into the game's sprite strips.

The game expects horizontal strips of 64 px square frames named D_ (down), S_ (side,
facing right; flipped for left) and U_ (up) per animation. PixelLab frames are centred
on their canvas, so each is pasted centred on (32, 27) to put the feet where the old
sprite's were.

Usage, from the repository root:
    python tools/import_pixellab_character.py <unzipped download folder> assassin
"""
from pathlib import Path
import json
import sys

from PIL import Image

FRAME = 64
CENTRE = (32, 27)
DIRECTIONS = {'D': 'south', 'S': 'east', 'U': 'north'}
ANIMATIONS = ['idle', 'walk', 'attack', 'hurt', 'death']


def main(source: Path, role: str) -> None:
    out = Path(__file__).resolve().parent.parent / 'game/assets/characters' / role
    meta = json.loads((source / 'metadata.json').read_text(encoding='utf-8'))
    frames = meta['states'][0]['frames']['animations']
    for prefix, direction in DIRECTIONS.items():
        for animation in ANIMATIONS:
            paths = frames[animation][direction]
            strip = Image.new('RGBA', (FRAME * len(paths), FRAME))
            for index, relative in enumerate(paths):
                image = Image.open(source / relative).convert('RGBA')
                at = (index * FRAME + CENTRE[0] - image.width // 2, CENTRE[1] - image.height // 2)
                strip.alpha_composite(image, (max(at[0], index * FRAME), max(at[1], 0)),
                                      (max(0, -(at[0] - index * FRAME)), max(0, -at[1])))
            strip.save(out / f'{prefix}_{animation}.png')
            print(out / f'{prefix}_{animation}.png', len(paths), 'frames')


if __name__ == '__main__':
    main(Path(sys.argv[1]), sys.argv[2])
