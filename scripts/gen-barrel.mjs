import { readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = 'packages/core/src';

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) return walk(full);
    if (!name.endsWith('.ts') || name === 'index.ts') return [];
    return [full];
  });
}

const lines = walk(ROOT)
  .map((f) => './' + relative(ROOT, f).replace(/\\/g, '/').replace(/\.ts$/, ''))
  .sort()
  .map((p) => `export * from '${p}';`);

writeFileSync(join(ROOT, 'index.ts'), `// GERADO - nao editar a mao\n${lines.join('\n')}\n`);
console.log(`barrel gerado com ${lines.length} exports`);