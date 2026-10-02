// Entorno para que los emuladores de Firebase arranquen en Windows.
//
// Requisitos: JDK 21 o superior (firebase-tools ya no soporta menos).
// En Windows el emulador de Firestore solo arranca con tres ajustes:
//   - -Djava.net.preferIPv4Stack=true (Java falla abriendo su loopback IPv6).
//   - TMP/TEMP en una carpeta corta (<raíz>/tmp): con la ruta temporal normal
//     de Windows falla el socket de dominio Unix que usa Netty.
//   - Se prefiere un JDK >= 21 de Eclipse Adoptium aunque JAVA_HOME apunte a
//     uno más viejo.
// En otros sistemas se devuelve el entorno tal cual.
const fs = require('fs');
const os = require('os');
const path = require('path');

function emulatorEnv() {
  const env = { ...process.env };
  if (process.platform !== 'win32') return env;

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
  return env;
}

module.exports = { emulatorEnv };
