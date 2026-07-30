import { build } from 'esbuild'
import { mkdirSync, copyFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))

// Xcode passes the directory it copies into the application bundle, so that the
// bundle is a build product rather than something committed next to what it is
// built from.
const flag = process.argv.indexOf('--outdir')
const outdir = flag === -1
    ? resolve(here, 'build/collab')
    : resolve(process.argv[flag + 1], 'collab')

mkdirSync(outdir, { recursive: true })

await build({
    entryPoints: [resolve(here, 'src/index.js')],
    bundle: true,
    outfile: resolve(outdir, 'editor.js'),
    format: 'iife',
    // WKWebView is the system WebKit, so the oldest engine this has to run on
    // is the one that shipped with the deployment target, iOS 14.5.
    target: ['safari14'],
    minify: true,
    sourcemap: false,
    legalComments: 'external',
    logLevel: 'info',
})

copyFileSync(resolve(here, 'editor.html'), resolve(outdir, 'editor.html'))
