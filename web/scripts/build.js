#!/usr/bin/env node
/**
 * Produce the deployable site in dist/:
 *
 *   1. compile + minify src/input.css through the Tailwind CLI
 *   2. copy the static assets (minus the dev-only Tailwind loader)
 *   3. rewrite each page's <!-- tw:dev --> block into a plain <link>
 *
 * Output is pure static HTML/CSS/JS — no runtime JS is needed for styling.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const web = path.resolve(__dirname, '..');
const dist = path.join(web, 'dist');

const DEV_BLOCK = /[ \t]*<!-- tw:dev -->[\s\S]*?<!-- \/tw:dev -->\n?/;
const PROD_TAG = '    <link rel="stylesheet" href="/assets/css/app.css" />\n';

function rmrf(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

function copyDir(from, to, skip = []) {
  fs.mkdirSync(to, { recursive: true });
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    if (skip.includes(entry.name)) continue;
    const src = path.join(from, entry.name);
    const dest = path.join(to, entry.name);
    if (entry.isDirectory()) copyDir(src, dest, skip);
    else fs.copyFileSync(src, dest);
  }
}

rmrf(dist);
fs.mkdirSync(dist, { recursive: true });

// 1. CSS
console.log('→ compiling Tailwind');
execFileSync(
  process.platform === 'win32' ? 'npx.cmd' : 'npx',
  ['tailwindcss', '-i', './src/input.css', '-o', './dist/assets/css/app.css', '--minify'],
  { cwd: web, stdio: 'inherit' }
);

// 2. Assets — the dev loader and the browser copy of the tokens ship nowhere.
console.log('→ copying assets');
copyDir(path.join(web, 'assets', 'img'), path.join(dist, 'assets', 'img'));
copyDir(path.join(web, 'assets', 'js'), path.join(dist, 'assets', 'js'), ['tailwind-dev.js']);
for (const extra of ['robots.txt', 'sitemap.xml', 'favicon.svg']) {
  const src = path.join(web, extra);
  if (fs.existsSync(src)) fs.copyFileSync(src, path.join(dist, extra));
}

// 3. Pages
console.log('→ rewriting pages');
const pages = fs.readdirSync(web).filter((f) => f.endsWith('.html'));
for (const page of pages) {
  const html = fs.readFileSync(path.join(web, page), 'utf8');
  if (!DEV_BLOCK.test(html)) {
    console.error(`✗ ${page} has no <!-- tw:dev --> block — its styles would not load.`);
    process.exit(1);
  }
  fs.writeFileSync(path.join(dist, page), html.replace(DEV_BLOCK, PROD_TAG));
  console.log(`  ${page}`);
}

const cssBytes = fs.statSync(path.join(dist, 'assets', 'css', 'app.css')).size;
console.log(`\n✓ dist/ ready — app.css ${(cssBytes / 1024).toFixed(1)} KB`);
console.log('  preview it with: npm run preview\n');
