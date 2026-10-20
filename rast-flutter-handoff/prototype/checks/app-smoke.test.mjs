/**
 * Event/runtime smoke checks without a browser or an external dependency.
 * The small DOM implements only selectors/events used by this prototype.
 * This verifies navigation and state/markup, not CSS layout or native permissions.
 */
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
import * as rules from '../dist/rules.js';

const source = (await readFile(new URL('../dist/app.js', import.meta.url), 'utf8'))
  .replace(/^import\s+[\s\S]*?\s+from\s+['"][^'"]+['"];?\s*/gm, '');
const storySource = (await readFile(new URL('../dist/how-it-works.js', import.meta.url), 'utf8'))
  .replace(/^export\s+/gm, '');
const decode = s => s.replace(/&(?:amp|lt|gt|quot|#39);/g, x => ({ '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'" })[x]);

class Element {
  constructor(tag, document, attrs = {}) {
    this.tagName = tag.toLowerCase(); this.document = document; this.attrs = attrs;
    this.children = []; this.parentElement = null; this.style = { setProperty(key, value) { this[key] = String(value); }, removeProperty(key) { delete this[key]; } }; this.scrollTop = 0;
    this.scrollHeight = 1000; this.clientWidth = 280; this._html = '';
    this.value = attrs.value ?? ''; this.checked = 'checked' in attrs;
    this.classList = {
      contains: c => this.className.split(/\s+/).includes(c),
      add: c => { if (!this.classList.contains(c)) this.className += ` ${c}`; },
      remove: c => { this.className = this.className.split(/\s+/).filter(x => x !== c).join(' '); },
      toggle: (c, force) => { const add = force ?? !this.classList.contains(c); if (add) this.classList.add(c); else this.classList.remove(c); return add; },
    };
  }
  get dataset() {
    const values = Object.fromEntries(Object.entries(this.attrs).filter(([key]) => key.startsWith('data-')).map(([key, value]) => [key.slice(5).replace(/-([a-z])/g, (_, letter) => letter.toUpperCase()), value]));
    return new Proxy(values, { set: (target, key, value) => { const attribute = `data-${String(key).replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`)}`; this.attrs[attribute] = String(value); target[key] = String(value); return true; } });
  }
  get id() { return this.attrs.id || ''; }
  get name() { return this.attrs.name || ''; }
  get disabled() { return 'disabled' in this.attrs; }
  get className() { return this.attrs.class || ''; }
  set className(value) { this.attrs.class = value; }
  get isConnected() { let p = this; while (p.parentElement) p = p.parentElement; return p === this.document.root; }
  setAttribute(key, value) { this.attrs[key] = String(value); }
  removeAttribute(key) { delete this.attrs[key]; }
  getAttribute(key) { return this.attrs[key] ?? null; }
  getBoundingClientRect() { return { left: 0, top: 0, width: this.clientWidth, height: 812, right: this.clientWidth, bottom: 812 }; }
  append(node) { this.children.push(node); node.parentElement = this; }
  remove() { if (this.parentElement) this.parentElement.children = this.parentElement.children.filter(x => x !== this); this.parentElement = null; }
  get textContent() { return this.children.map(x => typeof x === 'string' ? x : x.textContent).join(''); }
  set textContent(value) { this.children = [String(value)]; }
  get innerHTML() { return this._html; }
  set innerHTML(value) {
    this._html = value;
    this.children.forEach(x => { if (x instanceof Element) x.parentElement = null; });
    this.children = [];
    const stack = [this];
    for (const token of value.match(/<[^>]+>|[^<]+/g) || []) {
      if (token.startsWith('</')) {
        const tag = token.match(/^<\/([^\s>]+)/)[1].toLowerCase();
        const index = stack.findLastIndex(x => x.tagName === tag);
        if (index > 0) stack.length = index;
      } else if (/^<[A-Za-z]/.test(token)) {
        const [, tag, rest] = token.match(/^<([^\s/>]+)([\s\S]*)>$/);
        const attrs = {};
        for (const match of rest.matchAll(/([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) attrs[match[1]] = decode(match[2] ?? match[3] ?? match[4] ?? '');
        const node = new Element(tag, this.document, attrs); stack.at(-1).append(node);
        if (!/\/>$/.test(token) && !['img', 'input', 'br', 'hr', 'meta', 'link'].includes(tag)) stack.push(node);
      } else if (!token.startsWith('<!')) stack.at(-1).children.push(decode(token));
    }
    for (const select of this.querySelectorAll('select')) {
      const option = select.querySelector('[selected]') || select.querySelector('option');
      select.value = option?.attrs.value ?? option?.textContent ?? '';
    }
  }
  simpleMatches(selector) {
    if (selector.includes(':not(:disabled)') && this.disabled) return false;
    selector = selector.replace(':not(:disabled)', '');
    const tag = selector.match(/^[a-zA-Z][\w-]*/)?.[0];
    if (tag && tag.toLowerCase() !== this.tagName) return false;
    for (const [, id] of selector.matchAll(/#([\w-]+)/g)) if (this.id !== id) return false;
    for (const [, cls] of selector.matchAll(/\.([\w-]+)/g)) if (!this.classList.contains(cls)) return false;
    for (const [, name, quoted, single, bare] of selector.matchAll(/\[([^=\]]+)(?:=(?:"([^"]*)"|'([^']*)'|([^\]]*)))?\]/g)) {
      if (!(name in this.attrs)) return false;
      const wanted = quoted ?? single ?? bare;
      if (wanted !== undefined && this.attrs[name] !== wanted) return false;
    }
    return true;
  }
  matches(selector) {
    return selector.split(',').some(group => {
      const parts = group.trim().split(/\s+/);
      if (!this.simpleMatches(parts.pop())) return false;
      let parent = this.parentElement;
      while (parts.length) { const part = parts.pop(); while (parent && !parent.simpleMatches(part)) parent = parent.parentElement; if (!parent) return false; parent = parent.parentElement; }
      return true;
    });
  }
  querySelectorAll(selector) {
    const result = [];
    const walk = element => { for (const child of element.children) if (child instanceof Element) { if (child.matches(selector)) result.push(child); walk(child); } };
    walk(this); return result;
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
  closest(selector) { let el = this; while (el && !el.matches(selector)) el = el.parentElement; return el; }
  focus() { this.document.activeElement = this; }
  scrollIntoView() {}
  setPointerCapture() {}
  click() { if (!this.disabled) this.document.emit('click', this); }
  requestSubmit() { this.document.emit('submit', this); }
}

function boot({ reducedMotion = false, darkMode = false, savedStorage = new Map(), intersectionObserver = false, failStorageWrites = false } = {}) {
  const listeners = new Map(), windowListeners = new Map();
  const document = {
    title: '', hidden: false, visibilityState: 'visible',
    addEventListener(name, fn) { const list = listeners.get(name) || []; list.push(fn); listeners.set(name, list); },
    emit(type, target, extra = {}) { const event = { type, target, prevented: false, preventDefault() { this.prevented = true; }, stopPropagation() {}, ...extra }; for (const fn of listeners.get(type) || []) fn(event); return event; },
    querySelector(selector) { return this.root.querySelector(selector); },
    querySelectorAll(selector) { return this.root.querySelectorAll(selector); },
    createElement(tag) { return new Element(tag, this); },
  };
  document.root = document.documentElement = new Element('html', document);
  document.root.innerHTML = '<head><meta name="theme-color" content="#faf9f6"></head><body><div id="studio"></div><div id="live-region"></div></body>';
  document.body = document.root.querySelector('body'); document.activeElement = document.body;
  const timers = new Map(), storage = savedStorage, images = [], frames = new Map(), observers = new Set();
  let timerID = 0;
  let frameID = 0, frameTime = 0;
  let storageWritesFail = failStorageWrites;
  const mediaLists = new Map();
  const matchMedia = query => {
    if (!mediaLists.has(query)) {
      const mediaListeners = new Set();
      mediaLists.set(query, {
        matches: query === '(prefers-reduced-motion: reduce)' ? reducedMotion : query === '(prefers-color-scheme: dark)' ? darkMode : false,
        media: query,
        addEventListener(type, fn) { if (type === 'change') mediaListeners.add(fn); },
        removeEventListener(type, fn) { if (type === 'change') mediaListeners.delete(fn); },
        addListener(fn) { mediaListeners.add(fn); }, removeListener(fn) { mediaListeners.delete(fn); },
        change(matches) { this.matches = matches; for (const fn of [...mediaListeners]) if (mediaListeners.has(fn)) fn({ matches, media: query }); },
      });
    }
    return mediaLists.get(query);
  };
  const location = new URL('https://rast.example/');
  const window = {
    matchMedia, location, history: { replaceState() {}, pushState() {} },
    addEventListener(type, fn) { const callbacks = windowListeners.get(type) || new Set(); callbacks.add(fn); windowListeners.set(type, callbacks); },
    removeEventListener(type, fn) { windowListeners.get(type)?.delete(fn); },
  };
  // Other tabs share storage, but delivery can be delayed; tests emit window events explicitly.
  const emitWindow = (type, values = {}) => { const event = { type, target: window, ...values }; for (const fn of [...(windowListeners.get(type) || [])]) fn(event); };
  class SceneObserver {
    constructor(callback) { this.callback = callback; this.targets = new Set(); observers.add(this); }
    observe(target) { this.targets.add(target); }
    disconnect() { this.targets.clear(); observers.delete(this); }
  }
  const context = vm.createContext({
    ...rules, document, Element, Date, Intl, console,
    ...(intersectionObserver ? { IntersectionObserver: SceneObserver } : {}),
    window,
    location,
    performance: { now: () => frameTime },
    requestAnimationFrame: fn => { const id = frameID++; frames.set(id, fn); return id; },
    cancelAnimationFrame: id => frames.delete(id),
    localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => { if (storageWritesFail) throw new Error('Simulated storage write failure'); storage.set(k, v); }, removeItem: k => storage.delete(k) },
    setTimeout: (fn, delay) => { const id = ++timerID; timers.set(id, { fn, delay }); return id; },
    clearTimeout: id => timers.delete(id), queueMicrotask: fn => fn(),
    URL: { createObjectURL: f => `blob:${f.name}`, revokeObjectURL() {} },
    Image: class { constructor() { images.push(this); } },
    FormData: class {
      constructor(form) { this.values = Object.fromEntries(form.querySelectorAll('input,select,textarea').filter(el => el.name && (el.attrs.type !== 'checkbox' || el.checked)).map(el => [el.name, el.attrs.type === 'checkbox' ? 'on' : el.value])); }
      get(name) { return this.values[name] ?? null; }
    },
  });
  const storyModule = vm.runInContext(`(()=>{${storySource}\nreturn {createHowState,howMarkup,mountHowStory,howFrame,HOW_DURATION,HOW_STEPS};})()`, context, { filename: 'dist/how-it-works.js' });
  Object.assign(context, storyModule);
  vm.runInContext(source + '\n;globalThis.app = {state,SCREENS,PEOPLE,navigate,eligiblePeople,incomingLikes,render,get howPlayback(){return howPlayback;},get howController(){return howController;}};', context, { filename: 'dist/app.js' });
  const find = selector => { const el = document.querySelector(selector); assert.ok(el, `Missing rendered element: ${selector}`); return el; };
  const click = selector => find(selector).click();
  const input = (selector, value) => { const el = find(selector); el.value = value; document.emit('input', el); return el; };
  const submit = (name, fields = {}) => { const form = find(`form[data-form="${name}"]`); for (const [key, value] of Object.entries(fields)) { const field = form.querySelector(`[name="${key}"]`); assert.ok(field, `Missing field ${key}`); if (typeof value === 'boolean') field.checked = value; else field.value = value; } document.emit('submit', form); };
  const flush = max => { for (const [id, timer] of [...timers]) if (timer.delay <= max) { timers.delete(id); timer.fn(); } };
  const frame = (milliseconds = 16) => {
    frameTime += milliseconds;
    // Only callbacks already queued at this frame may run. New requests wait for the next frame.
    for (const [id, fn] of [...frames]) if (frames.get(id) === fn) { frames.delete(id); fn(frameTime); }
  };
  // Required playback credits at most 100 ms per presented frame. The caller seeds its first frame.
  const advanceRequired = milliseconds => { for (let remaining = milliseconds; remaining > 0;) { const elapsed = Math.min(100, remaining); frame(elapsed); remaining -= elapsed; } };
  const intersect = ratio => { for (const observer of [...observers]) observer.callback([...observer.targets].map(target => ({ target, isIntersecting: ratio > 0, intersectionRatio: ratio }))); };
  const setHidden = hidden => { document.hidden = hidden; document.visibilityState = hidden ? 'hidden' : 'visible'; document.emit('visibilitychange', document.root); };
  const setReducedMotion = matches => matchMedia('(prefers-reduced-motion: reduce)').change(matches);
  const setDarkMode = matches => matchMedia('(prefers-color-scheme: dark)').change(matches);
  const setStorageWriteFailure = fail => { storageWritesFail = fail; };
  const upload = (index, name, type = 'image/jpeg', size = 1000) => { click(`[data-upload="${index}"]`); const el = find('#photo-upload'); el.files = [{ name, type, size }]; document.emit('change', el); };
  return { ...context.app, ...storyModule, document, find, click, input, submit, flush, upload, images, storage, frame, advanceRequired, intersect, emitWindow, setHidden, setReducedMotion, setDarkMode, setStorageWriteFailure, pendingFrames: () => frames.size, activeObservers: () => observers.size, get howPlayback() { return context.app.howPlayback; }, get howController() { return context.app.howController; } };
}

const INTRO_KEY = 'rast-intro-v1';
const SETTINGS_KEY = 'rast-design-settings';
const SAFETY_KEY = 'rast-safety-v1';
const introStorage = status => new Map([[INTRO_KEY, JSON.stringify({ status })]]);
function completeSignup(b, locationGranted) {
  b.click('[data-action="start-signup"]'); b.click('.welcome .primary');
  b.submit('phone', { phone: '7700 900 123', dial: '+44' });
  b.submit('otp', { code: '246810' });
  b.click('[data-gender="woman"]'); b.submit('basics', { age: '28' });
  b.click('[data-action="preferences-next"]');
  b.click('[data-action="fill-step"]'); b.click('[data-action="photos-next"]');
  assert.equal(b.state.screen, 'permission');
  b.click(`[data-action="${locationGranted ? 'allow' : 'deny'}-location"]`);
}
function focusMutualProfile(b) {
  const person = b.eligiblePeople().find(candidate => candidate.id === 'p1') || b.eligiblePeople().find(candidate => candidate.likesYou);
  assert.ok(person?.likesYou, 'fixture must have a mutually interested profile');
  b.state.focusPerson = person.id; b.navigate('discover');
  assert.equal(b.find('[data-card]').dataset.card, person.id);
  return person.id;
}

let passed = 0, failed = 0;
function check(name, fn) { try { fn(); console.log(`PASS ${name}`); passed++; } catch (error) { console.error(`FAIL ${name}: ${error.message}`); failed++; } }

check('initial discover renders and excludes already matched profiles', () => {
  const b = boot(); assert.equal(b.state.screen, 'discover'); assert.ok(b.find('[data-card]'));
  assert.equal(b.state.premium, false);
  const seen = b.eligiblePeople().map(p => p.id);
  assert.ok(seen.length > 0); assert.ok(!b.state.threads.some(t => seen.includes(t.person)));
});

check('welcome CTA reaches phone; phone and OTP reject wrong values and advance valid ones', () => {
  const b = boot(); b.click('[data-action="start-signup"]'); assert.equal(b.state.screen, 'welcome');
  b.click('.welcome .primary'); assert.equal(b.state.screen, 'phone');
  b.submit('phone', { phone: '123', dial: '+90' }); assert.equal(b.state.screen, 'phone');
  assert.match(b.find('#form-error').textContent, /10|valid|number/i);
  b.submit('phone', { phone: '555 010 00 00', dial: '+90' }); assert.equal(b.state.screen, 'otp');
  b.submit('otp', { code: '000000' }); assert.equal(b.state.screen, 'otp'); assert.equal(b.state.verified, false);
  b.submit('otp', { code: '246810' }); assert.equal(b.state.screen, 'basics'); assert.equal(b.state.verified, true);
});

check('signup explicitly requires own age and gender; numeric age accepts only 18 through 130', () => {
  const b = boot(); b.click('[data-action="start-signup"]'); b.navigate('basics');
  const age = b.find('#your-age');
  assert.equal(age.name, 'age'); assert.equal(age.attrs.type, 'number');
  assert.equal(age.attrs.min, '18'); assert.equal(age.attrs.max, '130'); assert.ok('required' in age.attrs);
  assert.equal(age.value, ''); assert.equal(b.state.gender, '');
  assert.equal(b.document.querySelector('[name="dob"]'), null);
  for (const value of ['', '17', '131', '27.5', 'invalid']) {
    b.submit('basics', { age: value }); assert.equal(b.state.screen, 'basics', `age ${value} must not advance`);
  }
  b.submit('basics', { age: '18' }); assert.equal(b.state.screen, 'basics', 'gender must be explicitly selected');
  b.click('[data-gender="woman"]'); b.submit('basics', { age: '18' });
  assert.equal(b.state.screen, 'preferences'); assert.equal(b.state.age, 18);
  b.navigate('basics'); b.submit('basics', { age: '130' });
  assert.equal(b.state.screen, 'preferences'); assert.equal(b.state.age, 130);
});

check('self-described gender stays optional but requires a description when selected', () => {
  const b = boot(); b.click('[data-action="start-signup"]'); b.navigate('basics');
  b.click('[data-gender="self"]'); b.submit('basics', { age: '28' }); assert.equal(b.state.screen, 'basics');
  b.input('[name="customGender"]', 'Genderqueer'); b.submit('basics', { age: '28', showGender: true });
  assert.equal(b.state.screen, 'preferences'); assert.equal(b.state.customGender, 'Genderqueer'); assert.equal(b.state.showGender, true);
});

check('empty preferences and missing photos block onboarding, four photos permit the introduction', () => {
  const b = boot(); b.click('[data-action="start-signup"]'); b.navigate('preferences');
  // Establish an adult account before exercising the later onboarding steps.
  b.state.age = 28; b.state.ageInput = '28'; b.state.gender = 'woman'; b.state.verified = true;
  b.click('[data-pref="woman"]'); b.click('[data-pref="woman"]'); b.click('[data-action="preferences-next"]'); assert.equal(b.state.screen, 'preferences');
  b.click('[data-pref="all"]'); b.click('[data-action="preferences-next"]'); assert.equal(b.state.screen, 'photos');
  assert.equal(b.find('[data-action="photos-next"]').disabled, true); assert.equal(b.eligiblePeople().length, 0);
  b.click('[data-action="fill-step"]'); assert.equal(b.state.photos.filter(Boolean).length, 4);
  b.click('[data-remove-photo="0"]'); assert.equal(b.find('[data-action="photos-next"]').disabled, true);
  b.click('[data-action="fill-step"]'); b.click('[data-action="photos-next"]'); assert.equal(b.state.screen, 'permission');
  b.click('[data-action="allow-location"]'); assert.equal(b.state.screen, 'how'); assert.equal(b.state.introRequired, true); assert.equal(b.state.onboarding, false); assert.equal(b.state.location, true);
});

check('concurrent photo decodes retain their chosen slots; unsupported files stay rejected', () => {
  const b = boot(); b.state.photos = [null, null, null, null]; b.navigate('editPhotos');
  b.upload(0, 'first.jpg'); b.upload(1, 'second.jpg'); assert.equal(b.images.length, 2);
  b.images[0].onload(); b.images[1].onload();
  assert.equal(b.state.photos[0], 'blob:first.jpg'); assert.equal(b.state.photos[1], 'blob:second.jpg');
  b.upload(2, 'payload.svg', 'image/svg+xml'); assert.equal(b.images.length, 2); assert.equal(b.state.photos[2], null);
});

check('settings offer every interval through 120 seconds and delay through 24 hours with validated persistence', () => {
  const b = boot(); b.navigate('settings');
  assert.equal(b.state.interval, 30); assert.equal(b.state.delay, 2);
  assert.deepEqual(b.document.querySelectorAll('#phone-viewport [data-interval]').map(button => Number(button.dataset.interval)), [...rules.UPDATE_INTERVAL_SECONDS]);
  assert.deepEqual(b.document.querySelectorAll('#phone-viewport [data-delay]').map(button => Number(button.dataset.delay)), [...rules.REVEAL_DELAY_HOURS]);
  for (const interval of rules.UPDATE_INTERVAL_SECONDS) { b.click(`[data-interval="${interval}"]`); assert.equal(b.state.interval, interval); }
  for (const delay of rules.REVEAL_DELAY_HOURS) { b.click(`[data-delay="${delay}"]`); assert.equal(b.state.delay, delay); }
  const saved = JSON.parse(b.storage.get(SETTINGS_KEY)); assert.equal(saved.delay, 24); assert.equal(saved.interval, 120);
  const loaded = boot({ savedStorage: b.storage }); assert.equal(loaded.state.delay, 24); assert.equal(loaded.state.interval, 120);
  for (const invalid of [{ interval: 121, delay: 25 }, { interval: '120', delay: '24' }, { interval: 0, delay: 3 }]) {
    const fallback = boot({ savedStorage: new Map([[SETTINGS_KEY, JSON.stringify(invalid)]]) });
    assert.equal(fallback.state.interval, 30); assert.equal(fallback.state.delay, 2);
  }
  const person = b.PEOPLE.find(p => p.id === 'p1'); person.ago = 23.5; person.delay = 0;
  assert.ok(!b.eligiblePeople(true).some(p => p.id === person.id));
  person.ago = 24.5; assert.ok(b.eligiblePeople(true).some(p => p.id === person.id));
  b.click('[data-delay="0"]'); person.delay = 24; person.ago = 23.5;
  assert.ok(!b.eligiblePeople(true).some(p => p.id === person.id), 'the other person’s full-day delay still applies');
  person.ago = 24.5; assert.ok(b.eligiblePeople(true).some(p => p.id === person.id));
  b.click('[data-delay="2"]'); b.click('[data-interval="45"]');
  b.click('[data-action="toggle-visibility"]'); assert.equal(b.eligiblePeople().length, 0);
  b.click('[data-action="toggle-visibility"]'); assert.ok(b.eligiblePeople().length > 0);
});

check('appearance follows the live system theme, persists explicit choices and stays independent of reduced motion', () => {
  const b = boot({ darkMode: true });
  assert.equal(b.state.theme, 'system'); assert.equal(b.document.documentElement.dataset.theme, 'dark');
  b.setDarkMode(false); assert.equal(b.document.documentElement.dataset.theme, 'light');
  b.navigate('profile'); b.click('[data-action="appearance"]');
  assert.deepEqual(b.find('.sheet').querySelectorAll('[data-theme-choice]').map(button => button.dataset.themeChoice).sort(), ['dark', 'light', 'system']);
  b.click('[data-theme-choice="dark"]');
  assert.equal(b.state.theme, 'dark'); assert.equal(b.document.documentElement.dataset.theme, 'dark');
  assert.equal(JSON.parse(b.storage.get(SETTINGS_KEY)).theme, 'dark');
  b.setDarkMode(true); b.setDarkMode(false); assert.equal(b.document.documentElement.dataset.theme, 'dark');
  const loaded = boot({ savedStorage: b.storage, darkMode: false });
  assert.equal(loaded.state.theme, 'dark'); assert.equal(loaded.document.documentElement.dataset.theme, 'dark');
  loaded.navigate('profile'); loaded.click('[data-action="appearance"]'); loaded.click('[data-theme-choice="light"]');
  loaded.setDarkMode(true); assert.equal(loaded.state.theme, 'light'); assert.equal(loaded.document.documentElement.dataset.theme, 'light');
  loaded.navigate('profile'); loaded.click('[data-action="appearance"]'); loaded.click('[data-theme-choice="system"]');
  assert.equal(loaded.document.documentElement.dataset.theme, 'dark');
  loaded.setDarkMode(false); assert.equal(loaded.document.documentElement.dataset.theme, 'light');
  assert.equal(JSON.parse(loaded.storage.get(SETTINGS_KEY)).theme, 'system');
  loaded.navigate('how'); loaded.setReducedMotion(true); assert.equal(loaded.howPlayback.reduced, true); assert.equal(loaded.pendingFrames(), 0);
  loaded.setDarkMode(true); assert.equal(loaded.document.documentElement.dataset.theme, 'dark');
  assert.equal(loaded.howPlayback.reduced, true); assert.equal(loaded.pendingFrames(), 0, 'an OS color-scheme change must not turn reduced motion off');
  const fallback = boot({ darkMode: true, savedStorage: new Map([[SETTINGS_KEY, JSON.stringify({ theme: 'invalid' })]]) });
  assert.equal(fallback.state.theme, 'system'); assert.equal(fallback.document.documentElement.dataset.theme, 'dark');
});

check('one visual dual range has two handles, ordered values, 99+ and draft-only changes', () => {
  const b = boot(); b.click('[data-action="filters"]');
  assert.equal(b.find('.sheet').attrs.role, 'dialog');
  assert.equal(b.document.querySelectorAll('.dual-range').length, 1);
  assert.equal(b.find('.dual-range').querySelectorAll('input[type="range"]').length, 2);
  const initialMin = b.state.minAge;
  b.input('[data-range="minAge"]', '99'); assert.equal(b.state.draft.maxAge, 99); assert.equal(b.state.minAge, initialMin);
  assert.match(b.find('[data-range-label]').textContent, /99\+/);
  b.input('[data-range="maxAge"]', '18'); assert.equal(b.state.draft.minAge, 18); assert.equal(b.state.draft.maxAge, 18);
  b.click('[data-action="close-sheet"]'); assert.equal(b.state.minAge, initialMin);
  b.click('[data-action="filters"]'); b.input('[data-range="maxAge"]', '99'); b.click('[data-action="save-filters"]');
  assert.equal(b.state.maxAge, 99); assert.equal(b.state.sheet, null);
});

check('free swipe creates match and free chat sends escaped text once with Enter', () => {
  const b = boot(); const person = focusMutualProfile(b);
  assert.equal(b.state.premium, false);
  b.click('[data-action="like"]'); b.flush(500); assert.equal(b.state.screen, 'match');
  b.click('[data-action="start-chat"]'); assert.equal(b.state.screen, 'conversation');
  const thread = b.state.threads.find(t => t.person === person); assert.ok(thread);
  b.click('[data-action="suggest-message"]'); assert.ok(b.find('textarea[name="message"]').value.trim().length > 0);
  b.input('textarea[name="message"]', '<img src=x onerror=alert(1)> & hello');
  b.document.emit('keydown', b.find('textarea[name="message"]'), { key: 'Enter', shiftKey: false });
  assert.equal(thread.messages.length, 1); assert.match(thread.messages[0].text, /<img/);
  assert.ok(b.find('#studio').innerHTML.includes('&lt;img src=x onerror=alert(1)&gt; &amp; hello'));
  b.submit('message', { message: '  ' }); assert.equal(thread.messages.length, 1);
  assert.equal(b.state.premium, false);
});

check('report and block persists metadata and permanently removes a matched connection even after Unblock', () => {
  const b = boot(); const thread = b.state.threads[0], person = thread.person;
  b.navigate('chats'); b.click(`[data-thread="${thread.id}"]`); b.click('[data-action="person-menu"]'); b.click('[data-action="report"]');
  assert.equal(b.find('#also-block').checked, true);
  assert.equal(b.find('[data-action="submit-report"]').disabled, true);
  const reason = b.find('[data-report-reason]').dataset.reportReason;
  b.click('[data-report-reason]'); assert.equal(b.find('[data-action="submit-report"]').disabled, false);
  b.input('[name="reportDetails"]', 'Private report context must not be stored.');
  b.click('[data-action="submit-report"]'); assert.equal(b.state.screen, 'chats');
  assert.ok(b.state.blocked.includes(person)); assert.ok(b.state.disconnected.includes(person));
  assert.ok(!b.state.threads.some(t => t.person === person)); assert.ok(!b.eligiblePeople(true).some(p => p.id === person));
  const saved = JSON.parse(b.storage.get(SAFETY_KEY));
  assert.deepEqual(saved.reports, [{ person, reason }]); assert.ok(saved.blocked.includes(person)); assert.ok(saved.disconnected.includes(person));
  assert.ok(!b.storage.get(SAFETY_KEY).includes('Private report context'));
  const loaded = boot({ savedStorage: b.storage });
  assert.ok(!loaded.state.threads.some(t => t.person === person), 'saved removal must sanitize seeded conversations');
  loaded.navigate('safety'); loaded.click('[data-action="blocked-list"]'); loaded.click(`[data-unblock="${person}"]`);
  assert.ok(!loaded.state.blocked.includes(person)); assert.ok(loaded.state.disconnected.includes(person));
  loaded.state.passed = []; loaded.state.liked = []; loaded.state.history = [person];
  assert.ok(!loaded.eligiblePeople(true).some(p => p.id === person));
  for (const premium of [false, true]) { loaded.state.premium = premium; assert.ok(!loaded.incomingLikes().some(p => p.id === person)); }
  const unblocked = boot({ savedStorage: loaded.storage });
  assert.ok(!unblocked.state.blocked.includes(person)); assert.ok(unblocked.state.disconnected.includes(person));
  assert.ok(!unblocked.state.threads.some(t => t.person === person));
});

check('Remove connection survives reload and rejects stale likes, chats, messages, Undo and Premium rediscovery', () => {
  const b = boot(); const person = focusMutualProfile(b);
  b.click('[data-action="detail"]'); const staleLike = b.find('[data-action="like-detail"]');
  b.click('[data-action="like-detail"]'); assert.equal(b.state.screen, 'match');
  const staleStart = b.find('[data-action="start-chat"]'); b.click('[data-action="start-chat"]');
  const removedThread = b.state.threads.find(thread => thread.person === person); assert.ok(removedThread);
  const staleForm = b.find('form[data-form="message"]'); staleForm.querySelector('[name="message"]').value = 'Queued after removal';
  b.click('[data-action="person-menu"]'); b.click('[data-action="unmatch-confirm"]');
  assert.match(b.find('.sheet').textContent, /Remove connection/i);
  b.click('[data-action="unmatch"]'); assert.equal(b.state.screen, 'chats');
  assert.ok(b.state.disconnected.includes(person)); assert.ok(!b.state.blocked.includes(person));
  assert.ok(!b.state.threads.some(thread => thread.person === person));
  const saved = JSON.parse(b.storage.get(SAFETY_KEY)); assert.ok(saved.disconnected.includes(person));
  b.state.passed = []; b.state.liked = []; b.state.history = [person];
  b.document.emit('click', staleLike); assert.ok(!b.state.liked.includes(person));
  b.state.lastMatch = person; b.document.emit('click', staleStart);
  assert.ok(!b.state.threads.some(thread => thread.person === person));
  b.state.activeThread = removedThread.id;
  const otherMessages = JSON.stringify(b.state.threads);
  b.document.emit('submit', staleForm); assert.equal(JSON.stringify(b.state.threads), otherMessages, 'a removed conversation must not send into another person’s thread');
  b.navigate('conversation'); assert.equal(b.document.querySelector('#phone-viewport form[data-form="message"]'), null);
  b.navigate('match'); assert.equal(b.document.querySelector('#phone-viewport [data-action="start-chat"]'), null);
  b.navigate('discover'); b.click('[data-action="undo"]');
  assert.ok(!b.eligiblePeople(true).some(candidate => candidate.id === person));
  assert.notEqual(b.find('[data-card]').dataset.card, person);
  for (const premium of [false, true]) { b.state.premium = premium; b.navigate('likes'); assert.ok(!b.incomingLikes().some(candidate => candidate.id === person)); }
  const loaded = boot({ savedStorage: b.storage });
  assert.ok(loaded.state.disconnected.includes(person)); assert.ok(!loaded.eligiblePeople(true).some(candidate => candidate.id === person));
  loaded.navigate('safety'); loaded.click('[data-action="removed-list"]'); assert.equal(loaded.state.sheet, 'removed');
  assert.equal(loaded.find('.sheet').querySelectorAll('[data-unblock]').length, 0);
  loaded.click(`[data-action="report-person"][data-person="${person}"]`);
  const reason = loaded.find('[data-report-reason]').dataset.reportReason; loaded.click('[data-report-reason]');
  const alsoBlock = loaded.find('#also-block'); alsoBlock.checked = false; loaded.document.emit('change', alsoBlock);
  loaded.click('[data-action="submit-report"]');
  assert.ok(loaded.state.disconnected.includes(person)); assert.ok(!loaded.state.threads.some(thread => thread.person === person));
  assert.deepEqual(JSON.parse(loaded.storage.get(SAFETY_KEY)).reports, [{ person, reason }]);
});

check('report-only preserves the active connection and persists only the selected category and person', () => {
  const b = boot(); const thread = b.state.threads[0], person = thread.person, messages = JSON.stringify(thread.messages);
  b.navigate('chats'); b.click(`[data-thread="${thread.id}"]`); b.click('[data-action="person-menu"]'); b.click('[data-action="report"]');
  assert.equal(b.find('#also-block').checked, true); assert.equal(b.document.querySelectorAll('[data-report-reason]').length, 5);
  const reason = 'Scam or spam'; const choice = b.document.querySelectorAll('[data-report-reason]').find(button => button.dataset.reportReason === reason); assert.ok(choice); choice.click();
  b.input('[name="reportDetails"]', 'Do not persist this private explanation.');
  const alsoBlock = b.find('#also-block'); alsoBlock.checked = false; b.document.emit('change', alsoBlock);
  b.click('[data-action="submit-report"]');
  assert.equal(b.state.screen, 'conversation'); assert.equal(b.state.sheet, null);
  assert.ok(!b.state.blocked.includes(person)); assert.ok(!b.state.disconnected.includes(person));
  assert.equal(JSON.stringify(b.state.threads.find(candidate => candidate.person === person).messages), messages);
  assert.deepEqual(JSON.parse(b.storage.get(SAFETY_KEY)), { blocked: [], disconnected: [], reports: [{ person, reason }] });
  assert.ok([...b.storage.values()].every(value => !value.includes('Do not persist this private explanation.')));
  const loaded = boot({ savedStorage: b.storage });
  assert.deepEqual(JSON.parse(loaded.storage.get(SAFETY_KEY)).reports, [{ person, reason }]);
  assert.ok(loaded.state.threads.some(candidate => candidate.person === person));
  assert.ok(!loaded.state.blocked.includes(person)); assert.ok(!loaded.state.disconnected.includes(person));
});

check('blocking an unmatched Discover profile persists the block without permanently disconnecting it', () => {
  const b = boot(); const person = focusMutualProfile(b);
  b.click('[data-action="detail"]'); b.click('[data-action="person-menu"]'); b.click('[data-action="block-confirm"]'); b.click('[data-action="block-person"]');
  assert.ok(b.state.blocked.includes(person)); assert.ok(!b.state.disconnected.includes(person));
  const loaded = boot({ savedStorage: b.storage });
  assert.ok(loaded.state.blocked.includes(person)); assert.ok(!loaded.eligiblePeople(true).some(candidate => candidate.id === person));
  loaded.navigate('safety'); loaded.click('[data-action="blocked-list"]'); loaded.click(`[data-unblock="${person}"]`);
  assert.ok(!loaded.state.blocked.includes(person)); assert.ok(!loaded.state.disconnected.includes(person));
  assert.ok(loaded.eligiblePeople(true).some(candidate => candidate.id === person));
});

check('delayed storage events read the newest safety snapshot and close an externally removed conversation', () => {
  const previous = JSON.stringify({ blocked: [], disconnected: [], reports: [] });
  const shared = new Map([[SAFETY_KEY, previous]]), b = boot({ savedStorage: shared });
  const thread = b.state.threads[0], person = thread.person;
  b.navigate('chats'); b.click(`[data-thread="${thread.id}"]`); assert.equal(b.state.screen, 'conversation');
  const latest = { blocked: [person], disconnected: [person], reports: [{ person, reason: 'Scam or spam' }] };
  shared.set(SAFETY_KEY, JSON.stringify(latest));
  b.emitWindow('storage', { key: SAFETY_KEY, newValue: previous });
  assert.deepEqual([...b.state.blocked], latest.blocked); assert.deepEqual([...b.state.disconnected], latest.disconnected);
  assert.deepEqual(JSON.parse(JSON.stringify(b.state.reports)), latest.reports);
  assert.equal(b.state.screen, 'chats'); assert.ok(!b.state.threads.some(candidate => candidate.person === person));
  assert.equal(b.document.querySelector('#phone-viewport form[data-form="message"]'), null);
  // The next delayed event still says blocked, after another tab explicitly unblocked the profile.
  shared.set(SAFETY_KEY, JSON.stringify({ ...latest, blocked: [] }));
  b.emitWindow('storage', { key: SAFETY_KEY, newValue: JSON.stringify(latest) });
  assert.ok(!b.state.blocked.includes(person)); assert.ok(b.state.disconnected.includes(person));
  assert.ok(!b.eligiblePeople(true).some(candidate => candidate.id === person));
  assert.deepEqual(JSON.parse(JSON.stringify(b.state.reports)), latest.reports);
});

check('stale-tab report, block and unblock change only their target while preserving newer safety decisions', () => {
  for (const operation of ['report', 'block', 'unblock']) {
    const firstReport = { person: 'p5', reason: 'Scam or spam' };
    const initial = { blocked: ['p1', 'p4'], disconnected: [], reports: [firstReport] };
    const shared = new Map([[SAFETY_KEY, JSON.stringify(initial)]]), b = boot({ savedStorage: shared });
    const addedReport = { person: 'p3', reason: 'Another reason' };
    if (operation === 'report') {
      const thread = b.state.threads.find(candidate => candidate.person === addedReport.person); assert.ok(thread);
      b.navigate('chats'); b.click(`[data-thread="${thread.id}"]`); b.click('[data-action="person-menu"]'); b.click('[data-action="report"]');
      const reason = b.document.querySelectorAll('[data-report-reason]').find(button => button.dataset.reportReason === addedReport.reason); assert.ok(reason); reason.click();
      const checkbox = b.find('#also-block'); checkbox.checked = false; b.document.emit('change', checkbox);
    } else if (operation === 'block') {
      b.state.focusPerson = 'p5'; b.navigate('discover'); assert.equal(b.find('[data-card]').dataset.card, 'p5');
      b.click('[data-action="detail"]'); b.click('[data-action="person-menu"]'); b.click('[data-action="block-confirm"]');
    } else {
      b.navigate('safety'); b.click('[data-action="blocked-list"]'); assert.ok(b.find('[data-unblock="p4"]'));
    }
    const latest = { blocked: ['p4', 'p6'], disconnected: ['p2'], reports: [firstReport, { person: 'p6', reason: 'May be under 18' }] };
    // This tab has not received the other tab's unblock, block, disconnect or report events yet.
    shared.set(SAFETY_KEY, JSON.stringify(latest));
    assert.ok(b.state.blocked.includes('p1')); assert.ok(!b.state.blocked.includes('p6'));
    if (operation === 'report') b.click('[data-action="submit-report"]');
    else if (operation === 'block') b.click('[data-action="block-person"]');
    else b.click('[data-unblock="p4"]');
    const expected = {
      blocked: operation === 'block' ? ['p4', 'p6', 'p5'] : operation === 'unblock' ? ['p6'] : latest.blocked,
      disconnected: latest.disconnected,
      reports: operation === 'report' ? [...latest.reports, addedReport] : latest.reports,
    };
    assert.deepEqual(JSON.parse(shared.get(SAFETY_KEY)), expected, `${operation} must preserve the latest unrelated operations`);
    assert.ok(!b.state.blocked.includes('p1'), `${operation} must not resurrect the other tab's explicitly unblocked profile`);
    assert.ok(b.state.disconnected.includes('p2')); assert.ok(!b.state.threads.some(thread => thread.person === 'p2'));
    assert.deepEqual(JSON.parse(JSON.stringify(b.state.reports)), expected.reports);
  }
});

check('removing an open detail in another tab shows unavailable instead of falling back to the first profile', () => {
  const shared = new Map(), openTab = boot({ savedStorage: shared });
  const person = openTab.eligiblePeople().find(candidate => candidate.id !== 'p1' && candidate.likesYou); assert.ok(person);
  assert.ok(openTab.eligiblePeople().some(candidate => candidate.id === 'p1'), 'p1 must stay eligible so an accidental fallback is observable');
  openTab.state.focusPerson = person.id; openTab.navigate('discover'); openTab.click('[data-action="detail"]');
  assert.equal(openTab.find('[data-action="like-detail"]').dataset.person, person.id);
  const otherTab = boot({ savedStorage: shared }); otherTab.state.focusPerson = person.id; otherTab.navigate('discover');
  otherTab.click('[data-action="detail"]'); otherTab.click('[data-action="like-detail"]'); otherTab.click('[data-action="start-chat"]');
  otherTab.click('[data-action="person-menu"]'); otherTab.click('[data-action="unmatch-confirm"]'); otherTab.click('[data-action="unmatch"]');
  assert.ok(JSON.parse(shared.get(SAFETY_KEY)).disconnected.includes(person.id));
  openTab.emitWindow('storage', { key: SAFETY_KEY, newValue: shared.get(SAFETY_KEY) });
  assert.equal(openTab.state.screen, 'detail'); assert.equal(openTab.state.focusPerson, null);
  assert.match(openTab.find('#phone-viewport').textContent, /This profile is unavailable/);
  assert.equal(openTab.document.querySelector('#phone-viewport .profile-detail-photo'), null);
  assert.equal(openTab.document.querySelector('#phone-viewport [data-action="like-detail"]'), null);
  assert.ok(openTab.eligiblePeople().some(candidate => candidate.id === 'p1'));
});

check('failed safety writes keep session removals across later reports and storage events, then persist on recovery', () => {
  const shared = new Map(), b = boot({ savedStorage: shared, failStorageWrites: true });
  const removed = focusMutualProfile(b); assert.equal(removed, 'p1');
  b.click('[data-action="detail"]'); b.click('[data-action="like-detail"]'); b.click('[data-action="start-chat"]');
  b.click('[data-action="person-menu"]'); b.click('[data-action="unmatch-confirm"]'); b.click('[data-action="unmatch"]');
  assert.ok(b.state.disconnected.includes(removed)); assert.equal(shared.has(SAFETY_KEY), false);
  const target = b.state.threads.find(thread => thread.person === 'p2'); assert.ok(target);
  b.navigate('chats'); b.click(`[data-thread="${target.id}"]`);
  const reportOnly = reason => {
    b.click('[data-action="person-menu"]'); b.click('[data-action="report"]');
    const choice = b.document.querySelectorAll('[data-report-reason]').find(button => button.dataset.reportReason === reason); assert.ok(choice); choice.click();
    const checkbox = b.find('#also-block'); checkbox.checked = false; b.document.emit('change', checkbox); b.click('[data-action="submit-report"]');
  };
  reportOnly('May be under 18');
  assert.ok(b.state.disconnected.includes(removed)); assert.ok(!b.eligiblePeople(true).some(person => person.id === removed));
  assert.equal(shared.has(SAFETY_KEY), false, 'reads succeed even though setItem fails');
  const externalReport = { person: 'p6', reason: 'Scam or spam' };
  shared.set(SAFETY_KEY, JSON.stringify({ blocked: ['p4'], disconnected: [], reports: [externalReport] }));
  b.emitWindow('storage', { key: SAFETY_KEY, newValue: shared.get(SAFETY_KEY) });
  assert.ok(b.state.disconnected.includes(removed)); assert.ok(b.state.blocked.includes('p4'));
  assert.ok(!b.eligiblePeople(true).some(person => person.id === removed));
  assert.ok(b.state.reports.some(report => report.person === 'p2' && report.reason === 'May be under 18'));
  assert.ok(b.state.reports.some(report => report.person === externalReport.person && report.reason === externalReport.reason));
  b.setStorageWriteFailure(false); reportOnly('Another reason');
  const saved = JSON.parse(shared.get(SAFETY_KEY));
  assert.deepEqual(saved.blocked, ['p4']); assert.deepEqual(saved.disconnected, [removed]);
  assert.deepEqual(saved.reports, [externalReport, { person: 'p2', reason: 'May be under 18' }, { person: 'p2', reason: 'Another reason' }]);
  const loaded = boot({ savedStorage: shared });
  assert.ok(loaded.state.disconnected.includes(removed)); assert.ok(!loaded.eligiblePeople(true).some(person => person.id === removed));
  assert.deepEqual(JSON.parse(JSON.stringify(loaded.state.reports)), saved.reports);
});

check('gallery has sixteen English screens, filters, keyboard navigation and visible help', () => {
  const b = boot(); b.click('[data-mode="gallery"]'); assert.equal(b.document.querySelectorAll('[data-select-screen]').length, 16);
  assert.ok(b.find('[data-select-screen="likes"]')); assert.ok(b.find('[data-select-screen="premium"]'));
  assert.ok(b.find('[data-select-screen="how"]'));
  assert.doesNotMatch(b.find('#studio').textContent, /Keşfet|Konum|Karşılaşmalar|Görünürlük|Fotoğraf|Şifre/);
  b.click('[data-gallery-filter="signup"]'); assert.equal(b.document.querySelectorAll('[data-select-screen]').length, 7);
  b.document.emit('keydown', b.find('[data-select-screen="phone"]'), { key: 'Enter' }); assert.equal(b.state.mode, 'app'); assert.equal(b.state.screen, 'phone');
  b.click('[data-mode="gallery"]'); b.click('[data-action="demo-help"]'); assert.equal(b.state.mode, 'app'); assert.ok(b.find('.sheet'));
  b.document.emit('keydown', b.find('.sheet'), { key: 'Escape' }); assert.equal(b.state.sheet, null);
});

check('Discover preserves pass/undo history after visiting another tab', () => {
  const b = boot(); const person = b.find('[data-card]').dataset.card;
  b.click('[data-action="pass"]'); b.flush(500); assert.ok(b.state.passed.includes(person));
  b.navigate('likes'); b.navigate('discover'); assert.notEqual(b.find('[data-card]').dataset.card, person);
  b.click('[data-action="undo"]'); assert.equal(b.find('[data-card]').dataset.card, person); assert.ok(!b.state.passed.includes(person));
  b.navigate('discover'); assert.equal(b.find('[data-card]').dataset.card, person);
});

check('Discover keeps one shuffled deck across renders, photos and tabs instead of sorting by crossing time', () => {
  const b = boot(), originalDeck = b.state.deckOrder, order = [...originalDeck];
  assert.deepEqual([...order].sort(), [...b.PEOPLE].map(person => person.id).sort());
  assert.equal(new Set(order).size, b.PEOPLE.length);
  const available = new Set(b.eligiblePeople().map(person => person.id));
  const eligibleOrder = order.filter(id => available.has(id));
  const first = b.find('[data-card]').dataset.card; assert.equal(first, eligibleOrder[0]);
  b.render(); b.click('.photo-hit[data-action="photo-next"]');
  b.navigate('likes'); b.navigate('profile'); b.navigate('discover');
  assert.deepEqual([...b.state.deckOrder], order); assert.strictEqual(b.state.deckOrder, originalDeck);
  assert.equal(b.find('[data-card]').dataset.card, first);
  // Reverse the relative crossing times while every profile remains past its delay.
  for (const person of b.PEOPLE) person.ago = 100 - person.ago;
  b.state.focusPerson = null; b.render();
  assert.equal(b.find('[data-card]').dataset.card, first, 'changed encounter timestamps must not reorder the deck');
  b.click('[data-action="pass"]'); b.flush(500); assert.equal(b.find('[data-card]').dataset.card, eligibleOrder[1]);
  b.navigate('likes'); b.navigate('discover'); assert.equal(b.find('[data-card]').dataset.card, eligibleOrder[1]);
  b.click('[data-action="undo"]'); assert.equal(b.find('[data-card]').dataset.card, first);
  assert.deepEqual([...b.state.deckOrder], order);
  b.click('[data-action="reset-demo"]'); assert.notStrictEqual(b.state.deckOrder, originalDeck);
  assert.deepEqual([...b.state.deckOrder].sort(), [...order].sort(), 'reset may reshuffle, but must retain each profile exactly once');
});

check('incoming likes obey every privacy gate before or after premium', () => {
  const cases = [
    ['outside 20 metres', (b, p) => { p.distance = 21; }],
    ['other person delay incomplete', (b, p) => { b.state.delay = 0; p.delay = 2; p.ago = 1; }],
    ['own delay incomplete', (b, p) => { b.state.delay = 2; p.delay = 0; p.ago = 1; }],
    ['visibility paused', b => { b.state.visible = false; }],
    ['location denied', b => { b.state.location = false; }],
    ['missing fourth photo', b => { b.state.photos[0] = null; }],
    ['own age under eighteen', b => { b.state.age = 17; }],
    ['other age under eighteen', (b, p) => { p.age = 17; }],
    ['outside own age preference', (b, p) => { b.state.minAge = p.age + 1; b.state.maxAge = 99; }],
    ['outside other age preference', (b, p) => { p.minAge = b.state.age + 1; p.maxAge = 99; }],
    ['own gender preferences do not match', b => { b.state.prefs = []; }],
    ['other gender preferences do not match', (b, p) => { p.preferredGenders = []; }],
    ['blocked', (b, p) => { b.state.blocked.push(p.id); }],
    ['permanently disconnected', (b, p) => { b.state.disconnected.push(p.id); }],
    ['passed', (b, p) => { b.state.passed.push(p.id); }],
    ['already liked', (b, p) => { b.state.liked.push(p.id); }],
    ['already matched', (b, p) => { b.state.threads.push({ id: 'new-match', person: p.id, unread: 0, messages: [] }); }],
  ];
  for (const [name, override] of cases) {
    const b = boot(); const p = b.incomingLikes()[0]; assert.ok(p, 'fixture must have an eligible incoming like');
    override(b, p);
    for (const premium of [false, true]) {
      b.state.premium = premium;
      assert.ok(!b.incomingLikes().some(candidate => candidate.id === p.id), `${name}, premium=${premium}`);
    }
  }
});

check('locked incoming like opens premium, demo unlock preserves the exact eligible like set', () => {
  const b = boot(); const initial = [...b.incomingLikes()].map(p => p.id).sort(); assert.ok(initial.length > 0);
  b.navigate('likes'); assert.equal(b.state.premium, false);
  const locked = b.document.querySelectorAll('#phone-viewport [data-action="open-like"]');
  assert.equal(locked.length, initial.length);
  assert.ok(locked.every(card => card.dataset.person === undefined), 'locked cards must not expose identity attributes');
  b.click('#phone-viewport [data-action="open-like"]');
  assert.equal(b.state.screen, 'premium'); assert.equal(b.state.premium, false);
  b.click('[data-action="preview-premium"]');
  assert.equal(b.state.premium, true); assert.equal(b.state.screen, 'likes');
  const after = [...b.incomingLikes()].map(p => p.id).sort(); assert.deepEqual(after, initial);
  assert.equal(b.document.querySelectorAll('#phone-viewport [data-action="open-like"]').length, initial.length);
  for (const id of after) assert.ok(b.find(`#phone-viewport [data-action="open-like"][data-person="${id}"]`));
  b.click(`#phone-viewport [data-action="open-like"][data-person="${initial[0]}"]`);
  assert.equal(b.state.screen, 'detail'); assert.equal(b.state.focusPerson, initial[0]);
  b.click('[data-action="like-detail"]');
  assert.equal(b.state.screen, 'match'); assert.equal(b.state.lastMatch, initial[0]);
  assert.ok(b.state.threads.some(t => t.person === initial[0]));
});

check('photo previous/next controls change only the current profile photo', () => {
  const b = boot(); const person = b.find('[data-card]').dataset.card;
  const view = () => { const image = b.find('[data-card] img'); return `${image.attrs.src}|${image.attrs.style}`; };
  const first = view();
  b.click('.photo-hit[data-action="photo-next"]');
  const second = view();
  assert.notEqual(second, first); assert.equal(b.find('[data-card]').dataset.card, person);
  assert.equal(b.state.photoIndex, 1); assert.equal(b.find('.photo-indicators').attrs['aria-label'], 'Photo 2 of 4');
  b.click('.photo-hit[data-action="photo-prev"]');
  assert.equal(view(), first); assert.equal(b.find('[data-card]').dataset.card, person); assert.equal(b.state.photoIndex, 0);
  assert.equal(b.state.passed.includes(person), false); assert.equal(b.state.liked.includes(person), false);
});

check('dragging a photo hit area passes once and suppresses the following photo click', () => {
  const b = boot(); const person = b.find('[data-card]').dataset.card;
  const hit = b.find('.photo-hit[data-action="photo-next"]');
  b.document.emit('pointerdown', hit, { pointerId: 1, clientX: 200, clientY: 200 });
  b.document.emit('pointermove', hit, { pointerId: 1, clientX: 90, clientY: 200 });
  b.document.emit('pointerup', hit, { pointerId: 1, clientX: 90, clientY: 200 });
  b.flush(500);
  assert.equal(b.state.passed.filter(id => id === person).length, 1);
  assert.notEqual(b.find('[data-card]').dataset.card, person);
  b.click('.photo-hit[data-action="photo-next"]');
  assert.equal(b.state.photoIndex, 0, 'the click after a recognised drag must not advance the next profile photo');
  assert.equal(b.state.liked.length, 0);
});

check('detail photo controls apply the frame view as well as its counter', () => {
  const b = boot(); b.click('[data-action="detail"]'); assert.equal(b.state.screen, 'detail');
  const view = () => { const image = b.find('.profile-detail-photo img'); return `${image.attrs.src}|${image.attrs.style}`; };
  const first = view(); b.click('[data-action="photo-next"]');
  assert.notEqual(view(), first); assert.equal(b.state.photoIndex, 1);
  b.click('[data-action="photo-prev"]'); assert.equal(view(), first); assert.equal(b.state.photoIndex, 0);
});

check('Discover detail pass returns to Discover even after an earlier Likes visit', () => {
  const b = boot(); b.navigate('likes'); b.navigate('discover');
  const person = b.find('[data-card]').dataset.card;
  b.click('[data-action="detail"]'); assert.equal(b.state.screen, 'detail');
  b.click('[data-action="pass-detail"]');
  assert.equal(b.state.screen, 'discover'); assert.ok(b.state.passed.includes(person));
});

check('a non-mutual like from Discover detail returns to Discover', () => {
  const b = boot(); const person = b.eligiblePeople().find(p => !p.likesYou); assert.ok(person);
  b.navigate('discover'); b.state.focusPerson = person.id; b.render();
  assert.equal(b.find('[data-card]').dataset.card, person.id);
  b.click('[data-action="detail"]'); assert.equal(b.state.screen, 'detail');
  b.click('[data-action="like-detail"]');
  assert.equal(b.state.screen, 'discover'); assert.ok(b.state.liked.includes(person.id));
  assert.ok(!b.state.threads.some(t => t.person === person.id));
});

check('returning to a stale detail after pausing neither exposes nor likes the profile', () => {
  const b = boot(); const person = b.find('[data-card]').dataset.card;
  b.click('[data-action="detail"]'); const staleLike = b.find('[data-action="like-detail"]');
  b.navigate('settings'); b.click('[data-action="toggle-visibility"]'); assert.equal(b.state.visible, false);
  b.navigate('detail');
  assert.equal(b.document.querySelector('#phone-viewport .profile-detail-photo'), null);
  assert.equal(b.document.querySelector('#phone-viewport [data-action="like-detail"]'), null);
  // Simulate a previously queued event: eligibility must be rechecked in the handler.
  b.document.emit('click', staleLike);
  assert.ok(!b.state.liked.includes(person)); assert.ok(!b.state.threads.some(t => t.person === person));
  assert.notEqual(b.state.screen, 'match');
});

check('story navigation owns one RAF and cleans it up on pause, hiding, navigation and gallery', () => {
  const b = boot();
  assert.equal(b.document.querySelectorAll('#phone-viewport .bottom-nav button').length, 4);
  assert.equal(b.pendingFrames(), 0);
  b.click('#phone-viewport .bottom-nav [data-screen="profile"]');
  b.click('#phone-viewport [data-action="how-it-works"]');
  assert.equal(b.state.screen, 'how'); assert.equal(b.pendingFrames(), 1);
  b.frame(0); b.frame(1000); assert.equal(b.howPlayback.time, 1000);
  b.render(); assert.equal(b.pendingFrames(), 1, 'remount must replace, not duplicate, the RAF');
  b.click('[data-story-action="toggle"]'); assert.equal(b.pendingFrames(), 0);
  const paused = b.howPlayback.time; b.frame(4000); assert.equal(b.howPlayback.time, paused);
  b.click('[data-story-action="toggle"]'); assert.equal(b.pendingFrames(), 1);
  b.frame(0); b.frame(100); const beforeHidden = b.howPlayback.time;
  b.setHidden(true); assert.equal(b.pendingFrames(), 0); b.frame(10000); assert.equal(b.howPlayback.time, beforeHidden);
  b.setHidden(false); assert.equal(b.pendingFrames(), 1); b.frame(0); b.frame(100);
  assert.equal(b.howPlayback.time, beforeHidden + 100, 'hidden time must not become animation progress');
  b.navigate('discover'); assert.equal(b.pendingFrames(), 0);
  b.click('[data-mode="gallery"]'); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.document.querySelectorAll('[data-select-screen]').length, 16);
  assert.equal(b.find('[data-select-screen="how"] [data-how-story]').dataset.crossed, 'true');
});

check('story chapter selection is static, replay reaches the end and dating account data stays unchanged', () => {
  const b = boot();
  const keys = ['interval','delay','visible','location','notifications','age','gender','customGender','showGender','prefs','minAge','maxAge','photos','phone','verified','passed','liked','blocked','history','threads','premium'];
  const account = () => JSON.stringify(Object.fromEntries(keys.map(key => [key, b.state[key]])));
  const before = account(); b.navigate('how');
  for (let step = 0; step < 5; step++) {
    b.click(`[data-story-step="${step}"]`);
    assert.equal(b.pendingFrames(), 0); assert.equal(b.howPlayback.playing, false);
    assert.equal(b.find('[data-how-story]').dataset.stage, String(step));
    assert.equal(b.find(`[data-story-step="${step}"]`).attrs['aria-pressed'], 'true');
    const time = b.howPlayback.time; b.frame(1000); assert.equal(b.howPlayback.time, time);
  }
  b.click('[data-story-action="replay"]'); assert.equal(b.howPlayback.time, 0); assert.equal(b.pendingFrames(), 1);
  b.frame(0); b.frame(b.HOW_DURATION);
  assert.equal(b.howPlayback.time, b.HOW_DURATION); assert.equal(b.howPlayback.playing, false); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.find('[data-how-message]').style.visibility, 'visible'); assert.equal(account(), before);
  b.click('.how-discover-cta'); assert.equal(b.state.screen, 'profile'); assert.equal(account(), before);
});

