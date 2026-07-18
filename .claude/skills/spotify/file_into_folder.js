// Files a playlist into Errthang/Mine/Monthly/<year> in the Spotify web player.
// Folders are absent from the Web API; this drives the sidebar context menu instead.
// Paste into the open.spotify.com page context, then:  await filePlaylist('2026-07', '2026')
//
// Selectors key off role="menuitem" and visible text, never class names —
// Spotify's classes are build-hashed and churn on every deploy.
// Waits are polled, not fixed: submenus mount lazily and fixed sleeps race.

const PATH = ['Errthang', 'Mine', 'Monthly'];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, { timeout = 5000, interval = 100, what = 'condition' } = {}) {
  const deadline = Date.now() + timeout;
  for (;;) {
    const v = fn();
    if (v) return v;
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    await sleep(interval);
  }
}

const visibleMenus = () =>
  [...document.querySelectorAll('[role="menu"]')].filter((m) => m.getBoundingClientRect().width > 0);

const deepestMenu = () => visibleMenus().at(-1) || null;

const itemsIn = (menu) => (menu ? [...menu.querySelectorAll('[role="menuitem"]')] : []);

const itemNamed = (menu, text) => itemsIn(menu).find((i) => i.innerText.trim() === text);

const centre = (el) => {
  const r = el.getBoundingClientRect();
  return { clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 };
};

// All four events matter: the submenu does not open on pointerover alone.
function hover(el) {
  const o = { bubbles: true, cancelable: true, ...centre(el) };
  el.dispatchEvent(new PointerEvent('pointerover', { ...o, pointerId: 1, isPrimary: true }));
  el.dispatchEvent(new MouseEvent('mouseover', o));
  el.dispatchEvent(new PointerEvent('pointermove', { ...o, pointerId: 1, isPrimary: true }));
  el.dispatchEvent(new MouseEvent('mousemove', o));
}

function click(el) {
  const o = { bubbles: true, cancelable: true, ...centre(el) };
  el.dispatchEvent(new PointerEvent('pointerdown', { ...o, pointerId: 1, isPrimary: true }));
  el.dispatchEvent(new MouseEvent('mousedown', o));
  el.dispatchEvent(new PointerEvent('pointerup', { ...o, pointerId: 1, isPrimary: true }));
  el.dispatchEvent(new MouseEvent('mouseup', o));
  el.dispatchEvent(new MouseEvent('click', o));
}

// Sidebar rows are bare divs: no role, no testid, no href. Match the first text
// line; narrowest match wins so we get the row, not a wrapping container.
function sidebarRow(name) {
  let best = null;
  document.querySelectorAll('div').forEach((e) => {
    const r = e.getBoundingClientRect();
    if (r.left >= 250 || r.width < 120 || r.height < 30 || r.height > 80) return;
    if (!e.innerText || e.innerText.split('\n')[0].trim() !== name) return;
    if (!best || e.querySelectorAll('*').length < best.querySelectorAll('*').length) best = e;
  });
  return best;
}

function openContextMenu(el) {
  const o = { bubbles: true, cancelable: true, ...centre(el), button: 2 };
  el.dispatchEvent(new PointerEvent('pointerdown', { ...o, pointerId: 1, isPrimary: true }));
  el.dispatchEvent(new MouseEvent('mousedown', o));
  el.dispatchEvent(new MouseEvent('contextmenu', o));
}

function setInput(input, value) {
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  setter.call(input, value);
  input.dispatchEvent(new Event('input', { bubbles: true }));
}

async function dismissMenus() {
  if (!visibleMenus().length) return;
  document.body.click();
  await waitFor(() => visibleMenus().length === 0, { what: 'menus to close' }).catch(() => {});
}

async function renameFolder(from, to) {
  const row = await waitFor(() => sidebarRow(from), { what: `sidebar row "${from}"` });
  openContextMenu(row);
  const item = await waitFor(() => itemNamed(deepestMenu(), 'Rename'), { what: 'Rename item' });
  click(item);

  const input = await waitFor(
    () =>
      (document.activeElement instanceof HTMLInputElement && document.activeElement) ||
      [...document.querySelectorAll('input[type="text"]')].find(
        (i) => i.getBoundingClientRect().width > 0 && i.value === from,
      ),
    { what: 'rename input' },
  );
  setInput(input, to);
  input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true }));
  return waitFor(() => sidebarRow(to), { what: `renamed row "${to}"` }).then(() => true);
}

// A click-away that closed a previous menu can still be settling when the next
// contextmenu fires, and React swallows it. Re-query the row and retry.
async function openRowMenu(playlistName, attempts = 4) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    const row = sidebarRow(playlistName);
    if (!row) {
      throw new Error(
        `no sidebar row "${playlistName}" — the list is virtualised, scroll it into view first`,
      );
    }
    openContextMenu(row);
    try {
      await waitFor(() => itemNamed(deepestMenu(), 'Move to folder'), {
        timeout: 1200,
        what: '"Move to folder"',
      });
      return true;
    } catch (e) {
      lastErr = e;
      await sleep(300);
    }
  }
  throw lastErr;
}

async function filePlaylist(playlistName, folderName) {
  await dismissMenus();

  await openRowMenu(playlistName);
  // Re-query rather than reusing a node from a retried attempt: that menu may
  // have been replaced, and hovering a detached node silently does nothing.
  const move = itemNamed(deepestMenu(), 'Move to folder');
  if (!move) throw new Error('context menu vanished after opening');
  hover(move);

  let menu = await waitFor(
    () => {
      const m = deepestMenu();
      return itemNamed(m, PATH[0]) ? m : null;
    },
    { what: 'folder submenu' },
  );

  for (const step of PATH) {
    const item = await waitFor(() => itemNamed(deepestMenu(), step), { what: `folder "${step}"` });
    hover(item);
    menu = await waitFor(
      () => {
        const m = deepestMenu();
        return m && m !== menu && itemsIn(m).length ? m : null;
      },
      { what: `submenu under "${step}"` },
    );
  }

  const existing = itemNamed(menu, folderName);
  if (existing) {
    click(existing);
    await sleep(800);
    return { action: 'moved', folder: folderName, created: false };
  }

  const create = itemNamed(menu, 'Create folder');
  if (!create) throw new Error(`no "Create folder" under ${PATH.at(-1)}`);
  click(create);

  const renamed = await renameFolder('New Folder', folderName);
  return { action: 'moved', folder: folderName, created: true, renamed };
}

globalThis.filePlaylist = filePlaylist;
globalThis.spotifyDom = { sidebarRow, deepestMenu, itemNamed, itemsIn, waitFor, dismissMenus };
'loaded';
