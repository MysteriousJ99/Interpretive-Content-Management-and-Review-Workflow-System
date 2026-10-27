// tour-api.js - shared code for visitor pages that read PUBLISHED content from the API.
// The API (docs/api.md) only ever returns content an administrator has published.
// All text is inserted with textContent, never innerHTML, so content from the
// database can never run as code on a visitor's phone.
const TourAPI = (() => {
  const LANG = { en: 'English', es: 'Español', fr: 'Français' };
  const LEVEL = { college: 'College level', simplified: 'Simplified' };

  async function get(path) {
    const r = await fetch('/api/v1/' + path, { headers: { Accept: 'application/json' } });
    const data = await r.json().catch(() => ({}));
    return { ok: r.ok, status: r.status, data };
  }
  const list = () => get('locations');
  const summary = token => get('locations/' + encodeURIComponent(token));
  const content = (token, lang, level) =>
    get('locations/' + encodeURIComponent(token) + '/content?lang=' +
        encodeURIComponent(lang) + '&level=' + encodeURIComponent(level));

  // Build the language and reading-level menus from what is actually published.
  function fillPickers(available, langSel, levelSel) {
    const fill = (sel, values, labels) => {
      const previous = sel.value;
      sel.replaceChildren(...values.map(v => new Option(labels[v] || v, v)));
      if (values.includes(previous)) sel.value = previous;
    };
    fill(langSel, [...new Set(available.map(a => a.lang))], LANG);
    fill(levelSel, available.filter(a => a.lang === langSel.value).map(a => a.level), LEVEL);
  }

  // Each section: heading + body. Paragraphs in body are separated by a blank line.
  function renderSections(container, sections) {
    container.replaceChildren();
    for (const s of sections) {
      const h = document.createElement('h2');
      h.textContent = s.heading;
      container.append(h);
      for (const para of s.body.split(/\n\s*\n/)) {
        if (!para.trim()) continue;
        const p = document.createElement('p');
        p.textContent = para.trim();
        container.append(p);
      }
    }
  }

  // Wires a page's menus and content area together. Returns open(token).
  function mount({ langSel, levelSel, card, nameEl, sectionsEl, notice, chatLink }) {
    let token = null;
    let available = [];
    const say = message => { notice.textContent = message; notice.hidden = false; card.hidden = true; };

    async function show() {
      const r = await content(token, langSel.value, levelSel.value);
      if (!r.ok) return say('This language and reading level is not available for this building yet.');
      nameEl.textContent = r.data.location;
      renderSections(sectionsEl, r.data.sections);
      if (chatLink) {
        chatLink.href = 'chat.html?token=' + encodeURIComponent(token) +
          '&language=' + encodeURIComponent(langSel.value) +
          '&reading_level=' + encodeURIComponent(levelSel.value);
      }
      card.hidden = false;
      notice.hidden = true;
    }

    async function open(t) {
      if (!t) return say('Scan a USC AI Tours QR code to open a building.');
      const r = await summary(t);
      if (!r.ok) return say('This QR code does not match a building in the tour.');
      token = t;
      available = r.data.available || [];
      fillPickers(available, langSel, levelSel);
      await show();
    }

    langSel.addEventListener('change', () => {
      if (!token) return;
      fillPickers(available, langSel, levelSel);
      show().catch(() => say('Building information could not be loaded. Please try again.'));
    });
    levelSel.addEventListener('change', () => {
      if (token) show().catch(() => say('Building information could not be loaded. Please try again.'));
    });

    return { open: t => open(t).catch(() => say('Building information could not be loaded. Please try again.')), say };
  }

  return { list, summary, content, fillPickers, renderSections, mount };
})();
