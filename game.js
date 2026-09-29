'use strict';

/* ==============================================================
   ✨ FANTASY FOREVER ✨
   A tiny cozy RPG set in Moonbrook City: a modern magical town
   where wizards still commute to the office.

   💌 Personalize the game here!
   ============================================================== */
const CONFIG = {
  defaultName: 'Luna',
  // Shown on the ending screen after beating the final boss.
  loveNote: 'Thank you for being my favorite adventurer.\nOn Mondays and every other day. I love you! 💖',
  encounterRate: 0.13, // chance per step in flower beds / office carpet
};

/* ============================================================== */

const TILE = 32, COLS = 20, ROWS = 15, W = COLS * TILE, H = ROWS * TILE;
const MOVE_MS = 150;
const SAVE_KEY = 'fantasy-forever-save-v1';
const EMOJI_FONT = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
const HEROES = ['🧙‍♀️', '🧚‍♀️', '🧝‍♀️', '🧜‍♀️', '🦊', '🐰'];

const $ = (s) => document.querySelector(s);
const rand = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const hash = (x, y) => (((x * 73856093) ^ (y * 19349663)) >>> 0) % 1000;

/* ---------------- Maps ----------------
   City:  . grass   , flower bed (critters!)   - sidewalk   = road
          T tree    ~ pond   H/C/O buildings   h/c/o doors
   Tower: W wall    _ floor  : carpet (gremlins!)  d desk  p plant
          g magic ward       x exit                                   */
const MAPS = {
  city: {
    name: 'Moonbrook City',
    encounterTile: ',',
    pool: 'park',
    rows: [
      'TTTTTTTTTTTTTTTTTTTT',
      'T.HHHH..T....CCCCC.T',
      'T.HHHH.......CCCCC.T',
      'T.HHhH.......CCcCC.T',
      'T...-..........-...T',
      'T------------------T',
      'T==================T',
      'T==================T',
      'T------------------T',
      'T..,,,,,..-..OOOOO.T',
      'T.,,,,,,,.-..OOOOO.T',
      'T.,,~~,,,.-..OOOOO.T',
      'T.,,~~,,,.-..OOoOO.T',
      'T..,,,,,...........T',
      'TTTTTTTTTTTTTTTTTTTT',
    ],
    labels: [
      ['🏠 Home', 4 * TILE, TILE + 12],
      ['☕ Bubbling Cauldron', 15.5 * TILE, TILE + 12],
      ['🏢 Spellwork Tower', 15.5 * TILE, 9 * TILE + 12],
      ['🌷 Petal Park', 5.5 * TILE, 14 * TILE + 16],
    ],
  },
  tower: {
    name: 'Spellwork Tower',
    encounterTile: ':',
    pool: 'office',
    rows: [
      'WWWWWWWWWWWWWWWWWWWW',
      'Wp________________pW',
      'W__________________W',
      'WWWWWWWWggggWWWWWWWW',
      'W::::dd::::::dd::::W',
      'W::::::::::::::::::W',
      'W::dd::::dd::::dd::W',
      'W::::::::::::::::::W',
      'Wp::dd::::::::dd::pW',
      'W::::::::::::::::::W',
      'WWWWWWW______WWWWWWW',
      'Wp________________pW',
      'W__________________W',
      'W__________________W',
      'WWWWWWWWWxxWWWWWWWWW',
    ],
    labels: [
      ['👑 Top Floor', 15 * TILE, 16],
      ['💼 Office Floor', 3.5 * TILE, 10 * TILE + 16],
      ['🛎️ Lobby', 16 * TILE, 14 * TILE + 16],
    ],
  },
};

const WALKABLE = { city: new Set(['.', ',', '-', '=']), tower: new Set(['_', ':']) };

/* ---------------- Critters ---------------- */
const ENEMIES = {
  park: [
    { id: 'cloud', name: 'Grumpy Cloud', emoji: '🌧️', hp: 14, atk: 3, xp: 6, coins: 3,
      moves: ['drizzles on your hair', 'rumbles grumpily at you', 'zaps you with a teeny thunderbolt'],
      calm: 'rains a tiny rainbow and floats off happily!' },
    { id: 'shroom', name: 'Sleepy Mushroom', emoji: '🍄', hp: 12, atk: 3, xp: 5, coins: 2,
      moves: ['sneezes spores at you', 'yawns so hard you yawn too', 'bonks you with its cap'],
      calm: 'curls up for a peaceful nap. Shhh…' },
    { id: 'pigeon', name: 'Pigeon of Doom', emoji: '🐦', hp: 10, atk: 4, xp: 5, coins: 3,
      moves: ['steals a bite of your sandwich', 'coos menacingly', 'flaps right in your face'],
      calm: 'coos softly and does a little happy dance!' },
    { id: 'umbrella', name: 'Lost Umbrella', emoji: '☂️', hp: 16, atk: 3, xp: 7, coins: 4,
      moves: ['pokes you with its pointy end', 'flips inside-out dramatically', 'drips on your shoes'],
      calm: 'was just lonely! It hops off to find its owner.' },
    { id: 'bee', name: 'Busy Bee', emoji: '🐝', hp: 11, atk: 4, xp: 6, coins: 3,
      moves: ['buzzes about deadlines', 'boops you with its stinger', 'does an aggressive waggle dance'],
      calm: 'buzzes happily back to its flower.' },
  ],
  office: [
    { id: 'paper', name: 'Paperwork Imp', emoji: '📄', hp: 18, atk: 4, xp: 10, coins: 5,
      moves: ['gives you a papercut', 'files you under "LATER"', 'demands a signature in triplicate'],
      calm: 'finally gets signed and flutters away, fulfilled!' },
    { id: 'coffee', name: 'Coffee Slime', emoji: '☕', hp: 20, atk: 5, xp: 11, coins: 5,
      moves: ['splashes you with lukewarm decaf', 'jitters at you aggressively', 'spills itself on your keyboard'],
      calm: 'cools down to a pleasant temperature. Ahh~' },
    { id: 'clip', name: 'Paperclip Poltergeist', emoji: '📎', hp: 16, atk: 6, xp: 10, coins: 6,
      moves: ['asks if you need help writing a letter', 'clips your sleeve to a desk', 'bends into a scary shape'],
      calm: 'straightens out and feels much better!' },
    { id: 'printer', name: 'Printer Golem', emoji: '🖨️', hp: 24, atk: 5, xp: 12, coins: 6,
      moves: ['jams at you', 'prints 400 blank pages at you', 'flashes PC LOAD LETTER'],
      calm: 'prints you a thank-you card! 💌' },
    { id: 'email', name: 'Reply-All Wraith', emoji: '📧', hp: 18, atk: 5, xp: 11, coins: 5,
      moves: ['CCs you on 47 emails', 'replies-all "thanks!"', 'books a meeting that could have been an email'],
      calm: 'unsubscribes itself peacefully.' },
  ],
  boss: { id: 'monday', name: 'The Monday Monster', emoji: '⏰', hp: 75, atk: 6, xp: 60, coins: 40,
    moves: ['bonks you with the snooze button', 'shrieks "MEETING AT 8 A.M.!"', 'spins its clock hands at you'],
    calm: '' },
};

/* ---------------- State ---------------- */
let state = null;
let mode = 'title'; // title | map | battle | book | end
let busy = false;
let mover = { moving: false };
let lastBump = 0;

function newState(name, emoji) {
  return {
    player: { name, emoji, level: 1, xp: 0, hp: 30, maxHp: 30, mp: 10, maxMp: 10, atk: 6, coins: 5, muffins: 1 },
    map: 'city', x: 4, y: 4, facing: 'down',
    quest: 0, gremlins: 0, friends: {}, bossDone: false,
    steps: 0, lastBattle: 0, talks: {},
  };
}

function save() {
  if (!state || mode === 'title') return;
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(state)); } catch (e) { /* storage unavailable */ }
}
function loadSave() {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw);
    const base = newState(s.player?.name || CONFIG.defaultName, s.player?.emoji || HEROES[0]);
    return { ...base, ...s, player: { ...base.player, ...s.player }, friends: s.friends || {}, talks: s.talks || {} };
  } catch (e) { return null; }
}

