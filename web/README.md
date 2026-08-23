# ZOURA marketing site

Plain HTML, CSS and JS with Tailwind. Two pages, no framework, no router:

| Page            | File            | Notes                                                       |
| --------------- | --------------- | ----------------------------------------------------------- |
| Home            | `index.html`    | Nine sections; the nav scrolls to each one                    |
| Download        | `download.html` | Store links, requirements, first-run walkthrough, FAQ         |

## Commands

```bash
cd web
npm install        # once — the only dependency is tailwindcss

npm run dev        # http://localhost:4173 — Tailwind Play CDN, no build step
npm run build      # compiles dist/ — the deployable site
npm run preview    # http://localhost:4173 serving dist/ (what actually ships)
```

`dev` serves the source tree directly: the Play CDN compiles styles in the browser,
so editing HTML and refreshing is enough — nothing to rebuild. It prints a
"should not be used in production" warning; that is expected and only happens here.

`build` produces `dist/`: it runs the Tailwind CLI over `src/input.css`, copies the
assets, and rewrites each page's `<!-- tw:dev -->` block into a single
`<link rel="stylesheet" href="/assets/css/app.css">`. The result is pure static
files with no runtime JS for styling — deploy `dist/` as-is.

`PORT=4200 npm run dev` if 4173 is taken.

## Layout

```
web/
  index.html  download.html      pages (each carries a <!-- tw:dev --> block)
  tailwind.theme.js              Warm Mocha design tokens — the single source
  tailwind.config.js             build config; requires tailwind.theme.js
  src/input.css                  @layer base/components/utilities on top of Tailwind
  assets/css/                    (build output lands in dist/, not here)
  assets/js/main.js              all page behaviour, shared by both pages
  assets/js/tailwind-dev.js      dev only — feeds tokens + input.css to the CDN
  assets/img/                    local copies of every image
  scripts/dev.js                 zero-dependency static server
  scripts/build.js               Tailwind CLI + HTML rewrite -> dist/
  favicon.svg  robots.txt  sitemap.xml
  dist/                          build output (gitignored)
```

### Design tokens

`tailwind.theme.js` holds the Warm Mocha palette, type scale and spacing, and is
read by both paths — `tailwind.config.js` `require`s it, and the dev page loads it
as a plain script for the CDN. Change a token there and both stay in step.

`src/input.css` defines the component classes the markup leans on: `.shell`,
`.btn-primary` / `.btn-secondary`, `.card`, `.nav-link`, `.section-title`,
`.reveal` and the `.phone-frame` mockup chrome.

### Page behaviour (`assets/js/main.js`)

Each block is self-wiring — it activates only if its markup is on the page, which is
why both pages share one file. Covers the sticky header, mobile drawer, fixed-duration
anchor scrolling, nav scroll-spy, scroll reveals, the timeline spine, stat counters,
the app-screen carousel, FAQ accordions and the pricing toggle.

Anchor scrolling is done in JS on purpose: native `scroll-behavior: smooth` scales its
duration with distance, so a hero → FAQ jump on a page this long crawls. Every hop runs
over the same ~620 ms instead, and `prefers-reduced-motion` turns it into a plain jump.

## Before launch

- `href="#"` on both store buttons in `download.html` and the closing CTA — swap in
  the real App Store and Play Store URLs.
- `assets/img/cta-qr-code.jpg` is a placeholder QR; regenerate it against the live
  download URL.
- `https://zoura.app` is hardcoded in the canonical tags, Open Graph URLs,
  `robots.txt` and `sitemap.xml` — update if the domain differs.
- Privacy policy, terms and contact links in both footers still point at `#`.
