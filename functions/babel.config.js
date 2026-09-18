/**
 * Solo se usa para que Jest pueda transformar dependencias de node_modules
 * publicadas como ESM puro (p.ej. `jose`, requerida transitivamente por
 * firebase-admin). El código propio del proyecto sigue compilando con
 * ts-jest, no con Babel.
 */
module.exports = {
  presets: [['@babel/preset-env', { targets: { node: 'current' } }]],
};
