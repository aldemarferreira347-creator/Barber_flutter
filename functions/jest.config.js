/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.test.ts'],
  testPathIgnorePatterns: ['<rootDir>/test/rules/'],
  clearMocks: true,
  testTimeout: 20000,
  // firebase-admin arrastra `jose`, publicado como ESM puro; se deja pasar
  // por el transform de Babel en vez de ignorarlo como el resto de node_modules.
  transformIgnorePatterns: ['node_modules/(?!(jose)/)'],
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
    '^.+\\.jsx?$': 'babel-jest',
  },
};
