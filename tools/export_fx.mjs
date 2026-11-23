import { spawnSync } from 'node:child_process';
import { mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = 'D:/Pixelfx';
const previews = join(root, 'captures/fx');
const output = join(root, 'game/assets/fx');
mkdirSync(output, { recursive: true });
const effects = [
  ['melee/sword-slash', 'slash', {}],
  ['spawn/poof', 'shift', { palette: ['#100e29', '#30204f', '#653fa1', '#aa75dc', '#a8ecf5', '#f3f5ff'], stars: ['#7849b4', '#b990ef', '#d6ffff'] }],
  ['impacts/bullet-impact', 'impact', {}],
  ['shadow/shadow-flames', 'shadow', {}],
  ['fire/torch', 'torch', {}],
];
const manifest = [];
for (const [id, name, options] of effects) {
  const result = spawnSync(process.execPath, [join(library, 'tools/render.mjs'), id, '--sheet', '--no-actor', '--out', previews, '--opts', JSON.stringify(options)], { cwd: library, stdio: 'inherit' });
  if (result.status !== 0) process.exit(result.status ?? 1);
  const basename = id.split('/')[1];
  for (const extension of ['png', 'json']) copyFileSync(join(previews, id, `${basename}.${extension}`), join(output, `${name}.${extension}`));
  manifest.push({ name, id, options, source: library, contact_sheet: join(previews, id, 'contact.png'), license: 'MIT; see retained notices' });
}
for (const file of ['LICENSE', 'NOTICE.md']) copyFileSync(join(library, file), join(root, 'game/assets/licenses', `pixelfx-${file}`));
writeFileSync(join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`Exported ${effects.length} PixelFX atlases without stock actors.`);
