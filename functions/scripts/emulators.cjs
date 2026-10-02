// Levanta los emuladores de Auth, Firestore y Storage para desarrollo.
// Usa las reglas reales (firestore.rules / storage.rules). La app se conecta
// con `flutter run --dart-define=USE_EMULATOR=true` y los datos de prueba se
// cargan con `npm run seed` (en otra terminal, con los emuladores arriba).
// Uso: npm run emulators
const { spawnSync } = require('child_process');

const { emulatorEnv } = require('./java-env.cjs');

const result = spawnSync('firebase', ['emulators:start', '--project', 'barber-5082f', '--only', 'auth,firestore,storage'], {
  stdio: 'inherit',
  env: emulatorEnv(),
  shell: true,
});
process.exit(result.status ?? 1);
