// Corre los tests de reglas de Firestore/Storage contra el emulador.
//
// Requisitos: JDK 21 o superior (firebase-tools ya no soporta menos).
// En Windows el emulador de Firestore solo arranca con tres ajustes que este
// script aplica solo:
//   - -Djava.net.preferIPv4Stack=true (Java falla abriendo su loopback IPv6).
//   - TMP/TEMP en una carpeta corta (<raíz>/tmp): con la ruta temporal normal
//     de Windows falla el socket de dominio Unix que usa Netty.
//   - Se prefiere un JDK >= 21 de Eclipse Adoptium aunque JAVA_HOME apunte a
//     uno más viejo.
// Uso: npm run test:rules [-- <patrón de jest>]
const { spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const env = { ...process.env };

if (process.platform === 'win32') {
  env.JAVA_TOOL_OPTIONS = [env.JAVA_TOOL_OPTIONS, '-Djava.net.preferIPv4Stack=true'].filter(Boolean).join(' ');

  const tmp = path.join(path.parse(os.tmpdir()).root, 'tmp');
  fs.mkdirSync(tmp, { recursive: true });
  env.TMP = tmp;
  env.TEMP = tmp;

  const adoptium = 'C:/Program Files/Eclipse Adoptium';
  const jdk = fs.existsSync(adoptium)
    ? fs
        .readdirSync(adoptium)
        .filter((dir) => /^jdk-(2[1-9]|[3-9]\d)/.test(dir))
        .sort()
        .pop()
    : undefined;
  if (jdk) {
    env.JAVA_HOME = path.join(adoptium, jdk);
    env.PATH = `${path.join(env.JAVA_HOME, 'bin')}${path.delimiter}${env.PATH}`;
  }
}

const pattern = process.argv.slice(2).join(' ');
const jest = `jest --config jest.rules.config.js --runInBand ${pattern}`.trim();
const result = spawnSync('firebase', ['emulators:exec', '--project', 'demo-barber', '--only', 'firestore,storage', `"${jest}"`], {
  stdio: 'inherit',
  env,
  shell: true,
});
process.exit(result.status ?? 1);
