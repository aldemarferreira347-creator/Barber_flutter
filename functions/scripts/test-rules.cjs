// Corre los tests de reglas de Firestore/Storage contra el emulador.
// Los ajustes de Windows y el JDK ≥ 21 viven en java-env.cjs.
// Uso: npm run test:rules [-- <patrón de jest>]
const { spawnSync } = require('child_process');

const { emulatorEnv } = require('./java-env.cjs');

const pattern = process.argv.slice(2).join(' ');
const jest = `jest --config jest.rules.config.js --runInBand ${pattern}`.trim();
const result = spawnSync('firebase', ['emulators:exec', '--project', 'demo-barber', '--only', 'firestore,storage', `"${jest}"`], {
  stdio: 'inherit',
  env: emulatorEnv(),
  shell: true,
});
process.exit(result.status ?? 1);