check('story uses centre distance at 20 m, finishes the two-hour delay and shows two likes before chat', () => {
  const b = boot();
  const frameNearDistance = target => {
    let lo = 0, hi = 6000;
    for (let i = 0; i < 40; i++) { const mid = (lo + hi) / 2; if (b.howFrame(mid).distance > target) lo = mid; else hi = mid; }
    return b.howFrame((lo + hi) / 2);
  };
  assert.equal(frameNearDistance(30).crossed, false, 'overlapping 20 m circles must not be treated as the trigger');
  assert.equal(frameNearDistance(20.1).crossed, false); assert.equal(frameNearDistance(19.9).crossed, true);
  assert.equal(b.howFrame(10600).remaining, 120); assert.equal(b.howFrame(16400).remaining, 0);
  b.navigate('how'); b.click('[data-story-action="toggle"]');
  const showAt = time => { b.howPlayback.time = time; b.render(); return b.howFrame(time); };
  const firstLike = showAt(22900); assert.equal(firstLike.youLike, true); assert.equal(firstLike.theyLike, false); assert.equal(firstLike.chat, false);
  assert.equal(b.find('[data-how-message]').style.visibility, 'hidden');
  const bothLikes = showAt(24100); assert.equal(bothLikes.youLike, true); assert.equal(bothLikes.theyLike, true); assert.equal(bothLikes.chat, false);
  assert.equal(b.find('[data-how-you-like]').style.visibility, 'visible'); assert.equal(b.find('[data-how-they-like]').style.visibility, 'visible');
  assert.equal(b.find('[data-how-message]').style.visibility, 'hidden');
  const chat = showAt(25600); assert.equal(chat.youLike && chat.theyLike && chat.chat, true);
  assert.equal(b.find('[data-how-message]').style.visibility, 'visible'); assert.equal(b.pendingFrames(), 0);
});

