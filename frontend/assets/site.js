(function () {
  'use strict';

  var cfg = window.DS_CONFIG || {};
  var email = cfg.supportEmail || 'support@digitalstreamers.xyz';

  function applySupportEmail() {
    document.querySelectorAll('[data-support-email]').forEach(function (el) {
      var tag = el.tagName.toLowerCase();
      if (tag === 'a') {
        el.setAttribute('href', 'mailto:' + email);
        if (!el.getAttribute('data-keep-label')) {
          el.textContent = email;
        }
      } else {
        el.textContent = email;
      }
    });
  }

  function applyYear() {
    var year = String(new Date().getFullYear());
    document.querySelectorAll('[data-current-year]').forEach(function (el) {
      el.textContent = year;
    });
  }

  function initNav() {
    var toggle = document.querySelector('[data-nav-toggle]');
    var panel = document.querySelector('[data-nav-panel]');
    if (!toggle || !panel) return;

    var close = function () {
      panel.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
      document.body.classList.remove('nav-open');
    };

    toggle.addEventListener('click', function () {
      var open = !panel.classList.contains('is-open');
      panel.classList.toggle('is-open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      document.body.classList.toggle('nav-open', open);
    });

    panel.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', close);
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') close();
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    applySupportEmail();
    applyYear();
    initNav();
  });
})();
