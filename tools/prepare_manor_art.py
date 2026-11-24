"""Import the Blackglass Manor art pass: manor tiles/props and 4-direction characters.

CraftPix 4-direction sheets have one row per facing and square 64 px frames.
The game expects horizontal strips named D_ (down), S_ (side, facing right; flipped for
left) and U_ (up) per animation, so each sheet is split into three strips here.
Run from the repository root:  python tools/prepare_manor_art.py
"""
from pathlib import Path
import hashlib
import io
import json
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PACKS = Path(r'D:/Game Assets/2D Assets/CraftPixLibrary/packs')
OUT = ROOT / 'game/assets'
FRAME = 64
ANIMATIONS = ['idle', 'walk', 'attack', 'hurt', 'death']

# role -> (pack, member pattern with {anim}, row index for D, S (right-facing), U)
CHARACTERS = {
    # The assassin is now a PixelLab character; see tools/import_pixellab_character.py.
    'guard': ('free-swordsman-1-3-level-pixel-top-down-sprite-character-pack',
              'PNG/Swordsman_lvl3/Without_shadow/Swordsman_lvl3_{anim}_without_shadow.png', (0, 2, 3)),
    'watchman': ('archer-1-3-level-pixel-top-down-sprite-character',
                 'PNG/Archer_Lvl2/Without_shadow/Archer_lvl2_{anim}_without_shadow.png', (0, 2, 3)),
    'boss': ('free-vampire-4-direction-pixel-character-sprite-pack',
             'PNG/Vampires1/Without_shadow/Vampires1_{anim}_without_shadow.png', (0, 3, 1)),
}

MANOR_PACK = 'nobles-manor-pixel-top-down-tileset-asset-pack'
MANOR_FILES = ['Walls_floor', 'Interior_objects', 'Exterior', 'fountain', 'Fireplace']

manifest_path = OUT / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else []


def archive_for(pack):
    return next((PACKS / pack).glob('*.zip'))


def find_member(source, wanted):
    # Pack spelling of animation names varies (attack / Attack), so match case-insensitively.
    for name in source.namelist():
        if name.lower() == wanted.lower() and '__MACOSX' not in name:
            return name
    raise KeyError(wanted)


def record(path, archive, member, data):
    relative = str(path.relative_to(ROOT))
    manifest[:] = [entry for entry in manifest if entry['file'] != relative]
    manifest.append(dict(file=relative, source_archive=str(archive), member=member,
                         sha256=hashlib.sha256(data).hexdigest()))


def copy_license(source, pack):
    for name in source.namelist():
        if name.lower().endswith('license.txt') and '__MACOSX' not in name:
            target = OUT / 'licenses' / (pack + '.txt')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read(name))
            return


for role, (pack, pattern, rows) in CHARACTERS.items():
    archive = archive_for(pack)
    with zipfile.ZipFile(archive) as source:
        copy_license(source, pack)
        for animation in ANIMATIONS:
            member = find_member(source, pattern.format(anim=animation))
            sheet = Image.open(io.BytesIO(source.read(member))).convert('RGBA')
            assert sheet.height == FRAME * 4, (member, sheet.size)
            for direction, row in zip('DSU', rows):
                strip = sheet.crop((0, row * FRAME, sheet.width, (row + 1) * FRAME))
                buffer = io.BytesIO()
                strip.save(buffer, 'PNG')
                data = buffer.getvalue()
                path = OUT / 'characters' / role / f'{direction}_{animation}.png'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                record(path, archive, f'{member} (row {row})', data)

archive = archive_for(MANOR_PACK)
with zipfile.ZipFile(archive) as source:
    copy_license(source, MANOR_PACK)
    for name in MANOR_FILES:
        member = f'PNG/{name}.png'
        data = source.read(member)
        path = OUT / 'environment' / 'manor' / f'{name.lower()}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        record(path, archive, member, data)

FONT_PACK = 'simplified-medieval-gothic-pixel-font-for-video-games'
archive = archive_for(FONT_PACK)
with zipfile.ZipFile(archive) as source:
    copy_license(source, FONT_PACK)
    member = 'Simplified Gothic Regular.otf'
    data = source.read(member)
    path = OUT / 'fonts' / 'simplified_gothic.otf'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    record(path, archive, member, data)

manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Manifest now lists {len(manifest)} assets.')