check('reduced motion never autoplays and remains usable when the preference changes live', () => {
  const b = boot({ reducedMotion: true }); b.navigate('how');
  assert.equal(b.howPlayback.reduced, true); assert.equal(b.howPlayback.playing, false); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.find('[data-how-play-label]').textContent, 'Next step');
  b.click('[data-story-action="toggle"]'); assert.equal(b.find('[data-how-story]').dataset.stage, '1'); assert.equal(b.pendingFrames(), 0);
  b.click('[data-story-action="replay"]'); assert.equal(b.find('[data-how-story]').dataset.stage, '0'); assert.equal(b.pendingFrames(), 0);
  b.setReducedMotion(false); assert.equal(b.howPlayback.reduced, false); assert.equal(b.pendingFrames(), 0);
  b.click('[data-story-action="toggle"]'); assert.equal(b.pendingFrames(), 1); b.frame(0); b.frame(1000);
  b.setReducedMotion(true); assert.equal(b.howPlayback.playing, false); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.find('[data-how-story]').dataset.playing, 'false');
  b.click('[data-mode="gallery"]'); assert.equal(b.pendingFrames(), 0);
  b.setReducedMotion(false);
  b.click('[data-mode="app"]'); assert.equal(b.state.screen, 'how');
  assert.equal(b.howPlayback.reduced, false, 'live remount must refresh a preference changed while in gallery');
  assert.equal(b.find('[data-how-play-label]').textContent, 'Play'); assert.equal(b.pendingFrames(), 0);
  const previous = b.howPlayback; b.navigate('discover'); const priorState = JSON.stringify(previous);
  b.setReducedMotion(true); assert.equal(JSON.stringify(previous), priorState, 'destroyed controllers must release media listeners');
});