const fmt = (t) => String(t).replaceAll('{name}', state?.player.name || 'friend');
const xpNeeded = (lvl) => lvl * 15;

/* ---------------- Sound (tiny synth blips) ---------------- */
const Sound = { ctx: null, muted: false };
try { Sound.muted = localStorage.getItem('ff-muted') === '1'; } catch (e) { /* ignore */ }
const SFX = {
  blip: [[880, 0.025, 0.025]],
  select: [[660, 0.05], [880, 0.06]],
  bump: [[140, 0.06, 0.05]],
  hit: [[330, 0.05], [200, 0.08]],
  hurt: [[200, 0.07], [120, 0.12]],
  heal: [[523, 0.07], [659, 0.07], [784, 0.07], [1047, 0.14]],
  level: [[523, 0.09], [659, 0.09], [784, 0.09], [1047, 0.09], [1319, 0.25]],
  win: [[784, 0.08], [988, 0.08], [1175, 0.08], [1568, 0.22]],
  encounter: [[440, 0.06], [554, 0.06], [659, 0.06], [880, 0.12]],
  magic: [[1047, 0.06], [1319, 0.06], [1568, 0.06], [2093, 0.2]],
  door: [[392, 0.06], [523, 0.1]],
  lose: [[392, 0.15], [330, 0.15], [262, 0.3]],
};
function sfx(name) {
  if (Sound.muted) return;
  try {
    if (!Sound.ctx) Sound.ctx = new (window.AudioContext || window.webkitAudioContext)();
    const ac = Sound.ctx;
    if (ac.state === 'suspended') ac.resume();
    let t = ac.currentTime;
    for (const [f, d, v = 0.07] of SFX[name] || []) {
      const o = ac.createOscillator(), g = ac.createGain();
      o.type = 'triangle';
      o.frequency.value = f;
      g.gain.setValueAtTime(v, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + d);
      o.connect(g).connect(ac.destination);
      o.start(t);
      o.stop(t + d + 0.02);
      t += d;
    }
  } catch (e) { /* audio unavailable */ }
}

/* ---------------- Map helpers ---------------- */
function tileAt(mapId, x, y) {
  const r = MAPS[mapId].rows[y];
  if (!r || x < 0 || x >= r.length) return '';
  return r[x];
}
function isWalkable(mapId, x, y) {
  const ch = tileAt(mapId, x, y);
  if (ch === 'g') return state.quest >= 3;
  return WALKABLE[mapId].has(ch);
}
function npcsFor(s) {
  return (NPCS[s.map] || []).filter((n) => !n.when || n.when(s));
}
function npcAt(x, y) {
  return npcsFor(state).find((n) => n.x === x && n.y === y);
}
function hintSpots(s) {
  if (!s || mode === 'title') return [];
  if (s.map === 'city') {
    if (s.quest === 0) return [[15, 3]];
    if (s.quest >= 1 && s.quest <= 3) return [[15, 12]];
  } else {
    if (s.quest === 1) return [[6, 12]];
    if (s.quest === 3) return [[9, 1]];
  }
  return [];
}

/* ---------------- Dialog ---------------- */
let dlg = null;

function say(speaker, text) {
  return new Promise((resolve) => openDialog(speaker, text, null, resolve));
}
function ask(speaker, text, options, defaultSel = 0) {
  return new Promise((resolve) => openDialog(speaker, text, options, resolve, defaultSel));
}
function openDialog(speaker, text, options, resolve, defaultSel = 0) {
  if (dlg) clearInterval(dlg.timer);
  $('#dialog').classList.remove('hidden');
  const sp = $('#dlg-speaker');
  sp.textContent = speaker || '';
  sp.style.display = speaker ? '' : 'none';
  dlg = { chars: Array.from(fmt(text)), i: 0, options, sel: defaultSel, resolve, done: false, timer: null };
  $('#dlg-text').textContent = '';
  $('#dlg-choices').innerHTML = '';
  $('#dlg-next').style.visibility = 'hidden';
  dlg.timer = setInterval(typeStep, 22);
}
function typeStep() {
  if (!dlg) return;
  dlg.i++;
  $('#dlg-text').textContent = dlg.chars.slice(0, dlg.i).join('');
  if (dlg.i % 3 === 0) sfx('blip');
  if (dlg.i >= dlg.chars.length) finishTyping();
}
function finishTyping() {
  clearInterval(dlg.timer);
  dlg.done = true;
  $('#dlg-text').textContent = dlg.chars.join('');
  if (dlg.options) renderChoices();
  else $('#dlg-next').style.visibility = 'visible';
}
function renderChoices() {
  const box = $('#dlg-choices');
  box.innerHTML = '';
  dlg.options.forEach((label, i) => {
    const b = document.createElement('button');
    b.textContent = label;
    if (i === dlg.sel) b.className = 'sel';
    b.addEventListener('click', (ev) => { ev.stopPropagation(); closeDialog(i); });
    box.appendChild(b);
  });
}
function closeDialog(value) {
  const d = dlg;
  dlg = null;
  clearInterval(d.timer);
  if (d.options) sfx('select');
  // Hide on the next tick unless another line of dialog opens right away (avoids flicker).
  setTimeout(() => { if (!dlg) $('#dialog').classList.add('hidden'); }, 0);
  d.resolve(value);
}
function dialogConfirm() {
  if (!dlg) return;
  if (!dlg.done) return finishTyping();
  closeDialog(dlg.options ? dlg.sel : undefined);
}

/* ---------------- Scripts ---------------- */
async function runScript(fn) {
  if (busy) return;
  busy = true;
  heldDirs.length = 0;
  try { await fn(); } catch (e) { console.error(e); }
  busy = false;
  heldDirs.length = 0;
  updateHUD();
  save();
}

function fade(fn) {
  return new Promise((resolve) => {
    const f = $('#fade');
    f.classList.add('on');
    setTimeout(() => {
      fn();
      mover = { moving: false };
      updateHUD();
      setTimeout(() => {
        f.classList.remove('on');
        setTimeout(resolve, 250);
      }, 80);
    }, 260);
  });
}

async function intro() {
  await sleep(350);
  await say('Mochi 🐈', 'Mrrrow! {name}! Wake up! Today is your FIRST DAY at Spellwork Tower! ✨');
  await say('Mochi 🐈', 'Walk with the arrow keys or WASD (or the pad on your phone). Bump into anyone to chat!');
  await say('Mochi 🐈', "But first: coffee. Nobody casts a decent spell before coffee. The café is across the way. ☕");
  await say('Mochi 🐈', 'Oh, and the flower beds in Petal Park are full of grumpy critters. Cheer them up with magic and they become your friends! 💕');
  await say('Mochi 🐈', 'Follow the ❗ marks and the ⭐ goal at the top if you get lost. Now shoo. I have a nap scheduled.');
}

async function homeDoor() {
  const c = await ask('🏠 Home', 'Home sweet home. Take a cozy nap? (Restores HP & MP)', ['Nap time 💤', 'Not now']);
  if (c !== 0) return;
  const p = state.player;
  await fade(() => { p.hp = p.maxHp; p.mp = p.maxMp; });
  sfx('heal');
  save();
  await say('🏠 Home', 'Zzz… You wake up fresh as a daisy! 🌼 (Game saved)');
}

