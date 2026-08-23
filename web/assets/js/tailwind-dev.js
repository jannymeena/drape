/**
 * Dev-only Tailwind wiring. Loaded after the Play CDN script by the
 * <!-- tw:dev --> block, which `npm run build` strips out and replaces with a
 * <link> to the compiled stylesheet.
 *
 * Two jobs:
 *   1. hand the CDN the same tokens tailwind.config.js gives the real build
 *   2. feed it src/input.css, which the CDN cannot read on its own
 */
(function () {
  if (typeof tailwind === 'undefined') {
    console.error('[zoura] Tailwind Play CDN did not load — check the script order.');
    return;
  }

  tailwind.config = { theme: { extend: zouraTheme } };

  fetch('/src/input.css')
    .then(function (res) { return res.text(); })
    .then(function (css) {
      var style = document.createElement('style');
      style.type = 'text/tailwindcss';
      // The CDN already emits base/components/utilities itself.
      style.textContent = css.replace(/@tailwind\s+[a-z]+\s*;/g, '');
      document.head.appendChild(style);
    })
    .catch(function (err) {
      console.error('[zoura] could not load src/input.css', err);
    });
})();
