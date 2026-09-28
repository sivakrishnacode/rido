import { defineConfig } from 'vitest/config';
import tsconfigPaths from 'vite-tsconfig-paths';

export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    globals: true,
    root: './',
    include: ['**/*.e2e-spec.ts'],
    // The files share one test database and Redis (and clear Redis keys in beforeAll): run them one at a time.
    fileParallelism: false,
  },
});