async function cafeDoor() {
  const p = state.player;
  sfx('door');
  if (state.quest === 0) {
    await say('Bree 🧚‍♀️', 'Welcome to the Bubbling Cauldron! ✨ Ooh, a new face!');
    await say('Bree 🧚‍♀️', 'First day at Spellwork Tower? Then this Moonbeam Latte is on the house! ☕🌙');
    p.hp = p.maxHp; p.mp = p.maxMp;
    sfx('heal');
    await say('', 'You sip the latte… you feel magically awake! (HP & MP restored)');
    await say('Bree 🧚‍♀️', 'And take these Pumpkin Muffins 🧁. Munch one during a battle if you get hurt!');
    p.muffins += 3;
    updateHUD();
    await say('', 'You got 3 Pumpkin Muffins! 🧁🧁🧁');
    await say('Bree 🧚‍♀️', "Spellwork Tower is the big blue building across the road. Knock 'em dead! …Figuratively! We're a friendly city! 💕");
    state.quest = 1;
    return;
  }
  for (;;) {
    const c = await ask('Bree 🧚‍♀️', `Welcome back, {name}! What can I get you? (You have ${p.coins} 🪙)`,
      ['🧁 Pumpkin Muffin: 5 coins', '☕ Moonbeam Latte (full heal): 3 coins', "That's all, thanks! 👋"], 2);
    if (c === 0) {
      if (p.coins >= 5) { p.coins -= 5; p.muffins++; sfx('select'); await say('Bree 🧚‍♀️', 'One muffin, fresh from the enchanted oven! 🧁'); }
      else await say('Bree 🧚‍♀️', 'Aww, not quite enough coins. Cheer up some critters and come back! 🌷');
    } else if (c === 1) {
      if (p.coins >= 3) { p.coins -= 3; p.hp = p.maxHp; p.mp = p.maxMp; sfx('heal'); await say('Bree 🧚‍♀️', 'Extra foam, extra moonbeams! You look refreshed! ✨'); }
      else await say('Bree 🧚‍♀️', "Aww, you're short on coins… here, smell the latte at least. ☕ Mmm.");
    } else {
      await say('Bree 🧚‍♀️', pick(['Bye bye! Fly safe! 🧚‍♀️', 'Come back soon, sweetie! 💕', "Don't let the Mondays get you down!"]));
      return;
    }
    updateHUD();
  }
}

async function towerDoor() {
  if (state.quest === 0) {
    await say('', "The revolving door spins you right back outside. 🌀 You're way too sleepy for work… Coffee first! ☕");
    return;
  }
  sfx('door');
  await fade(() => { state.map = 'tower'; state.x = 9; state.y = 13; state.facing = 'up'; });
  if (state.quest === 1) await say('Dot 🐉', 'Oh! Are you the new hire? Over here, sweetie! 👋');
}

async function exitDoor() {
  sfx('door');
  await fade(() => { state.map = 'city'; state.x = 15; state.y = 13; state.facing = 'down'; });
}

async function gateMsg() {
  if (state.quest < 2) await say('✨ Magic Ward', 'A grumpy purple magic ward blocks the stairs. Maybe the receptionist knows what\'s going on?');
  else await say('✨ Magic Ward', `A grumpy purple ward blocks the stairs. It's powered by office gremlins… (${state.gremlins}/3 calmed)`);
}

const DOORS = { city: { h: homeDoor, c: cafeDoor, o: towerDoor }, tower: { x: exitDoor } };

/* ---------------- NPCs ---------------- */
const NPCS = {
  city: [
    { id: 'mochi', emoji: '🐈', x: 6, y: 4, talk: async () => {
      const q = state.quest;
      const line = q === 0 ? "Coffee first, then work. That's the ancient law. ☕ (The café is the yellow building, top right!)"
        : q === 1 ? 'Spellwork Tower is the big blue building across the road. Go, go, go! 🏢'
        : q < 4 ? 'Tired? Nap at home to restore HP & MP. Or pet me. Petting me also helps. Scientifically.'
        : 'You saved Monday?! I am… impressed. Here, have a slow blink. 😽';
      await say('Mochi 🐈', line);
      const c = await ask('Mochi 🐈', 'Mochi looks at you expectantly.', ['Pet Mochi 🤚', 'Leave her be']);
      if (c === 0) { sfx('heal'); await say('Mochi 🐈', pick(['Purrrrrrr… 💕', 'Mrrp! …Okay, that was acceptable.', 'Purr… you may continue. For science.'])); }
    } },
    { id: 'owl', emoji: '🦉', x: 9, y: 2, talk: async () => {
      await say('Pip the Postowl 🦉', pick([
        'Hoo! Special delivery for… {name}? Oh wait, no. It\'s for Mochi. Catnip. Again.',
        'Hoo hoo! Enchanted mail moves at the speed of wings! Unless it\'s raining. Then it\'s soggy.',
        'Did you know the café fairy bakes muffins with actual moonlight? Very healthy. Probably.',
      ]));
    } },
    { id: 'merlo', emoji: '🧙‍♂️', x: 11, y: 10, talk: async () => {
      const tips = [
        'Back in my day we fought DRAGONS. Now the dragons work in HR. Progress!',
        'Tip: ✨ Sparkle Bolt is free! 🌈 Rainbow Beam hits twice as hard but costs MP.',
        'Tip: Low on HP? 💗 Cozy Heal uses MP, 🧁 muffins are free (once you have them).',
        'Tip: Naps at home and lattes at the café restore everything. Self-care is a spell too!',
        'Tip: Every critter you cheer up goes in your 📖 Friendbook. Collect them all!',
      ];
      state.talks.merlo = ((state.talks.merlo || 0) + 1) % tips.length;
      await say('Grandpa Merlo 🧙‍♂️', tips[state.talks.merlo]);
    } },
    { id: 'unicorn', emoji: '🦄', x: 17, y: 8, talk: async () => {
      await say('Sparkle the Unicorn 🦄', pick([
        'Ugh, the 8:15 cloud-bus is late AGAIN.',
        "I'm a certified accountant. Horn-tified. …Heh. Sorry.",
        'Rush hour in Moonbrook is wild. Yesterday a broom cut me off!',
      ]));
    } },
  ],
  tower: [
    { id: 'dot', emoji: '🐉', x: 6, y: 12, talk: async () => {
      const q = state.quest;
      if (q <= 1) {
        await say('Dot 🐉', "Oh thank goodness, you're here! I'm Dot, the receptionist. Welcome to Spellwork Tower!");
        await say('Dot 🐉', 'Bad news, sweetie. Someone forgot to turn off the Enchanted Alarm Clock over the weekend…');
        await say('Dot 🐉', 'It soaked up ALL the Monday grumpiness in the city and became… THE MONDAY MONSTER! ⏰😱');
        await say('Dot 🐉', "It's locked itself on the Top Floor behind a magic ward. The office gremlins are powering it.");
        await say('Dot 🐉', 'Cheer up 3 gremlins on the blue carpet upstairs, and the ward should pop! Good luck! 🍀');
        state.quest = 2;
      } else if (q === 2) {
        await say('Dot 🐉', `Gremlins cheered up: ${state.gremlins}/3. You've got this, {name}! 💪`);
      } else if (q === 3) {
        await say('Dot 🐉', "The ward is down! Go get 'em, {name}! (Maybe grab a nap or a latte first. Just saying. 💤)");
      } else {
        await say('Dot 🐉', 'Employee of the month! No, of the CENTURY! 🏆 I made you a little sparkly badge.');
      }
    } },
    { id: 'fern', emoji: '🧝‍♀️', x: 17, y: 9, talk: async () => {
      const q = state.quest;
      await say('Fern 🧝‍♀️', q < 3 ? "Hi, new person! The gremlins pop out of the blue carpet. Facilities says it's \"a feature\"."
        : q === 3 ? "The ward's down?! You're a legend. I'd help, but I have a 2 o'clock."
        : 'Lunch is on me today! 🥪 Honestly, lunch is on me forever.');
    } },
    { id: 'ghost', emoji: '👻', x: 3, y: 2, talk: async () => {
      await say('Boo-b the Intern 👻', 'Boo! …Sorry, force of habit. 👻');
      if (!state.bossDone) await say('Boo-b the Intern 👻', 'Hot tip: the Monday Monster winds up a HUGE alarm every few turns. When it starts winding up, heal!');
      else await say('Boo-b the Intern 👻', "Now that it's quiet up here, I can finally haunt in peace. Thanks, {name}!");
    } },
    { id: 'boss', emoji: '⏰', x: 9, y: 1, big: true, when: (s) => !s.bossDone, talk: bossTalk },
    { id: 'clock', emoji: '🕰️', x: 9, y: 1, when: (s) => s.bossDone, talk: async () => {
      await say('Tiny Clock 🕰️', "tick… tock… I'm just a regular clock now. I promise to only ring on Saturdays. At noon. Softly. 💤");
    } },
  ],
};

