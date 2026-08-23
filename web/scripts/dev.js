#!/usr/bin/env node
/**
 * Zero-dependency static file server for local development.
 *
 *   npm run dev       serve the source tree (Tailwind Play CDN, no build step)
 *   npm run preview   serve dist/ (compiled CSS, exactly what ships)
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const useDist = process.argv.includes('--dist');
const root = path.resolve(__dirname, '..', useDist ? 'dist' : '.');
const port = Number(process.env.PORT) || 4173;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8'
};

if (!fs.existsSync(root)) {
  console.error(`✗ ${path.relative(process.cwd(), root)} does not exist — run \`npm run build\` first.`);
  process.exit(1);
}

http
  .createServer((req, res) => {
    let pathname;
    try {
      pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    } catch {
      res.writeHead(400).end('Bad request');
      return;
    }

    // Resolve inside root only — never let ../ escape the served tree.
    let file = path.join(root, pathname);
    if (!file.startsWith(root)) {
      res.writeHead(403).end('Forbidden');
      return;
    }

    // Pretty URLs: / -> index.html, /download -> download.html
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
    if (!fs.existsSync(file) && fs.existsSync(`${file}.html`)) file += '.html';

    if (!fs.existsSync(file)) {
      res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h1>404</h1><p><a href="/">Back to the home page</a></p>');
      return;
    }

    res.writeHead(200, {
      'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-store'
    });
    fs.createReadStream(file).pipe(res);
  })
  .listen(port, () => {
    console.log(`\n  ZOURA site  →  http://localhost:${port}`);
    console.log(`  serving     ${path.relative(process.cwd(), root) || '.'}${useDist ? '  (compiled CSS)' : '  (Tailwind Play CDN)'}\n`);
  });
