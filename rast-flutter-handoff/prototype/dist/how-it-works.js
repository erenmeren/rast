// A self-contained, illustrative story. It never reads or changes dating data.
export const HOW_DURATION = 27400;
export const HOW_STEPS = [
  { at: 0, label: 'Cross paths', title: 'Life brings you a little closer.', copy: 'Go about your day. When someone comes within about 20 metres, your paths can cross.' },
  { at: 6200, label: 'Both fit', title: 'The connection goes both ways.', copy: 'You must both match each other’s age and gender preferences. A crossing alone isn’t enough.' },
  { at: 10600, label: 'Give it time', title: 'A little space. A little time.', copy: 'The longer privacy delay wins. Here, you choose 1 hour and they choose 2, so both wait 2 hours.' },
  { at: 16400, label: 'Discover', title: 'Now, a familiar stranger.', copy: 'Their profile appears in Discover. Your exact location and crossing time stay private.' },
  { at: 21200, label: 'Say hello', title: 'Two likes. One new beginning.', copy: 'You like each other. A chat opens. Where the conversation goes is up to you.' },
];
const HOW_POSTERS = [5900, 9900, 14000, 20000, HOW_DURATION];
const bounded = (x, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, x));
const smooth = x => { const v = bounded(x); return v * v * (3 - 2 * v); };
const during = (t, start, end) => smooth((t - start) / (end - start));
const bezier = (a, b, c, d, t) => (1-t)**3*a + 3*(1-t)**2*t*b + 3*(1-t)*t*t*c + t**3*d;
const minuteClock = minutes => `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

export function createHowState({ required = false } = {}) {
  const reduced = Boolean(window.matchMedia?.('(prefers-reduced-motion: reduce)').matches);
  return { time: reduced && !required ? HOW_POSTERS[0] : 0, playing: required || !reduced, reduced, required, watched: 0, complete: false };
}

export function howFrame(milliseconds) {
  const time = bounded(Number(milliseconds) || 0, 0, HOW_DURATION);
  const walk = smooth(time / 6000);
  const a = { x: bezier(-32, 21, 104, 142, walk), y: bezier(253, 259, 221, 205, walk) };
  const b = { x: bezier(257, 256, 231, 205, walk), y: bezier(-34, 54, 126, 174, walk) };
  // One illustrated metre is four SVG units; the actual trigger is centre distance.
  const distance = Math.hypot(a.x-b.x, a.y-b.y) / 4;
  const crossed = distance <= 20;
  const stage = HOW_STEPS.reduce((index, item, i) => time >= item.at ? i : index, 0);
  const wait = bounded((time - HOW_STEPS[2].at) / (HOW_STEPS[3].at - HOW_STEPS[2].at));
  return { time, a, b, distance, crossed, stage, wait, remaining: Math.ceil(120 * (1-wait)), youLike: time >= 22400, theyLike: time >= 23600, chat: time >= 24800 };
}

export function howMarkup({ logo, icon, gallery = false, required = false, complete = false }) {
  const uid = gallery ? 'how-gallery' : 'how-live';
  return `<section class="page how-page${required ? ' how-first-run' : ''}" data-how-story data-required="${required}" data-playing="false" data-stage="0">
    <header class="how-header">${logo}<span class="how-demo-label"><span></span>Illustrative demo</span></header>
    <div class="how-intro"><span class="how-eyebrow">${required ? 'ONE QUICK INTRODUCTION' : 'SMALL WORLD. GOOD TIMING.'}</span><h2>How a hello <span>happens.</span></h2>${required ? '<p class="how-first-message">Watch once. Then make your next move.</p>' : ''}</div>
    <div class="how-scene" role="img" aria-label="Two anonymous people move along illustrated streets toward a possible encounter." data-how-scene>
      <div class="how-scene-tag" aria-hidden="true"><span class="how-scene-index" data-how-stage-number>01</span><span data-how-scene-label>OUT IN THE WORLD</span></div>
      <svg class="how-world" viewBox="0 0 360 360" aria-hidden="true" data-how-world>
        <defs>
          <pattern id="${uid}-grain" width="9" height="9" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r=".65" fill="#d7d3cc" opacity=".35"/></pattern>
          <filter id="${uid}-shadow" x="-70%" y="-70%" width="240%" height="240%"><feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#343038" flood-opacity=".15"/></filter>
        </defs>
        <rect width="360" height="360" fill="#f2efea"/>
        <rect width="360" height="360" fill="url(#${uid}-grain)"/>
        <g fill="#e4e0d9" stroke="#d9d5cf" stroke-width="1">
          <path d="M-12 18H161Q175 18 175 32V124Q175 137 160 137H91L-12 108Z"/>
          <path d="M278 -12H377V144H268Q257 144 259 126Z"/>
          <path d="M-15 303 139 263Q152 260 156 274L174 378H-15Z"/>
          <path d="M260 247 378 211V376H263Q250 376 250 362V263Q250 250 260 247Z"/>
        </g>
        <g fill="#efede7" stroke="#d2cec6" stroke-width="1">
          <rect x="13" y="36" width="49" height="42" rx="5"/><rect x="74" y="35" width="81" height="64" rx="5"/>
          <rect x="282" y="14" width="62" height="42" rx="5"/><rect x="280" y="69" width="58" height="48" rx="5"/>
          <path d="m280 272 55-16 12 48-58 11Z"/><path d="m19 318 48-13 10 44-46 12Z"/>
        </g>
        <path d="M-28 250C63 258 113 208 173 210S285 190 389 146" fill="none" stroke="#fffdfa" stroke-width="64"/>
        <path d="M236-28C259 79 207 116 216 205S202 310 210 389" fill="none" stroke="#fffdfa" stroke-width="58"/>
        <path d="M-28 250C63 258 113 208 173 210S285 190 389 146" fill="none" stroke="#e4dfd5" stroke-width="1.5" stroke-dasharray="4 9"/>
        <path d="M236-28C259 79 207 116 216 205S202 310 210 389" fill="none" stroke="#e4dfd5" stroke-width="1.5" stroke-dasharray="4 9"/>
        <g stroke="#ddd7cc" stroke-width="5" opacity=".8">
          <path d="M183 97h54m-54 8h52m-54 8h52m-53 8h51"/>
          <path d="m281 163 14 42m-5-46 14 42m-5-47 14 43m-5-47 14 43"/>
        </g>
        <path d="M20 126 124 153Q146 159 140 174L91 192Q45 208 18 192Z" fill="#dce5d8"/>
        <g fill="#becfba" stroke="#b3c4ae" stroke-width="1">
          <circle cx="33" cy="159" r="12"/><circle cx="68" cy="170" r="10"/><circle cx="108" cy="163" r="9"/>
          <circle cx="308" cy="339" r="12"/><circle cx="326" cy="324" r="9"/>
        </g>
        <g fill="#b7b2aa"><rect x="86" y="133" width="18" height="4" rx="2" transform="rotate(16 86 133)"/><rect x="281" y="232" width="18" height="4" rx="2" transform="rotate(-15 281 232)"/></g>
        <g data-how-radius transform="translate(142 205)"><circle class="how-radius-fill" r="80"/><circle class="how-radius-line" r="80"/><path d="M0 0h80" class="how-radius-measure"/><text x="43" y="-7" class="how-radius-text">20 m</text></g>
        <line class="how-connection" x1="142" y1="205" x2="205" y2="174" data-how-connection/>
        <g data-how-person-a transform="translate(142 205)" filter="url(#${uid}-shadow)">
          <circle r="23" fill="#fff"/><circle r="19.5" fill="#292c33"/><circle cy="-5" r="5.5" fill="#fff"/><path d="M-10 12a10 10 0 0 1 20 0" fill="#fff"/>
          <rect x="-20" y="30" width="40" height="21" rx="10.5" fill="#292c33"/><text y="44" text-anchor="middle" class="how-person-label" fill="#fff">You</text>
        </g>
        <g data-how-person-b transform="translate(205 174)" filter="url(#${uid}-shadow)">
          <circle r="23" fill="#fff"/><circle r="19.5" fill="#ee7159"/><circle cy="-5" r="5.5" fill="#fff"/><path d="M-10 12a10 10 0 0 1 20 0" fill="#fff"/>
          <rect x="-34" y="30" width="68" height="21" rx="10.5" fill="#fff"/><text y="44" text-anchor="middle" class="how-person-label" fill="#8d5546">Someone</text>
        </g>
      </svg>
      <div class="how-crossing-label" data-how-crossing aria-hidden="true">${icon('mark')}<span>Your paths just crossed.</span></div>
      <div class="how-fit-overlay" data-how-fit aria-hidden="true"><div class="how-fit-check">${icon('check')}<span>You fit their preferences</span></div><div class="how-fit-check">${icon('check')}<span>They fit yours</span></div></div>
      <div class="how-wait-layer" data-how-wait aria-hidden="true">
        <div class="how-wait-kicker">A LITTLE TIME FOR PRIVACY</div>
        <div class="how-clock"><svg viewBox="0 0 160 160"><circle cx="80" cy="80" r="70" class="how-clock-track"/><circle cx="80" cy="80" r="70" class="how-clock-progress" data-how-clock-ring/><circle cx="80" cy="80" r="57" class="how-clock-face"/></svg><div class="how-clock-text">${icon('lock')}<strong data-how-clock>02:00</strong><span>HOURS : MINUTES</span></div></div>
        <div class="how-delay-pair"><span>You <b>1h</b></span>${icon('arrow')}<span class="how-delay-longer">Them <b>2h</b></span></div>
        <span class="how-time-note">${icon('clock')}Time fast-forwarded · 2h is the default</span>
      </div>
      <div class="how-discover-layer" data-how-reveal aria-hidden="true">
        <div class="how-ready-pill">${icon('check')}Ready in Discover</div>
        <div class="how-paper-card behind"></div><div class="how-paper-card behind two"></div>
        <div class="how-mini-card" data-how-card><img src="assets/portrait-1.jpg" alt="" draggable="false"><div class="how-mini-card-shade"></div><div class="how-mini-photo-bars"><i></i><i></i><i></i><i></i></div><div class="how-mini-card-label"><strong>27</strong><span>You crossed paths.</span></div><span class="how-mini-heart">${icon('heart')}</span></div>
      </div>
      <div class="how-hello-layer" data-how-hello aria-hidden="true">
        <div class="how-hello-kicker">YOUR MOVE. THEIR MOVE.</div>
        <div class="how-hello-pair"><div class="how-hello-person"><img src="assets/portrait-7.jpg" alt="" draggable="false"><span class="how-like-stamp" data-how-you-like>${icon('heart')}</span></div><div class="how-hello-person other"><img src="assets/portrait-1.jpg" alt="" draggable="false"><span class="how-like-stamp" data-how-they-like>${icon('heart')}</span></div></div>
        <div class="how-like-captions"><span data-how-you-label>Your like</span><span data-how-they-label>Their like</span></div>
        <div class="how-message" data-how-message><span class="how-message-avatar"><img src="assets/portrait-1.jpg" alt=""></span><div><span>YOUR NEXT HELLO</span><p>Hey. Coffee sometime?</p></div>${icon('chat')}</div>
      </div>
      <span class="how-map-note" data-how-map-note aria-hidden="true">AN ILLUSTRATED CROSSING · NOT A LIVE MAP</span>
    </div>
    <div class="how-player"><button class="how-control how-play" data-story-action="toggle" aria-label="Pause animation"><span class="how-play-symbol">${icon('play')}</span><span class="how-pause-symbol">${icon('pause')}</span><span data-how-play-label>Pause</span></button><span class="how-time" data-how-time>0:00 / 0:27</span>${required ? `<span class="how-once-label">${icon('check')}Just this once</span>` : `<button class="how-control how-replay" data-story-action="replay" aria-label="Replay animation">${icon('rewind')}Replay</button>`}</div>
    <div class="how-chapters" role="group" aria-label="${required ? 'Introduction progress' : 'Animation chapters'}">${HOW_STEPS.map((s,i)=>`<button data-story-step="${i}" aria-label="Step ${i+1}: ${s.label}" aria-pressed="${i===0}"${required ? ' disabled' : ''}><span class="how-chapter-track"><i></i></span><span class="how-chapter-label">${s.label}</span></button>`).join('')}</div>
    <div class="how-narration" aria-live="polite" aria-atomic="true"><span class="how-step-counter" data-how-counter>01 / 05</span><h3 data-how-title>${HOW_STEPS[0].title}</h3><p data-how-copy>${HOW_STEPS[0].copy}</p></div>
    ${required ? `<button class="primary how-discover-cta" data-action="intro-continue" data-how-continue${complete ? '' : ' disabled'}><span data-how-continue-label>${complete ? 'Start exploring' : 'Watch to continue'}</span>${icon('arrow')}</button>` : `<button class="primary how-discover-cta" data-screen="profile">Back to Profile ${icon('arrow')}</button>`}
    <p class="how-access-note" data-how-access-note>A short illustration. You control the next move.</p>
  </section>`;
}

export function mountHowStory(root, model, { poster = false, onComplete = () => {} } = {}) {
  const el = selector => root.querySelector(selector);
  const refs = Object.fromEntries(['world','radius','person-a','person-b','connection','crossing','fit','wait','clock','clock-ring','reveal','card','hello','you-like','they-like','you-label','they-label','message','map-note','stage-number','scene-label','scene','counter','title','copy','time','play-label','access-note','continue','continue-label'].map(name=>[name,el(`[data-how-${name}]`)]));
  const chapters = [...root.querySelectorAll('[data-story-step]')];
  const play = root.querySelector('[data-story-action="toggle"]');
  const media = window.matchMedia?.('(prefers-reduced-motion: reduce)');
  let raf = null, previous = null, generation = 0, destroyed = false, lastStage = -1, lastSecond = -1, inView = true;
  if (!poster) { model.reduced = Boolean(media?.matches); if (model.reduced && !model.required) model.playing = false; }
  const opacity = (element, value) => { element.style.opacity = String(bounded(value)); element.style.visibility = value > .001 ? 'visible' : 'hidden'; };
  function paint() {
    const progress = howFrame(model.time);
    // Required reduced-motion playback advances still scenes on the same timer.
    // A poster never advances the watch counter or completes the introduction.
    const f = model.required && model.reduced ? howFrame(HOW_POSTERS[progress.stage]) : progress, t = f.time;
    root.setAttribute('data-playing', String(model.playing && (!model.reduced || model.required) && !poster));
    root.setAttribute('data-stage', String(progress.stage));
    root.setAttribute('data-crossed', String(f.crossed));
    refs.radius.setAttribute('transform', `translate(${f.a.x.toFixed(2)} ${f.a.y.toFixed(2)})`);
    refs['person-a'].setAttribute('transform', `translate(${f.a.x.toFixed(2)} ${f.a.y.toFixed(2)})`);
    refs['person-b'].setAttribute('transform', `translate(${f.b.x.toFixed(2)} ${f.b.y.toFixed(2)})`);
    refs.connection.setAttribute('x1', f.a.x); refs.connection.setAttribute('y1', f.a.y);
    refs.connection.setAttribute('x2', f.b.x); refs.connection.setAttribute('y2', f.b.y);
    opacity(refs.connection, f.crossed ? 1 : 0);
    opacity(refs.world, 1 - .91 * during(t, 10200, 11000));
    opacity(refs.crossing, (f.crossed ? 1 : 0) * (1 - during(t, 6400, 6900)));
    opacity(refs.fit, during(t, 6500, 7100) * (1 - during(t, 10300, 10600)));
    opacity(refs.wait, during(t, 10600, 11100) * (1 - during(t, 15900, 16400)));
    refs.clock.textContent = minuteClock(f.remaining);
    refs['clock-ring'].style.strokeDashoffset = String(439.823 * f.wait);
    opacity(refs.reveal, during(t, 16400, 17100) * (1 - during(t, 21200, 21800)));
    refs.card.style.transform = `translateY(${(1-during(t,16400,17400))*40}px) rotate(${(1-during(t,16400,17400))*-6}deg)`;
    opacity(refs.hello, during(t, 21300, 22000));
    const yourLike = during(t, 22400, 22900), theirLike = during(t, 23600, 24100), message = during(t, 24800, 25600);
    opacity(refs['you-like'],yourLike); opacity(refs['they-like'],theirLike);
    refs['you-like'].style.transform = `scale(${.7+.3*yourLike}) rotate(-8deg)`;
    refs['they-like'].style.transform = `scale(${.7+.3*theirLike}) rotate(8deg)`;
    refs['you-label'].style.opacity = String(.3+.7*yourLike); refs['they-label'].style.opacity = String(.3+.7*theirLike);
    opacity(refs.message,message); refs.message.style.transform = `translateY(${(1-message)*15}px)`;
    opacity(refs['map-note'], 1-during(t,10200,10600));
    chapters.forEach((button,i)=>{
      const end = HOW_STEPS[i+1]?.at || HOW_DURATION;
      const chapterProgress = model.required && model.reduced ? (model.complete || i < progress.stage ? 1 : 0) : bounded((progress.time-HOW_STEPS[i].at)/(end-HOW_STEPS[i].at));
      button.style.setProperty('--chapter-progress',`${chapterProgress*100}%`);
      button.setAttribute('aria-pressed',String(i===progress.stage));
    });
    if (progress.stage !== lastStage) {
      lastStage = progress.stage;
      const step = HOW_STEPS[progress.stage];
      refs.counter.textContent = `${String(progress.stage+1).padStart(2,'0')} / 05`;
      refs['stage-number'].textContent = String(progress.stage+1).padStart(2,'0');
      refs['scene-label'].textContent = ['OUT IN THE WORLD','THE FIT IS MUTUAL','PRIVACY SETS THE PACE','A NEW POSSIBILITY','THE NEXT MOVE IS YOURS'][progress.stage];
      refs.title.textContent = step.title; refs.copy.textContent = step.copy;
      refs.scene.setAttribute('aria-label',`${step.title} ${step.copy} This is an illustrative demo.`);
    }
    const second = Math.floor(progress.time/1000);
    if(second!==lastSecond){lastSecond=second;refs.time.textContent=`0:${String(second).padStart(2,'0')} / 0:27`;}
    const playLabel = model.required && model.complete ? 'Complete' : model.reduced && !model.required ? 'Next step' : model.playing ? 'Pause' : progress.time>=HOW_DURATION ? 'Replay' : 'Play';
    refs['play-label'].textContent=playLabel; play.setAttribute('aria-label',`${playLabel}${model.reduced || model.complete?'':' animation'}`);
    if(model.required && model.complete)play.setAttribute('disabled','');
    if(model.required && refs.continue){
      if(model.complete)refs.continue.removeAttribute('disabled');else refs.continue.setAttribute('disabled','');
      refs['continue-label'].textContent=model.complete?'Start exploring':'Watch to continue';
    }
    refs['access-note'].textContent=model.required ? model.complete ? 'All set. Replay this anytime from Profile.' : !inView && !poster ? 'Keep the illustration in view to continue.' : model.reduced ? 'Reduced motion is on. The five scenes advance automatically.' : 'A short introduction, just once before you begin.' : model.reduced?'Motion is reduced. Select a chapter to explore.':'Replay this anytime from your profile.';
  }
  function cancel(){generation++;if(raf!==null && typeof cancelAnimationFrame==='function')cancelAnimationFrame(raf);raf=null;previous=null;}
  function schedule(){
    if(destroyed||poster||!root.isConnected||!model.playing||(model.reduced&&!model.required)||document.hidden||!inView||raf!==null||typeof requestAnimationFrame!=='function')return;
    const token=generation;
    raf=requestAnimationFrame(timestamp=>{
      raf=null;if(destroyed||token!==generation||!root.isConnected)return;
      if(document.hidden||!inView){previous=null;return;}
      if(previous!==null){
        const elapsed=Math.max(0,timestamp-previous);
        // A stalled foreground tab must not jump over scenes nobody has seen.
        if(model.required){model.watched=Math.min(HOW_DURATION,model.watched+Math.min(elapsed,100));model.time=model.watched;}
        else model.time=Math.min(HOW_DURATION,model.time+elapsed);
      }
      previous=timestamp;
      if(model.time>=HOW_DURATION){
        model.playing=false;
        if(model.required&&!model.complete&&model.watched>=HOW_DURATION){model.complete=true;onComplete();}
      }
      paint();schedule();
    });
  }
  function setStep(index){cancel();model.playing=false;model.time=HOW_POSTERS[bounded(Number(index)||0,0,4)];paint();}
  function handle(action,value){
    if(destroyed||poster)return;
    if(model.required&&(action!=='toggle'||model.complete))return;
    if(action==='step'){setStep(value);return;}
    if(action==='replay'){cancel();model.time=model.reduced?HOW_POSTERS[0]:0;model.playing=!model.reduced;paint();schedule();return;}
    if(action==='toggle'){
      if(model.reduced&&!model.required){setStep((howFrame(model.time).stage+1)%5);return;}
      cancel();if(model.time>=HOW_DURATION)model.time=0;model.playing=!model.playing;paint();schedule();
    }
  }
  function visibility(){cancel();paint();schedule();}
  function motionChanged(event){cancel();model.reduced=Boolean(event.matches);if(model.reduced&&!model.required){model.playing=false;model.time=HOW_POSTERS[howFrame(model.time).stage];}paint();schedule();}
  const observer=!poster&&model.required&&typeof IntersectionObserver==='function'?new IntersectionObserver(entries=>{
    const entry=entries.find(item=>item.target===refs.scene);if(!entry)return;
    const visible=entry.isIntersecting&&entry.intersectionRatio>=.4;
    if(visible!==inView){inView=visible;visibility();}
  },{threshold:[0,.4]}):null;
  if(observer){inView=false;observer.observe(refs.scene);}
  if(!poster)media?.addEventListener?.('change',motionChanged);
  paint();schedule();
  return { handle, visibility, destroy(){destroyed=true;cancel();observer?.disconnect();if(!poster)media?.removeEventListener?.('change',motionChanged);} };
}