async function bossTalk() {
  const c = await ask('The Monday Monster ⏰', 'RIIIING! NO. MORE. WEEKENDS. EVERY DAY IS MONDAY NOW!!', ['Fight! ✨', 'Not yet… (heal up first)']);
  if (c !== 0) return;
  const res = await battle(ENEMIES.boss, { boss: true, area: 'boss' });
  if (res !== 'win') return;
  state.bossDone = true;
  state.quest = 4;
  updateHUD();
  await say('', 'The Monday Monster lets out a huge yawn… and shrinks back into a tiny, sleepy clock. 🕰️');
  await say('Tiny Clock 🕰️', '…sorry. I just really, really wanted a weekend too.');
  await say('Dot 🐉 (on the intercom)', 'ATTENTION ALL STAFF: {name} saved Monday! Everyone gets Friday off! 🎉');
  save();
  await showEnding();
}

/* ---------------- Encounters ---------------- */
function onStep() {
  state.steps++;
  const map = MAPS[state.map];
  if (tileAt(state.map, state.x, state.y) === map.encounterTile
      && state.steps - state.lastBattle >= 4
      && Math.random() < CONFIG.encounterRate) {
    runScript(randomEncounter);
  }
}

async function randomEncounter() {
  state.lastBattle = state.steps;
  const area = MAPS[state.map].pool;
  const stage = $('#stage');
  stage.classList.remove('flash'); void stage.offsetWidth; stage.classList.add('flash');
  sfx('encounter');
  await sleep(450);
  const res = await battle(pick(ENEMIES[area]), { area });
  if (res === 'win' && state.map === 'tower' && state.quest === 2) {
    state.gremlins++;
    updateHUD();
    if (state.gremlins >= 3) {
      state.quest = 3;
      sfx('magic');
      await say('✨', 'POP! Somewhere upstairs, the grumpy magic ward bursts like a soap bubble! 🫧');
      await say('✨', 'The way to the Top Floor is open!');
    } else {
      await say('✨', `The ward upstairs flickers… (${state.gremlins}/3 gremlins cheered up)`);
    }
  }
}

/* ---------------- Battle ---------------- */
const ACTIONS = [
  { id: 'bolt', label: '✨ Sparkle Bolt', cost: () => 'free' },
  { id: 'beam', label: '🌈 Rainbow Beam', cost: () => '4 MP' },
  { id: 'heal', label: '💗 Cozy Heal', cost: () => '3 MP' },
  { id: 'snack', label: '🧁 Eat Muffin', cost: () => `×${state.player.muffins}` },
  { id: 'run', label: '🏃 Run Away', cost: () => '' },
];
let battleMenu = null;
let battleSkip = null;
let battleIsBoss = false;

function canUse(id) {
  const p = state.player;
  if (id === 'beam') return p.mp >= 4;
  if (id === 'heal') return p.mp >= 3 && p.hp < p.maxHp;
  if (id === 'snack') return p.muffins > 0 && p.hp < p.maxHp;
  if (id === 'run') return !battleIsBoss;
  return true;
}
function renderActions() {
  const box = $('#b-actions');
  box.innerHTML = '';
  box.classList.toggle('waiting', !battleMenu);
  ACTIONS.forEach((a, i) => {
    const b = document.createElement('button');
    b.className = 'act' + (battleMenu && i === battleMenu.sel ? ' sel' : '');
    b.disabled = !battleMenu || !canUse(a.id);
    const k = document.createElement('span'); k.className = 'k'; k.textContent = i + 1;
    const cost = document.createElement('small');
    cost.textContent = a.id === 'run' && battleIsBoss ? "can't!" : a.cost();
    b.append(k, document.createTextNode(' ' + a.label), cost);
    b.addEventListener('click', () => pickAction(i));
    box.appendChild(b);
  });
}
function chooseAction(preferred) {
  return new Promise((resolve) => {
    const sel = ACTIONS.findIndex((a) => a.id === preferred && canUse(a.id));
    battleMenu = { resolve, sel: Math.max(0, sel) };
    renderActions();
  });
}
function pickAction(i) {
  if (!battleMenu) return;
  const a = ACTIONS[i];
  if (!a || !canUse(a.id)) { sfx('bump'); return; }
  const m = battleMenu;
  battleMenu = null;
  sfx('select');
  renderActions();
  m.resolve(a.id);
}
function bwait(ms) {
  return new Promise((resolve) => {
    const done = () => { clearTimeout(t); if (battleSkip === done) battleSkip = null; resolve(); };
    const t = setTimeout(done, ms);
    battleSkip = done;
  });
}
async function blog(text, ms = 1300) {
  $('#b-log').textContent = fmt(text);
  await bwait(ms);
}
function popup(sel, text, cls = '') {
  const el = document.createElement('div');
  el.className = 'pop ' + cls;
  el.textContent = text;
  $(sel).appendChild(el);
  setTimeout(() => el.remove(), 1000);
}
function shake(sel) {
  const el = $(sel);
  el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake');
  setTimeout(() => el.classList.remove('shake'), 400);
}
function renderBattle(e) {
  const p = state.player;
  $('#b-enemy-hp').style.width = Math.max(0, (e.hp / e.maxHp) * 100) + '%';
  $('#b-hp').style.width = (p.hp / p.maxHp) * 100 + '%';
  $('#b-mp').style.width = (p.mp / p.maxMp) * 100 + '%';
  $('#b-hp-text').textContent = `HP ${p.hp}/${p.maxHp}`;
  $('#b-mp-text').textContent = `MP ${p.mp}/${p.maxMp}`;
  updateHUD();
}

async function battle(tpl, { boss = false, area = 'park' } = {}) {
  const p = state.player;
  const e = { ...tpl, maxHp: tpl.hp, windup: false };
  mode = 'battle';
  battleIsBoss = boss;
  battleMenu = null;
  const root = $('#battle');
  root.className = 'overlay ' + area;
  const ee = $('#b-enemy-emoji');
  ee.className = '';
  ee.textContent = e.emoji;
  $('#b-enemy-name').textContent = e.name;
  $('#b-player-emoji').textContent = p.emoji;
  $('#b-player-name').textContent = `${p.name}  Lv ${p.level}`;
  renderBattle(e);
  renderActions();

  await blog(boss ? 'The Monday Monster rings furiously! ⏰💢' : `A grumpy ${e.name} pops out! ${e.emoji}`, 1400);
  let turn = 0, saidHalf = false, lastAction = 'bolt';

  for (;;) {
    $('#b-log').textContent = 'What will you do?';
    const act = await chooseAction(lastAction);
    lastAction = act;

    // ---- Your turn ----
    if (act === 'run') {
      await blog('You tiptoe away very, very quietly… 🏃', 1100);
      endBattle();
      return 'run';
    }
    if (act === 'bolt' || act === 'beam') {
      let dmg = act === 'bolt' ? p.atk + rand(0, 3) : p.atk * 2 + rand(0, 4);
      if (act === 'beam') p.mp -= 4;
      const crit = Math.random() < 0.1;
      if (crit) dmg = Math.round(dmg * 1.5);
      e.hp = Math.max(0, e.hp - dmg);
      sfx('hit');
      shake('#b-enemy-emoji');
      popup('.b-enemy', `-${dmg}`);
      renderBattle(e);
      await blog(act === 'bolt'
        ? `You fling a Sparkle Bolt! ✨${crit ? ' Critical sparkle!!' : ''}`
        : `You cast a dazzling Rainbow Beam! 🌈${crit ? ' Critical sparkle!!' : ''}`, 1100);
    } else if (act === 'heal' || act === 'snack') {
      const amt = act === 'heal' ? 10 + p.level * 4 : 25;
      if (act === 'heal') p.mp -= 3; else p.muffins--;
      const before = p.hp;
      p.hp = Math.min(p.maxHp, p.hp + amt);
      sfx('heal');
      popup('.b-player', `+${p.hp - before}`, 'heal');
      renderBattle(e);
      await blog(act === 'heal' ? 'You cast Cozy Heal. Warm fuzzy feelings! 💗' : 'You munch a Pumpkin Muffin. Nom nom nom! 🧁', 1100);
    }

    if (e.hp <= 0) return await winBattle(e, boss);

    // ---- Critter's turn ----
    turn++;
    await bwait(250);
    if (boss && !saidHalf && e.hp <= e.maxHp / 2) {
      saidHalf = true;
      await blog('The Monday Monster: "W-wait… is that… a WEEKEND I smell?!" 😳', 1500);
    }
    if (boss && e.windup) {
      e.windup = false;
      const dmg = e.atk * 2 + rand(1, 4);
      hurt(dmg);
      renderBattle(e);
      await blog(`⏰ RIIIIIIIIIING!!! A HUGE alarm blasts you! -${dmg} HP`, 1500);
    } else if (boss && turn % 3 === 2) {
      e.windup = true;
      shake('#b-enemy-emoji');
      await blog('The Monday Monster is winding up a HUGE alarm… ⚠️ (Now would be a great time to heal!)', 1800);
    } else if (boss && p.mp >= 3 && Math.random() < 0.3) {
      p.mp -= 3;
      const dmg = rand(2, 4);
      hurt(dmg);
      popup('.b-player', '-3 MP', 'mp');
      renderBattle(e);
      await blog(`The Monday Monster breathes Monday Mist… you feel so unmotivated. -${dmg} HP, -3 MP 😩`, 1500);
    } else if (!boss && Math.random() < 0.12) {
      await blog(`${e.name} ${pick(e.moves)}… but trips over its own feet! 💫`, 1300);
    } else {
      const dmg = e.atk + rand(0, 2);
      hurt(dmg);
      renderBattle(e);
      await blog(`${e.name} ${pick(e.moves)}! -${dmg} HP`, 1300);
    }

    if (p.hp <= 0) return await loseBattle();
  }
}