check('both location choices require visible first playback and an explicit continue before Discover', () => {
  for (const locationGranted of [true, false]) {
    const b = boot(); completeSignup(b, locationGranted);
    assert.equal(b.state.screen, 'how'); assert.equal(b.state.location, locationGranted); assert.equal(b.state.onboarding, false);
    assert.equal(b.state.introRequired, true); assert.equal(b.state.introCompleted, false); assert.equal(b.state.introFlow, true);
    assert.deepEqual(JSON.parse(b.storage.get(INTRO_KEY)), { status: 'pending' });
    assert.equal(b.howPlayback.required, true); assert.equal(b.howPlayback.watched, 0);
    assert.equal(b.find('[data-action="intro-continue"]').disabled, true);
    assert.equal(b.find('[data-how-continue-label]').textContent, 'Watch to continue');
    assert.equal(b.document.querySelector('[data-story-action="replay"]'), null);
    assert.ok(b.document.querySelectorAll('[data-story-step]').every(button => button.disabled));
    const account = () => JSON.stringify({ age: b.state.age, gender: b.state.gender, prefs: b.state.prefs, photos: b.state.photos, location: b.state.location, delay: b.state.delay, liked: b.state.liked, passed: b.state.passed, threads: b.state.threads });
    const before = account();
    b.click('[data-story-step="4"]'); b.howController.handle('step', 4); b.howController.handle('replay');
    assert.equal(b.howPlayback.watched, 0); assert.equal(b.howPlayback.time, 0);
    b.click('[data-action="intro-continue"]'); b.navigate('profile');
    b.click('[data-mode="gallery"]'); b.click('[data-action="demo-help"]'); b.click('[data-action="reset-demo"]');
    assert.equal(b.state.screen, 'how'); assert.equal(b.state.mode, 'app'); assert.equal(b.state.sheet, null);
    assert.equal(b.state.introRequired, true); assert.equal(b.pendingFrames(), 1);
    b.frame(0); b.advanceRequired(200);
    b.click('[data-story-action="toggle"]'); assert.equal(b.pendingFrames(), 0);
    b.frame(30000); assert.equal(b.howPlayback.watched, 200, 'paused time must receive no watch credit');
    b.click('[data-story-action="toggle"]'); b.frame(0);
    const beforeStall = b.howPlayback.watched; b.frame(30000);
    assert.ok(b.howPlayback.watched - beforeStall <= 100, 'one long foreground stall must not jump past unseen scenes');
    assert.equal(b.howPlayback.complete, false); assert.equal(b.find('[data-action="intro-continue"]').disabled, true);
    b.advanceRequired(b.HOW_DURATION - b.howPlayback.watched - 1);
    assert.equal(b.howPlayback.watched, b.HOW_DURATION - 1); assert.equal(b.state.introCompleted, false);
    assert.equal(b.find('[data-action="intro-continue"]').disabled, true);
    b.frame(1);
    assert.equal(b.howPlayback.watched, b.HOW_DURATION); assert.equal(b.howPlayback.complete, true);
    assert.equal(b.state.introRequired, false); assert.equal(b.state.introCompleted, true); assert.equal(b.state.introFlow, true);
    assert.deepEqual(JSON.parse(b.storage.get(INTRO_KEY)), { status: 'complete' });
    assert.equal(b.find('[data-how-continue-label]').textContent, 'Start exploring');
    assert.equal(b.find('[data-action="intro-continue"]').disabled, false);
    assert.equal(b.find('[data-story-action="toggle"]').disabled, true); assert.equal(b.find('[data-how-play-label]').textContent, 'Complete');
    assert.equal(b.pendingFrames(), 0); assert.equal(account(), before);
    b.navigate('discover'); b.click('[data-mode="gallery"]');
    assert.equal(b.state.screen, 'how'); assert.equal(b.state.mode, 'app', 'completion still requires the visible continue action');
    b.click('[data-action="intro-continue"]');
    assert.equal(b.state.screen, 'discover'); assert.equal(b.state.introFlow, false); assert.equal(b.state.location, locationGranted);
    assert.equal(account(), before); assert.equal(b.pendingFrames(), 0);
  }
});

