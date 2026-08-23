/**
 * ZOURA marketing site behaviour.
 *
 * Every block below is optional — it wires itself up only if the matching
 * markup is on the page, so index.html and download.html share this one file.
 */
(function () {
  'use strict';

  var $ = function (sel, ctx) { return (ctx || document).querySelector(sel); };
  var $$ = function (sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); };
  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------------------------------------------------------------------
     Header — solid background once the page scrolls off the hero
     --------------------------------------------------------------------- */
  function initHeader() {
    var header = $('[data-header]');
    if (!header) return;

    var solid = ['bg-surface/95', 'backdrop-blur-md', 'border-light-border', 'shadow-zoura'];

    function sync() {
      var scrolled = window.scrollY > 24;
      solid.forEach(function (cls) { header.classList.toggle(cls, scrolled); });
      header.classList.toggle('border-transparent', !scrolled);
    }

    sync();
    window.addEventListener('scroll', sync, { passive: true });
  }

  /* ---------------------------------------------------------------------
     Mobile menu
     --------------------------------------------------------------------- */
  function initMobileMenu() {
    var toggle = $('[data-menu-toggle]');
    var menu = $('[data-menu]');
    if (!toggle || !menu) return;

    var icon = $('[data-menu-icon]', toggle);

    function setOpen(open) {
      menu.classList.toggle('hidden', !open);
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
      if (icon) icon.textContent = open ? 'close' : 'menu';
    }

    toggle.addEventListener('click', function () {
      setOpen(menu.classList.contains('hidden'));
    });

    // Tapping a link navigates; close the drawer behind it.
    $$('[data-menu-link]', menu).forEach(function (link) {
      link.addEventListener('click', function () { setOpen(false); });
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !menu.classList.contains('hidden')) {
        setOpen(false);
        toggle.focus();
      }
    });

    // The drawer is mobile-only; drop it if the viewport grows past lg.
    window.matchMedia('(min-width: 1024px)').addEventListener('change', function (e) {
      if (e.matches) setOpen(false);
    });
  }

  /* ---------------------------------------------------------------------
     Smooth scroll for in-page anchors.

     Native `scroll-behavior: smooth` scales its duration with distance, which
     turns a hero → FAQ jump on this page into several seconds of travel. This
     runs every hop over the same short duration instead.
     --------------------------------------------------------------------- */
  var SCROLL_MS = 620;
  var HEADER_OFFSET = 88;

  function scrollToSection(target) {
    var to = Math.min(
      target.getBoundingClientRect().top + window.scrollY - HEADER_OFFSET,
      document.documentElement.scrollHeight - window.innerHeight
    );
    var from = window.scrollY;
    var distance = to - from;

    if (reducedMotion || Math.abs(distance) < 2) {
      window.scrollTo(0, to);
      return;
    }

    var started = null;
    var done = false;

    function step(now) {
      if (done) return;
      if (started === null) started = now;
      var t = Math.min((now - started) / SCROLL_MS, 1);
      var eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; // ease-in-out cubic
      window.scrollTo(0, from + distance * eased);
      if (t < 1) requestAnimationFrame(step);
      else done = true;
    }
    requestAnimationFrame(step);

    // rAF is throttled to a standstill in background/unpainted tabs, which would
    // leave the link doing nothing at all. Timers still run there, so this makes
    // sure we always end up at the target.
    setTimeout(function () {
      if (done) return;
      done = true;
      window.scrollTo(0, to);
    }, SCROLL_MS + 120);
  }

  function initSmoothAnchors() {
    document.addEventListener('click', function (e) {
      var link = e.target.closest && e.target.closest('a[href^="#"]');
      if (!link) return;

      var id = link.getAttribute('href');
      if (!id || id === '#') return;

      var target = document.querySelector(id);
      if (!target) return;

      e.preventDefault();
      scrollToSection(target);
      // Keep the URL shareable without letting the browser jump as well.
      history.replaceState(null, '', id);
    });

    // A page opened straight at #section still needs the header offset applied.
    if (window.location.hash) {
      var initial = document.querySelector(window.location.hash);
      if (initial) {
        window.scrollTo(0, initial.getBoundingClientRect().top + window.scrollY - HEADER_OFFSET);
      }
    }
  }

  /* ---------------------------------------------------------------------
     Scroll spy — mark the nav link whose section is in view.

     Uses the section nearest the top of the viewport rather than raw
     intersection ratios, so short and tall sections behave the same.
     --------------------------------------------------------------------- */
  function initScrollSpy() {
    var links = $$('[data-nav]');
    if (!links.length) return;

    var targets = links
      .map(function (link) {
        var id = link.getAttribute('href');
        return id && id.charAt(0) === '#' ? { link: link, section: $(id) } : null;
      })
      .filter(function (t) { return t && t.section; });

    if (!targets.length) return;

    function sync() {
      var line = window.scrollY + 100; // just below the fixed header
      var current = null;

      targets.forEach(function (t) {
        if (t.section.offsetTop <= line) current = t;
      });

      // At the very bottom nothing below can win, so honour the last section.
      if (window.innerHeight + window.scrollY >= document.body.offsetHeight - 2) {
        current = targets[targets.length - 1];
      }

      // `current` stays null above the first linked section (the hero), which
      // leaves every link unmarked rather than falsely highlighting the first.
      var href = current && current.link.getAttribute('href');
      links.forEach(function (link) {
        if (href && link.getAttribute('href') === href) link.setAttribute('aria-current', 'true');
        else link.removeAttribute('aria-current');
      });
    }

    sync();
    window.addEventListener('scroll', sync, { passive: true });
    window.addEventListener('resize', sync);
  }

  /* ---------------------------------------------------------------------
     Reveal on scroll
     --------------------------------------------------------------------- */
  function initReveal() {
    var items = $$('.reveal');
    if (!items.length) return;

    if (reducedMotion || !('IntersectionObserver' in window)) {
      items.forEach(function (el) { el.classList.add('is-visible'); });
      return;
    }

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.12, rootMargin: '0px 0px -40px 0px' }
    );

    items.forEach(function (el) { observer.observe(el); });
  }

  /* ---------------------------------------------------------------------
     Timeline spine — fills as the "how it works" steps scroll past
     --------------------------------------------------------------------- */
  function initTimeline() {
    var fill = $('[data-timeline]');
    if (!fill) return;

    var track = fill.parentElement;

    function sync() {
      var rect = track.getBoundingClientRect();
      var anchor = window.innerHeight * 0.55; // fill up to just below centre
      var progress = (anchor - rect.top) / rect.height;
      fill.style.height = Math.max(0, Math.min(1, progress)) * 100 + '%';
    }

    sync();
    window.addEventListener('scroll', sync, { passive: true });
    window.addEventListener('resize', sync);
  }

  /* ---------------------------------------------------------------------
     Animated stat counters
     --------------------------------------------------------------------- */
  function initCounters() {
    var container = $('[data-counters]');
    if (!container) return;

    var counters = $$('[data-count-to]', container);
    if (!counters.length) return;

    function render(el, value) {
      var decimals = Number(el.dataset.decimals || 0);
      el.textContent =
        (el.dataset.prefix || '') +
        (decimals ? value.toFixed(decimals) : Math.floor(value)) +
        (el.dataset.suffix || '');
    }

    function run() {
      counters.forEach(function (el) {
        var target = parseFloat(el.dataset.countTo);
        var duration = 1600;
        var started = null;

        function frame(now) {
          if (started === null) started = now;
          var t = Math.min((now - started) / duration, 1);
          render(el, target * (1 - Math.pow(1 - t, 3))); // ease-out cubic
          if (t < 1) requestAnimationFrame(frame);
        }

        requestAnimationFrame(frame);
      });
    }

    if (reducedMotion || !('IntersectionObserver' in window)) return; // markup already shows finals

    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          run();
          observer.disconnect();
        });
      },
      { threshold: 0.25 }
    );

    observer.observe(container);
  }

  /* ---------------------------------------------------------------------
     App screen carousel
     --------------------------------------------------------------------- */
  function initCarousel() {
    var root = $('[data-carousel]');
    var track = $('[data-carousel-track]');
    if (!root || !track) return;

    var slides = Array.prototype.slice.call(track.children);
    var dots = $$('[data-carousel-dot]');
    var counters = $$('[data-carousel-counter]');
    var index = 0;
    var timer = null;

    function paint() {
      track.style.transform = 'translateX(-' + index * 100 + '%)';

      dots.forEach(function (dot, i) {
        var active = i === index;
        dot.classList.toggle('w-6', active);
        dot.classList.toggle('w-2', !active);
        dot.classList.toggle('bg-primary-container', active);
        dot.classList.toggle('bg-light-border', !active);
        dot.setAttribute('aria-current', String(active));
      });

      counters.forEach(function (el) {
        el.textContent = index + 1 + ' / ' + slides.length;
      });
    }

    function go(next) {
      index = (next + slides.length) % slides.length;
      paint();
    }

    function play() {
      stop();
      if (reducedMotion) return;
      timer = setInterval(function () { go(index + 1); }, 5000);
    }

    function stop() {
      if (timer) clearInterval(timer);
      timer = null;
    }

    $$('[data-carousel-next]').forEach(function (btn) {
      btn.addEventListener('click', function () { go(index + 1); play(); });
    });
    $$('[data-carousel-prev]').forEach(function (btn) {
      btn.addEventListener('click', function () { go(index - 1); play(); });
    });
    dots.forEach(function (dot) {
      dot.addEventListener('click', function () { go(Number(dot.dataset.carouselDot)); play(); });
    });

    root.addEventListener('mouseenter', stop);
    root.addEventListener('mouseleave', play);

    // Touch swipe
    var startX = null;
    root.addEventListener('touchstart', function (e) { startX = e.touches[0].clientX; stop(); }, { passive: true });
    root.addEventListener('touchend', function (e) {
      if (startX === null) return;
      var dx = e.changedTouches[0].clientX - startX;
      if (Math.abs(dx) > 40) go(index + (dx < 0 ? 1 : -1));
      startX = null;
      play();
    });

    paint();
    play();
  }

  /* ---------------------------------------------------------------------
     FAQ accordions — grid-rows trick animates to the panel's real height
     --------------------------------------------------------------------- */
  function initAccordions() {
    $$('[data-accordion]').forEach(function (group) {
      var triggers = $$('[data-accordion-trigger]', group);

      function close(trigger) {
        var panel = document.getElementById(trigger.getAttribute('aria-controls'));
        var icon = $('[data-accordion-icon]', trigger);
        trigger.setAttribute('aria-expanded', 'false');
        if (panel) panel.classList.replace('grid-rows-[1fr]', 'grid-rows-[0fr]');
        if (icon) icon.classList.remove('rotate-180');
        trigger.closest('[data-accordion] > div').classList.remove('bg-surface-bright');
      }

      triggers.forEach(function (trigger) {
        trigger.addEventListener('click', function () {
          var open = trigger.getAttribute('aria-expanded') === 'true';

          // One panel at a time.
          triggers.forEach(function (other) {
            if (other !== trigger) close(other);
          });

          if (open) {
            close(trigger);
            return;
          }

          var panel = document.getElementById(trigger.getAttribute('aria-controls'));
          var icon = $('[data-accordion-icon]', trigger);
          trigger.setAttribute('aria-expanded', 'true');
          if (panel) panel.classList.replace('grid-rows-[0fr]', 'grid-rows-[1fr]');
          if (icon) icon.classList.add('rotate-180');
          trigger.closest('[data-accordion] > div').classList.add('bg-surface-bright');
        });
      });
    });
  }

  /* ---------------------------------------------------------------------
     Pricing monthly / yearly toggle
     --------------------------------------------------------------------- */
  function initBillingToggle() {
    var toggle = $('[data-billing-toggle]');
    if (!toggle) return;

    var knob = $('[data-billing-knob]');
    var monthlyLabel = $('[data-billing-label="monthly"]');
    var yearlyLabel = $('[data-billing-label="yearly"]');
    var yearly = false;

    toggle.addEventListener('click', function () {
      yearly = !yearly;

      toggle.setAttribute('aria-checked', String(yearly));
      toggle.classList.toggle('bg-primary-fixed-dim', yearly);
      toggle.classList.toggle('bg-light-border', !yearly);
      if (knob) knob.classList.toggle('translate-x-6', yearly);

      [
        [monthlyLabel, !yearly],
        [yearlyLabel, yearly]
      ].forEach(function (pair) {
        if (!pair[0]) return;
        pair[0].classList.toggle('text-primary', pair[1]);
        pair[0].classList.toggle('text-muted-gray', !pair[1]);
      });

      $$('[data-price]').forEach(function (el) {
        el.style.opacity = '0';
        setTimeout(function () {
          el.textContent = yearly ? el.dataset.yearly : el.dataset.monthly;
          el.style.opacity = '1';
        }, 140);
      });

      $$('[data-price-period]').forEach(function (el) {
        el.style.opacity = '0';
        setTimeout(function () {
          el.textContent = yearly ? '/year' : '/month';
          el.style.opacity = '1';
        }, 140);
      });
    });

    $$('[data-price], [data-price-period]').forEach(function (el) {
      el.style.transition = 'opacity 140ms ease';
    });
  }

  /* ------------------------------------------------------------------- */
  function boot() {
    initHeader();
    initMobileMenu();
    initSmoothAnchors();
    initScrollSpy();
    initReveal();
    initTimeline();
    initCounters();
    initCarousel();
    initAccordions();
    initBillingToggle();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
