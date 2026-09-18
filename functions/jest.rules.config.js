/** @type {import('jest').Config} */
module.exports = {
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/rules/**/*.test.ts'],
  clearMocks: true,
  testTimeout: 30000,
  transform: {
    '^.+\\.tsx?$': 'ts-jest',
  },
};