check('pending reload restarts the introduction; completion survives reload and later signup with optional Profile replay', () => {
  const first = boot(); completeSignup(first, true); first.frame(0); first.advanceRequired(1200);
  const resumed = boot({ savedStorage: first.storage });
  assert.equal(resumed.state.screen, 'how'); assert.equal(resumed.state.introRequired, true); assert.equal(resumed.state.introFlow, true);
  assert.equal(resumed.howPlayback.watched, 0); assert.equal(resumed.howPlayback.time, 0, 'an incomplete reload must restart rather than restore unverified progress');
  resumed.navigate('discover'); assert.equal(resumed.state.screen, 'how');
  resumed.frame(0); resumed.advanceRequired(resumed.HOW_DURATION); resumed.click('[data-action="intro-continue"]');
  const completed = boot({ savedStorage: resumed.storage });
  assert.equal(completed.state.screen, 'discover'); assert.equal(completed.state.introRequired, false); assert.equal(completed.state.introCompleted, true); assert.equal(completed.state.introFlow, false);
  completeSignup(completed, false);
  assert.equal(completed.state.screen, 'discover'); assert.equal(completed.state.location, false); assert.equal(completed.state.introCompleted, true);
  completed.navigate('profile'); completed.click('#phone-viewport [data-action="how-it-works"]');
  assert.equal(completed.howPlayback.required, false); assert.equal(completed.state.introFlow, false);
  completed.click('[data-story-step="4"]'); assert.equal(completed.find('[data-how-story]').dataset.stage, '4');
  completed.click('[data-story-action="replay"]'); assert.equal(completed.howPlayback.time, 0);
  assert.deepEqual(JSON.parse(completed.storage.get(INTRO_KEY)), { status: 'complete' });
  completed.click('.how-discover-cta'); assert.equal(completed.state.screen, 'profile');

  const settings = boot(); settings.state.location = false; settings.navigate('settings');
  settings.click('[data-action="location-help"]'); settings.click('[data-action="allow-location"]');
  assert.equal(settings.state.location, true); assert.equal(settings.state.screen, 'discover'); assert.equal(settings.state.introFlow, false);
  assert.equal(settings.storage.has(INTRO_KEY), false, 'enabling location for an existing account must not create a first-run record');
  completed.click('[data-action="reset-demo"]'); assert.equal(completed.storage.has(INTRO_KEY), false); assert.equal(completed.state.introCompleted, false);
  const deleted = boot({ savedStorage: introStorage('complete') }); deleted.navigate('safety');
  deleted.click('[data-action="delete-account"]'); deleted.click('[data-action="confirm-delete"]');
  assert.equal(deleted.storage.has(INTRO_KEY), false); assert.equal(deleted.state.introCompleted, false); assert.equal(deleted.state.screen, 'welcome');
});