function hurt(dmg) {
  const p = state.player;
  p.hp = Math.max(0, p.hp - dmg);
  sfx('hurt');
  shake('.battle-card');
  popup('.b-player', `-${dmg}`);
}

async function winBattle(e, boss) {
  const p = state.player;
  sfx('win');
  $('#b-enemy-emoji').classList.add('calmed');
  if (boss) {
    await blog('The Monday Monster stops ringing… it looks very, very sleepy. 💤', 1700);
  } else {
    await blog(`The ${e.name} ${e.calm} 💕`, 1700);
    state.friends[e.id] = (state.friends[e.id] || 0) + 1;
  }
  p.xp += e.xp;
  p.coins += e.coins;
  renderBattle(e);
  await blog(`You got ${e.xp} XP and ${e.coins} coins! 🪙`, 1300);
  while (p.xp >= xpNeeded(p.level)) {
    p.xp -= xpNeeded(p.level);
    p.level++;
    p.maxHp += 8; p.maxMp += 3; p.atk += 2;
    p.hp = p.maxHp; p.mp = p.maxMp;
    sfx('level');
    $('#b-player-name').textContent = `${p.name}  Lv ${p.level}`;
    renderBattle(e);
    await blog(`⭐ LEVEL UP! You're now level ${p.level}! More HP, MP and sparkle power! ⭐`, 1800);
  }
  endBattle();
  return 'win';
}

async function loseBattle() {
  sfx('lose');
  await blog('You feel sooo sleepy… 💤', 1600);
  endBattle();
  const p = state.player;
  await fade(() => {
    state.map = 'city'; state.x = 4; state.y = 4; state.facing = 'down';
    p.hp = p.maxHp; p.mp = p.maxMp;
  });
  await say('Mochi 🐈', "Mrrow. You dozed off out there, so I dragged you home. You're welcome. 😼 (HP & MP restored!)");
  return 'lose';
}

function endBattle() {
  battleMenu = null;
  battleSkip = null;
  $('#battle').classList.add('hidden');
  mode = 'map';
  updateHUD();
}

/* ---------------- HUD / menus ---------------- */
function objective() {
  switch (state.quest) {
    case 0: return 'Grab a magic latte at the Bubbling Cauldron café ☕ (top right)';
    case 1: return 'Go to Spellwork Tower for your first day 🏢 (bottom right)';
    case 2: return `Cheer up office gremlins on the blue carpet (${state.gremlins}/3)`;
    case 3: return 'The ward is down! Face the Monday Monster on the Top Floor ⏰';
    default: return 'You saved Monday! 🎉 Explore and fill your 📖 Friendbook';
  }
}
function setBar(sel, v, max, textSel, label) {
  $(sel).style.width = Math.max(0, (v / max) * 100) + '%';
  $(textSel).textContent = `${label} ${v}/${max}`;
}
function updateHUD() {
  if (!state) return;
  const p = state.player;
  $('#hud-emoji').textContent = p.emoji;
  $('#hud-name').textContent = p.name;
  $('#hud-level').textContent = `Lv ${p.level} · ${p.xp}/${xpNeeded(p.level)} XP`;
  setBar('#hud-hp', p.hp, p.maxHp, '#hud-hp-text', 'HP');
  setBar('#hud-mp', p.mp, p.maxMp, '#hud-mp-text', 'MP');
  $('#hud-coins').textContent = p.coins;
  $('#hud-muffins').textContent = p.muffins;
  $('#obj-text').textContent = objective();
}

function openBook() {
  if (mode !== 'map' || busy || !state) return;
  mode = 'book';
  const grid = $('#book-grid');
  grid.innerHTML = '';
  const all = [...ENEMIES.park, ...ENEMIES.office, ENEMIES.boss];
  let found = 0;
  for (const e of all) {
    const n = e.id === 'monday' ? (state.bossDone ? 1 : 0) : (state.friends[e.id] || 0);
    if (n) found++;
    const d = document.createElement('div');
    d.className = 'friend' + (n ? '' : ' unknown');
    const em = document.createElement('div'); em.className = 'fe'; em.textContent = n ? (e.id === 'monday' ? '🕰️' : e.emoji) : '❔';
    const nm = document.createElement('div'); nm.textContent = n ? (e.id === 'monday' ? 'Tiny Clock' : e.name) : '???';
    const ct = document.createElement('div'); ct.className = 'fc'; ct.textContent = n ? (e.id === 'monday' ? 'best friend ⏰' : `cheered up ×${n}`) : 'not met yet';
    d.append(em, nm, ct);
    grid.appendChild(d);
  }
  $('#book-count').textContent = `${found}/${all.length} friends made 💕`;
  $('#book').classList.remove('hidden');
}
function closeBook() {
  if (mode !== 'book') return;
  $('#book').classList.add('hidden');
  mode = 'map';
}

function showEnding() {
  return new Promise((resolve) => {
    mode = 'end';
    const p = state.player;
    const friends = Object.values(state.friends).reduce((a, b) => a + b, 0);
    $('#end-text').textContent = `${p.name}, you cheered up ${friends} grumpy critters, reached level ${p.level}, and turned the Monday Monster back into a sleepy little clock. Spellwork Tower has declared a four-day weekend in your honor! 🏖️`;
    $('#end-love').textContent = '💌 ' + CONFIG.loveNote;
    $('#ending').classList.remove('hidden');
    sfx('level');
    const conf = $('#confetti');
    conf.innerHTML = '';
    for (let i = 0; i < 40; i++) {
      const s = document.createElement('span');
      s.textContent = pick(['💖', '✨', '🌸', '🎉', '⭐', '🧁']);
      s.style.left = Math.random() * 100 + 'vw';
      s.style.animationDuration = 3 + Math.random() * 4 + 's';
      s.style.animationDelay = Math.random() * 3 + 's';
      conf.appendChild(s);
    }
    $('#btn-keep').onclick = () => { $('#ending').classList.add('hidden'); mode = 'map'; resolve(); };
    $('#btn-new2').onclick = () => { $('#ending').classList.add('hidden'); resolve(); showTitle(); };
  });
}

/* ---------------- Title ---------------- */
let chosenHero = HEROES[0];
function showTitle() {
  mode = 'title';
  $('#title').classList.remove('hidden');
  const pickBox = $('#hero-pick');
  pickBox.innerHTML = '';
  HEROES.forEach((h) => {
    const b = document.createElement('button');
    b.textContent = h;
    if (h === chosenHero) b.className = 'sel';
    b.addEventListener('click', () => {
      chosenHero = h;
      [...pickBox.children].forEach((c) => c.classList.toggle('sel', c === b));
      sfx('select');
    });
    pickBox.appendChild(b);
  });
  const saved = loadSave();
  $('#name-input').value = saved?.player.name || CONFIG.defaultName;
  $('#btn-continue').classList.toggle('hidden', !saved);
}
function startGame(newGame) {
  if (newGame) {
    if (loadSave() && !confirm('Start a brand new adventure? Your saved game will be replaced.')) return;
    const name = $('#name-input').value.trim().slice(0, 12) || CONFIG.defaultName;
    state = newState(name, chosenHero);
  } else {
    state = loadSave();
    if (!state) return;
  }
  $('#title').classList.add('hidden');
  mode = 'map';
  busy = false;
  mover = { moving: false };
  updateHUD();
  sfx('magic');
  save();
  if (newGame) runScript(intro);
}

