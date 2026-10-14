(() => {
  const file = window.location.pathname.split('/').pop() || 'index.html';
  const active = file === 'index.html' ? 'home' : file === 'scan.html' || file === 'guided_viewing.html' ? 'scan' : 'learn';
  const nav = document.createElement('nav');
  nav.className = 'mobile-nav';
  nav.setAttribute('aria-label', 'Mobile navigation');

  nav.innerHTML = `
    <a class="${active === 'home' ? 'active' : ''}" href="index.html"><span class="nav-icon" aria-hidden="true">⌂</span><span>Home</span></a>
    <a class="scan-link ${active === 'scan' ? 'active' : ''}" href="scan.html"><span class="nav-icon" aria-hidden="true">▦</span><span>Scan</span></a>
    <a class="${active === 'learn' ? 'active' : ''}" href="viewer.html"><span class="nav-icon" aria-hidden="true">☰</span><span>Learn</span></a>`;

  document.body.append(nav);

  document.addEventListener('click', event => {
    const link = event.target.closest('a[href]');
    if (!link || link.target === '_blank' || link.hasAttribute('download')) return;
    const destination = new URL(link.href, window.location.href);
    if (destination.origin !== window.location.origin) return;
    event.preventDefault();
    window.location.assign(destination.href);
  });
})();