check('required playback waits for 40 percent scene visibility and excludes hidden-tab and offscreen time', () => {
  const b = boot({ savedStorage: introStorage('pending'), intersectionObserver: true });
  assert.equal(b.activeObservers(), 1); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.find('[data-how-access-note]').textContent, 'Keep the illustration in view to continue.');
  b.intersect(0.39); b.frame(10000); assert.equal(b.howPlayback.watched, 0); assert.equal(b.pendingFrames(), 0);
  b.intersect(0.4); assert.equal(b.pendingFrames(), 1); b.frame(0); b.advanceRequired(1000);
  assert.equal(b.howPlayback.watched, 1000);
  b.setHidden(true); assert.equal(b.pendingFrames(), 0); b.frame(60000); assert.equal(b.howPlayback.watched, 1000);
  b.setHidden(false); assert.equal(b.pendingFrames(), 1); b.frame(0); b.advanceRequired(1000); assert.equal(b.howPlayback.watched, 2000);
  b.intersect(0.39); assert.equal(b.pendingFrames(), 0);
  assert.equal(b.find('[data-how-access-note]').textContent, 'Keep the illustration in view to continue.');
  b.frame(60000); assert.equal(b.howPlayback.watched, 2000); assert.equal(b.state.introCompleted, false);
  b.intersect(0.4); b.frame(0); b.advanceRequired(b.HOW_DURATION - b.howPlayback.watched - 1);
  assert.equal(b.state.introCompleted, false); b.frame(1); assert.equal(b.state.introCompleted, true);
  b.click('[data-action="intro-continue"]'); assert.equal(b.activeObservers(), 0); assert.equal(b.pendingFrames(), 0);
  b.intersect(1); assert.equal(b.pendingFrames(), 0, 'the departed scene must release its observer');
});