/* ---------------- Input ---------------- */
const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const KEYMAP = {
  ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right',
  w: 'up', s: 'down', a: 'left', d: 'right', W: 'up', S: 'down', A: 'left', D: 'right',
};
const heldDirs = [];

function pressDir(d) {
  const i = heldDirs.indexOf(d);
  if (i >= 0) heldDirs.splice(i, 1);
  heldDirs.push(d);
  navigate(d);
  // Step right away so quick taps always move (holding keeps walking via update()).
  if (mode === 'map' && state && !busy && !dlg) {
    if (mover.moving) mover.queued = d; // remember taps made mid-step
    else tryMove(d);
  }
}
function releaseDir(d) {
  const i = heldDirs.indexOf(d);
  if (i >= 0) heldDirs.splice(i, 1);
}
function navigate(d) {
  if (dlg && dlg.done && dlg.options) {
    const n = dlg.options.length;
    dlg.sel = (dlg.sel + (d === 'up' || d === 'left' ? n - 1 : 1)) % n;
    sfx('blip');
    renderChoices();
  } else if (battleMenu) {
    const step = { left: -1, right: 1, up: -2, down: 2 }[d];
    battleMenu.sel = Math.min(ACTIONS.length - 1, Math.max(0, battleMenu.sel + step));
    sfx('blip');
    renderActions();
  }
}
function onConfirm() {
  if (mode === 'title' || mode === 'end') return;
  if (mode === 'book') return closeBook();
  if (dlg) return dialogConfirm();
  if (battleSkip) return battleSkip();
  if (battleMenu) return pickAction(battleMenu.sel);
  if (mode === 'map' && !busy && !mover.moving) interact();
}
function interact() {
  const [dx, dy] = DIRS[state.facing];
  const nx = state.x + dx, ny = state.y + dy;
  const npc = npcAt(nx, ny);
  if (npc) return runScript(npc.talk);
  const ch = tileAt(state.map, nx, ny);
  const door = DOORS[state.map][ch];
  if (door) return runScript(door);
  if (ch === 'g' && state.quest < 3) return runScript(gateMsg);
}

window.addEventListener('keydown', (e) => {
  if (e.target instanceof HTMLInputElement) {
    if (e.key === 'Enter' && mode === 'title') startGame(true);
    return;
  }
  const d = KEYMAP[e.key];
  if (d) {
    e.preventDefault();
    if (!e.repeat) pressDir(d);
    return;
  }
  if (e.key === ' ' || e.key === 'Enter' || e.key === 'z' || e.key === 'Z') {
    e.preventDefault();
    if (!e.repeat) onConfirm();
    return;
  }
  if (/^[1-9]$/.test(e.key)) {
    const i = Number(e.key) - 1;
    if (dlg && dlg.done && dlg.options && i < dlg.options.length) closeDialog(i);
    else if (battleMenu) pickAction(i);
    return;
  }
  if (e.key === 'b' || e.key === 'B') { if (mode === 'book') closeBook(); else openBook(); }
  if (e.key === 'Escape') closeBook();
});
window.addEventListener('keyup', (e) => { const d = KEYMAP[e.key]; if (d) releaseDir(d); });
window.addEventListener('blur', () => { heldDirs.length = 0; });

document.querySelectorAll('.dpad button').forEach((b) => {
  const d = b.dataset.dir;
  b.addEventListener('pointerdown', (e) => { e.preventDefault(); b.setPointerCapture?.(e.pointerId); pressDir(d); });
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach((ev) => b.addEventListener(ev, () => releaseDir(d)));
});
$('#btn-a').addEventListener('pointerdown', (e) => { e.preventDefault(); onConfirm(); });
$('#dialog').addEventListener('click', () => { if (dlg && !(dlg.done && dlg.options)) dialogConfirm(); });
$('#b-log').addEventListener('click', () => { if (battleSkip) battleSkip(); });
$('#btn-book').addEventListener('click', () => (mode === 'book' ? closeBook() : openBook()));
$('#btn-book-close').addEventListener('click', closeBook);
$('#btn-start').addEventListener('click', () => startGame(true));
$('#btn-continue').addEventListener('click', () => startGame(false));
const muteBtn = $('#btn-mute');
muteBtn.textContent = Sound.muted ? '🔇' : '🔊';
muteBtn.addEventListener('click', () => {
  Sound.muted = !Sound.muted;
  muteBtn.textContent = Sound.muted ? '🔇' : '🔊';
  try { localStorage.setItem('ff-muted', Sound.muted ? '1' : '0'); } catch (e) { /* ignore */ }
});

/* ---------------- Movement ---------------- */
function tryMove(d) {
  state.facing = d;
  const [dx, dy] = DIRS[d];
  const nx = state.x + dx, ny = state.y + dy;
  const npc = npcAt(nx, ny);
  if (npc) return runScript(npc.talk);
  const ch = tileAt(state.map, nx, ny);
  const door = DOORS[state.map][ch];
  if (door) return runScript(door);
  if (ch === 'g' && state.quest < 3) return runScript(gateMsg);
  if (!isWalkable(state.map, nx, ny)) {
    const now = performance.now();
    if (now - lastBump > 300) { sfx('bump'); lastBump = now; }
    return;
  }
  mover = { moving: true, fromX: state.x, fromY: state.y, toX: nx, toY: ny, t: 0 };
}

/* ---------------- Ambient decorations ---------------- */
const vehicles = [
  { emoji: '🚌', row: 7, x: -60, speed: 0.055 },
  { emoji: '🚕', row: 6, x: W + 120, speed: -0.075 },
  { emoji: '🚗', row: 7, x: -380, speed: 0.065 },
];
const flyer = { emoji: '🧹', x: -80, y: 14, speed: 0.07, wait: 3000 };
const sparkles = [];

function playerPixelPos() {
  if (mover.moving) {
    const t = Math.min(1, mover.t);
    return [(mover.fromX + (mover.toX - mover.fromX) * t) * TILE, (mover.fromY + (mover.toY - mover.fromY) * t) * TILE];
  }
  return [state.x * TILE, state.y * TILE];
}

function update(dt) {
  const inCity = !state || state.map === 'city';
  if (inCity) {
    const pp = state && mode !== 'title' ? playerPixelPos() : null;
    for (const v of vehicles) {
      const vy = v.row * TILE;
      // Polite drivers stop for pedestrians!
      if (pp && Math.abs(pp[1] - vy) < TILE * 0.6) {
        const ahead = v.speed > 0 ? pp[0] - v.x : v.x - (pp[0] + TILE);
        if (ahead > -8 && ahead < 46) continue;
      }
      v.x += v.speed * dt;
      if (v.speed > 0 && v.x > W + 40) v.x = -60 - Math.random() * 400;
      if (v.speed < 0 && v.x < -60) v.x = W + 40 + Math.random() * 400;
    }
    if (flyer.wait > 0) flyer.wait -= dt;
    else {
      flyer.x += flyer.speed * dt;
      if (flyer.x > W + 60) { flyer.x = -60; flyer.wait = 4000 + Math.random() * 6000; flyer.emoji = pick(['🧹', '🐉', '🧹', '🦄']); }
    }
  }
  if (Math.random() < dt / 180) {
    sparkles.push({ x: Math.random() * W, y: Math.random() * H, life: 0, max: 1200 + Math.random() * 1200, hue: pick([330, 280, 50, 200]) });
  }
  for (let i = sparkles.length - 1; i >= 0; i--) {
    const s = sparkles[i];
    s.life += dt; s.y -= dt * 0.01;
    if (s.life > s.max) sparkles.splice(i, 1);
  }

  if (mode !== 'map' || !state) return;
  if (mover.moving) {
    mover.t += dt / MOVE_MS;
    if (mover.t >= 1) {
      mover.moving = false;
      state.x = mover.toX; state.y = mover.toY;
      const queued = mover.queued;
      mover = { moving: false };
      onStep();
      if (queued && !busy && !heldDirs.length) tryMove(queued);
    }
  }
  if (!mover.moving && !busy) {
    const d = heldDirs[heldDirs.length - 1];
    if (d) tryMove(d);
  }
}

