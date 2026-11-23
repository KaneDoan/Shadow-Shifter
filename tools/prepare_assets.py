"""Extract the small, explicit asset set used by ShadowShift."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parent.parent
PACKS = Path(r'D:/Game Assets/2D Assets/CraftPixLibrary/packs')
OUT = ROOT / 'game/assets'
manifest = []

def extract(pack, members):
    archive = next((PACKS / pack).glob('*.zip'))
    with zipfile.ZipFile(archive) as source:
        for member, destination in members:
            data = source.read(member)
            path = OUT / destination
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            manifest.append(dict(file=str(path.relative_to(ROOT)), source_archive=str(archive), member=member, sha256=hashlib.sha256(data).hexdigest()))
        if 'license.txt' in source.namelist():
            license_path = OUT / 'licenses' / (pack + '.txt')
            license_path.parent.mkdir(parents=True, exist_ok=True)
            license_path.write_bytes(source.read('license.txt'))

characters = []
for number, role in [('2', 'assassin'), ('1', 'watchman'), ('2', 'guard'), ('3', 'boss')]:
    for direction in ['D', 'S', 'U']:
        for action in ['Idle', 'Walk', 'Attack', 'Hurt', 'Death']:
            characters.append((f'1 Characters/{number}/{direction}_{action}.png', f'characters/{role}/{direction}_{action.lower()}.png'))
for name in ['Shadow', 'Arrow', 'D_Blood', 'S_Blood', 'U_Blood']:
    characters.append((f'1 Characters/Other/{name}.png', f'characters/other/{name.lower()}.png'))
extract('free-top-down-roguelike-game-kit-pixel-art', characters)

environment = ['walls_floor', 'Objects', 'doors_lever_chest_animation', 'fire_animation', 'fire_animation2', 'decorative_cracks_walls', 'decorative_cracks_floor']
extract('free-2d-top-down-pixel-dungeon-asset-pack', [(f'PNG/{name}.png', f'environment/{name.lower()}.png') for name in environment])
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Prepared {len(manifest)} selected assets with source paths and SHA-256 hashes.')
