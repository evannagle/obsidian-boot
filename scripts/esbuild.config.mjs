import esbuild from 'esbuild';
import builtins from "builtin-modules";

esbuild.build({
    banner: {
        js: '/* This is an autogenerated file. Do not edit this file directly. */\n'
    },
    entryPoints: ['src/index.ts'],
    bundle: true,
    outfile: 'dist/app.js',
    target: 'es2020',
    external: [
        ...builtins
    ],
    format: 'cjs',
    // watch: process.argv.includes('--watch'),
    logLevel: 'info',
    sourcemap: process.argv.includes('--sourcemap'),
    treeShaking: true
}).catch(() => process.exit(1));