/* ---------------- Rendering ---------------- */
const canvas = $('#game');
const ctx = canvas.getContext('2d');
function resizeCanvas() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = W * dpr;
  canvas.height = H * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

function circle(x, y, r) { ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); }
function rrect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
function emoji(ch, x, y, size, color = '#000') {
  ctx.fillStyle = color; // color emoji still inherit fillStyle's alpha
  ctx.font = `${size}px ${EMOJI_FONT}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(ch, x, y);
}

function grass(px, py, h) {
  ctx.fillStyle = h % 2 ? '#b4e7a5' : '#afe4a0';
  ctx.fillRect(px, py, TILE, TILE);
  if (h % 5 === 0) {
    ctx.fillStyle = '#94d386';
    const ox = 6 + (h % 17), oy = 8 + (h % 13);
    ctx.fillRect(px + ox, py + oy, 2, 5);
    ctx.fillRect(px + ox + 3, py + oy - 1, 2, 6);
  }
  if (h % 23 === 0) { ctx.fillStyle = '#fff'; circle(px + 10 + (h % 11), py + 20, 1.8); }
}
function flowerBed(px, py, h, t) {
  ctx.fillStyle = '#95d585';
  ctx.fillRect(px, py, TILE, TILE);
  const sway = Math.sin(t / 500 + h) * 1.5;
  ctx.strokeStyle = '#62b258';
  ctx.lineWidth = 2;
  for (let i = 0; i < 3; i++) {
    const bx = px + 6 + i * 10, by = py + 28;
    ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + sway, by - 11); ctx.stroke();
  }
  const cols = ['#ff8fb8', '#ffd166', '#ffffff', '#c3a6ff'];
  for (let i = 0; i < 3; i++) {
    const fx = px + 6 + ((h * (i + 3)) % 20), fy = py + 5 + ((h * (i + 7)) % 16);
    ctx.fillStyle = cols[(h + i) % 4];
    circle(fx + sway, fy, 3.2);
    ctx.fillStyle = '#ffe066';
    circle(fx + sway, fy, 1.2);
  }
}
function tree(px, py, h) {
  ctx.fillStyle = 'rgba(60,90,50,.18)';
  ctx.beginPath(); ctx.ellipse(px + 16, py + 28, 11, 4, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#a0704e';
  ctx.fillRect(px + 13, py + 18, 6, 10);
  const blossom = h % 4 === 0;
  ctx.fillStyle = blossom ? '#ffb3cf' : '#6cc26b';
  circle(px + 16, py + 14, 11);
  ctx.fillStyle = blossom ? '#ffd6e6' : '#8fdc86';
  circle(px + 12, py + 10, 5);
}
function building(ch, x, y, px, py, t, h) {
  const B = {
    H: { wall: '#ffdbe6', roof: '#f07ea6', trim: '#d95f89' },
    C: { wall: '#fff1cf', roof: '#c98a5a', trim: '#9b5f36' },
    O: { wall: '#c3ccff', roof: '#7b7fe0', trim: '#5a5dc0' },
  }[ch];
  const above = tileAt('city', x, y - 1).toUpperCase();
  if (above !== ch) {
    ctx.fillStyle = B.roof;
    ctx.fillRect(px, py, TILE, TILE);
    ctx.fillStyle = 'rgba(255,255,255,.18)';
    for (let i = 4; i < TILE; i += 8) ctx.fillRect(px, py + i, TILE, 2);
    ctx.fillStyle = B.trim;
    ctx.fillRect(px, py + TILE - 4, TILE, 4);
    return;
  }
  ctx.fillStyle = B.wall;
  ctx.fillRect(px, py, TILE, TILE);
  if (ch === 'O') {
    for (const wx of [5, 18]) {
      const lit = (h + wx + Math.floor(t / 1800)) % 5 === 0;
      ctx.fillStyle = B.trim;
      ctx.fillRect(px + wx - 1, py + 5, 11, 22);
      ctx.fillStyle = lit ? '#fff3a6' : '#e8f0ff';
      ctx.fillRect(px + wx, py + 6, 9, 20);
    }
    return;
  }
  // Cute windows for home & café
  ctx.fillStyle = '#fff';
  rrect(px + 8, py + 7, 16, 15, 3); ctx.fill();
  ctx.fillStyle = ch === 'C' ? '#ffe7a8' : '#bfe6ff';
  ctx.fillRect(px + 10, py + 9, 12, 11);
  if (ch === 'H') {
    ctx.fillStyle = '#ff9ec0';
    ctx.beginPath(); ctx.moveTo(px + 10, py + 9); ctx.lineTo(px + 15, py + 9); ctx.lineTo(px + 10, py + 17); ctx.fill();
    ctx.beginPath(); ctx.moveTo(px + 22, py + 9); ctx.lineTo(px + 17, py + 9); ctx.lineTo(px + 22, py + 17); ctx.fill();
  }
  if (ch === 'C' && y === 2) {
    // Striped awning
    for (let i = 0; i < 4; i++) {
      ctx.fillStyle = i % 2 ? '#fff' : '#ff9fb6';
      ctx.fillRect(px + i * 8, py + 24, 8, 8);
    }
  }
}
function door(ch, px, py) {
  if (ch === 'o') {
    ctx.fillStyle = '#5a5dc0';
    ctx.fillRect(px + 3, py + 5, 26, 27);
    ctx.fillStyle = '#dff4ff';
    ctx.fillRect(px + 5, py + 7, 22, 25);
    ctx.fillStyle = '#5a5dc0';
    ctx.fillRect(px + 15, py + 7, 2, 25);
    return;
  }
  ctx.fillStyle = ch === 'h' ? '#b0744c' : '#8a5a3c';
  ctx.beginPath();
  ctx.moveTo(px + 8, py + 32); ctx.lineTo(px + 8, py + 14);
  ctx.arc(px + 16, py + 14, 8, Math.PI, 0);
  ctx.lineTo(px + 24, py + 32); ctx.fill();
  ctx.fillStyle = '#ffd166';
  circle(px + 21, py + 23, 1.8);
  if (ch === 'h') emoji('♥', px + 16, py + 14, 9, '#ff8fb8');
  else { ctx.fillStyle = '#ffe7a8'; circle(px + 16, py + 14, 4); }
}

function drawCityTile(ch, x, y, px, py, t) {
  const h = hash(x, y);
  switch (ch) {
    case '.': grass(px, py, h); break;
    case ',': flowerBed(px, py, h, t); break;
    case '-':
      ctx.fillStyle = '#f3e6d6'; ctx.fillRect(px, py, TILE, TILE);
      ctx.fillStyle = '#e4d2bd'; ctx.fillRect(px, py + 15, TILE, 2); ctx.fillRect(px + (y % 2 ? 0 : 15), py, 2, TILE);
      break;
    case '=': {
      ctx.fillStyle = '#7d8096'; ctx.fillRect(px, py, TILE, TILE);
      const cross = x === 4 || x === 10 || x === 15;
      if (cross) {
        ctx.fillStyle = '#f4f4f8';
        for (let i = 0; i < 4; i++) ctx.fillRect(px + 2 + i * 8, py + 3, 5, 26);
      } else if (y === 6 && x % 2 === 0) {
        ctx.fillStyle = '#ffd966'; ctx.fillRect(px + 6, py + TILE - 2, 20, 4);
      }
      break;
    }
    case 'T': grass(px, py, h); tree(px, py, h); break;
    case '~': {
      ctx.fillStyle = '#8fd8ff'; ctx.fillRect(px, py, TILE, TILE);
      ctx.strokeStyle = 'rgba(255,255,255,.7)'; ctx.lineWidth = 2;
      const o = Math.sin(t / 600 + x) * 3;
      ctx.beginPath(); ctx.moveTo(px + 4 + o, py + 12); ctx.quadraticCurveTo(px + 10 + o, py + 8, px + 16 + o, py + 12); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(px + 14 - o, py + 24); ctx.quadraticCurveTo(px + 20 - o, py + 20, px + 26 - o, py + 24); ctx.stroke();
      break;
    }
    case 'H': case 'C': case 'O': building(ch, x, y, px, py, t, h); break;
    case 'h': case 'c': case 'o': building(ch.toUpperCase(), x, y, px, py, t, h); door(ch, px, py); break;
    default: grass(px, py, h);
  }
}

function drawTowerTile(ch, x, y, px, py, t) {
  const h = hash(x, y);
  const floor = () => {
    ctx.fillStyle = '#f5dfc3'; ctx.fillRect(px, py, TILE, TILE);
    ctx.fillStyle = '#e8cba8';
    ctx.fillRect(px, py + 10, TILE, 1); ctx.fillRect(px, py + 21, TILE, 1);
    ctx.fillRect(px + ((x * 7) % 24), py, 1, 10); ctx.fillRect(px + ((x * 13 + 9) % 24), py + 11, 1, 10);
  };
  const carpet = () => {
    ctx.fillStyle = '#bcdaf6'; ctx.fillRect(px, py, TILE, TILE);
    ctx.fillStyle = '#a8cbef';
    ctx.beginPath(); ctx.moveTo(px + 16, py + 8); ctx.lineTo(px + 24, py + 16); ctx.lineTo(px + 16, py + 24); ctx.lineTo(px + 8, py + 16); ctx.fill();
  };
  switch (ch) {
    case 'W': {
      ctx.fillStyle = '#dccff3'; ctx.fillRect(px, py, TILE, TILE);
      const below = tileAt('tower', x, y + 1);
      if (below && below !== 'W') { ctx.fillStyle = '#c3b1e6'; ctx.fillRect(px, py + TILE - 6, TILE, 6); }
      if ((y === 0 || y === 3 || y === 10) && h % 3 === 0 && below && below !== 'W') {
        ctx.fillStyle = '#fff'; ctx.fillRect(px + 6, py + 4, 20, 18);
        ctx.fillStyle = '#bfe6ff'; ctx.fillRect(px + 8, py + 6, 16, 14);
        ctx.fillStyle = '#fff'; circle(px + 14 + Math.sin(t / 2000 + x) * 3, py + 13, 3);
      }
      break;
    }
    case '_': case 'x': floor(); if (ch === 'x') {
      ctx.fillStyle = '#e56b6f'; rrect(px + 2, py + 6, 28, 20, 4); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.font = 'bold 9px Fredoka, sans-serif'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText('EXIT', px + 16, py + 16);
    } break;
    case ':': carpet(); break;
    case 'd':
      carpet();
      ctx.fillStyle = '#b8875c'; ctx.fillRect(px + 2, py + 12, 28, 16);
      ctx.fillStyle = '#d4a275'; ctx.fillRect(px + 2, py + 12, 28, 5);
      ctx.fillStyle = '#555a6b'; ctx.fillRect(px + 9, py + 3, 14, 10);
      ctx.fillStyle = h % 2 ? '#8ff0ff' : '#ffc2e0'; ctx.fillRect(px + 10, py + 4, 12, 7);
      break;
    case 'p': floor(); emoji('🪴', px + 16, py + 15, 24); break;
    case 'g':
      floor();
      if (state && state.quest < 3) {
        const a = 0.45 + 0.2 * Math.sin(t / 250 + x);
        ctx.fillStyle = `rgba(190, 110, 255, ${a})`; ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = 'rgba(255,255,255,.6)';
        for (let i = 0; i < 3; i++) ctx.fillRect(px + 5 + i * 10, py + ((t / 20 + i * 11 + x * 7) % TILE), 2, 6);
      }
      break;
    default: floor();
  }
}

function label(text, cx, cy) {
  ctx.font = '600 11px Fredoka, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const w = ctx.measureText(text).width + 16;
  ctx.fillStyle = 'rgba(255,255,255,.92)';
  rrect(cx - w / 2, cy - 9, w, 18, 9); ctx.fill();
  ctx.strokeStyle = '#f5a8c8'; ctx.lineWidth = 1.5; ctx.stroke();
  ctx.fillStyle = '#6b4a7a';
  ctx.fillText(text, cx, cy + 1);
}

function drawCharacter(e, px, py, t, size = 24, bobSpeed = 400) {
  const bob = Math.sin(t / bobSpeed + px) * 1.5;
  ctx.fillStyle = 'rgba(60,40,80,.2)';
  ctx.beginPath(); ctx.ellipse(px + 16, py + 28, size * 0.42, 4, 0, 0, Math.PI * 2); ctx.fill();
  emoji(e, px + 16, py + 14 + bob, size);
}

function draw(t) {
  const s = state && mode !== 'title' ? state : { map: 'city', quest: -1 };
  const map = MAPS[s.map];
  const tileFn = s.map === 'city' ? drawCityTile : drawTowerTile;
  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) tileFn(map.rows[y][x], x, y, x * TILE, y * TILE, t);
  }

  if (s.map === 'city') {
    emoji('🦆', 5 * TILE + Math.sin(t / 1500) * 10, 12 * TILE - 2 + Math.sin(t / 300) * 1, 18);
    for (const v of vehicles) {
      ctx.save();
      ctx.translate(v.x + 16, v.row * TILE + 16);
      if (v.speed > 0) ctx.scale(-1, 1);
      emoji(v.emoji, 0, 0, 26);
      ctx.restore();
    }
  }

  for (const [text, cx, cy] of map.labels) label(text, cx, cy);

  // Characters, sorted by row so they overlap nicely
  const actors = [];
  if (s.player) {
    for (const n of npcsFor(s)) actors.push({ e: n.emoji, x: n.x * TILE, y: n.y * TILE, big: n.big });
    const [ppx, ppy] = playerPixelPos();
    actors.push({ e: s.player.emoji, x: ppx, y: ppy, player: true });
  }
  actors.sort((a, b) => a.y - b.y);
  for (const a of actors) {
    if (a.big) {
      const wob = Math.sin(t / 90) * (Math.sin(t / 1300) > 0.6 ? 2 : 0);
      drawCharacter(a.e, a.x + wob, a.y - 4, t, 36, 250);
    } else if (a.player) {
      const hop = mover.moving ? -Math.abs(Math.sin(mover.t * Math.PI)) * 4 : 0;
      drawCharacter(a.e, a.x, a.y + hop, t, 26, 600);
    } else {
      drawCharacter(a.e, a.x, a.y, t, 24);
    }
  }

  if (s.map === 'city' && flyer.wait <= 0) {
    ctx.save();
    ctx.translate(flyer.x, flyer.y + Math.sin(t / 250) * 4);
    ctx.scale(-1, 1);
    emoji(flyer.emoji, 0, 0, 22);
    ctx.restore();
    ctx.fillStyle = 'rgba(255,240,150,.8)';
    for (let i = 1; i < 5; i++) circle(flyer.x - i * 10, flyer.y + Math.sin(t / 250 - i) * 4 + 4, 3 - i * 0.5);
  }

  for (const sp of sparkles) {
    const a = Math.sin((sp.life / sp.max) * Math.PI);
    ctx.fillStyle = `hsla(${sp.hue}, 100%, 85%, ${a})`;
    const r = 3 * a;
    ctx.beginPath();
    ctx.moveTo(sp.x, sp.y - r * 2); ctx.lineTo(sp.x + r * 0.5, sp.y - r * 0.5); ctx.lineTo(sp.x + r * 2, sp.y);
    ctx.lineTo(sp.x + r * 0.5, sp.y + r * 0.5); ctx.lineTo(sp.x, sp.y + r * 2); ctx.lineTo(sp.x - r * 0.5, sp.y + r * 0.5);
    ctx.lineTo(sp.x - r * 2, sp.y); ctx.lineTo(sp.x - r * 0.5, sp.y - r * 0.5);
    ctx.fill();
  }

  for (const [hx, hy] of hintSpots(s.player ? s : null)) {
    emoji('❗', hx * TILE + 16, hy * TILE - 6 + Math.sin(t / 200) * 3, 18);
  }
}

let lastT = performance.now();
function frame(now) {
  const dt = Math.min(50, now - lastT);
  lastT = now;
  update(dt);
  draw(now);
  requestAnimationFrame(frame);
}

showTitle();
requestAnimationFrame(frame);