check('required reduced-motion playback uses sequential still scenes with the same unskippable visible duration', () => {
  const b = boot({ reducedMotion: true, savedStorage: introStorage('pending') });
  assert.equal(b.howPlayback.required, true); assert.equal(b.howPlayback.reduced, true); assert.equal(b.howPlayback.playing, true);
  assert.equal(b.pendingFrames(), 1); assert.equal(b.find('[data-how-play-label]').textContent, 'Pause');
  const scene = () => JSON.stringify({ a: b.find('[data-how-person-a]').attrs.transform, other: b.find('[data-how-person-b]').attrs.transform, world: b.find('[data-how-world]').style.opacity, card: b.find('[data-how-card]').style.transform, clock: b.find('[data-how-clock]').textContent });
  const firstScene = scene(); b.frame(0); b.advanceRequired(1000);
  assert.equal(b.howPlayback.watched, 1000); assert.equal(scene(), firstScene, 'the required timer must not introduce continuous movement under reduced motion');
  b.howController.handle('step', 4); b.howController.handle('replay'); b.click('[data-story-step="4"]');
  assert.equal(b.howPlayback.watched, 1000); assert.equal(b.howPlayback.time, 1000); assert.equal(b.find('[data-how-story]').dataset.stage, '0');
  b.click('[data-story-action="toggle"]'); b.frame(30000); assert.equal(b.howPlayback.watched, 1000); assert.equal(b.pendingFrames(), 0);
  b.click('[data-story-action="toggle"]'); b.frame(0); b.advanceRequired(5200);
  assert.equal(b.find('[data-how-story]').dataset.stage, '1'); const secondScene = scene(); b.advanceRequired(500);
  assert.equal(scene(), secondScene); assert.equal(b.howPlayback.watched, 6700);
  b.advanceRequired(b.HOW_DURATION - b.howPlayback.watched - 1);
  assert.equal(b.state.introCompleted, false); assert.equal(b.find('[data-action="intro-continue"]').disabled, true);
  b.frame(1); assert.equal(b.state.introCompleted, true); assert.equal(b.howPlayback.reduced, true);
  assert.equal(b.find('[data-how-message]').style.visibility, 'visible'); assert.equal(b.pendingFrames(), 0);
  b.click('[data-action="intro-continue"]'); assert.equal(b.state.screen, 'discover');
});

console.log(`${passed} passed, ${failed} failed. DOM/runtime only; no visual/browser validation.`);
if (failed) process.exitCode = 1;
