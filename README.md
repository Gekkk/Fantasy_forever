# ✨ Fantasy Forever ✨

A cozy little RPG set in **Moonbrook City**, a modern fantasy town where wizards
still commute to the office, dragons work reception and the bus is always late.

It's your first day at **Spellwork Tower**, and someone left the Enchanted
Alarm Clock on all weekend. It soaked up every bit of Monday grumpiness in the
city and became **the Monday Monster**. ⏰

## How to play

Open `index.html` in a browser. There's nothing to install and it works on phones too.

| | Keyboard | Phone |
|---|---|---|
| Walk | Arrow keys / WASD | D-pad |
| Talk / continue | Bump into people, or Space / Enter | **A** button |
| Pick a battle move | Click it, or press 1–5 | Tap it |
| Friendbook | B | 📖 button |

- Follow the ⭐ goal at the top and the ❗ markers on the map.
- Grumpy critters hide in the **flower beds** (park) and the **blue carpet** (office).
  You never hurt them. You cheer them up with magic and they join your 📖 Friendbook.
- Low on HP? Eat a 🧁 muffin, cast 💗 Cozy Heal, nap at 🏠 Home, or buy a ☕ latte at the café.
- Losing is gentle: you just wake up at home, fully healed.
- The game saves automatically in the browser.

## Personalize it 💌

At the very top of `game.js` there's a `CONFIG` block:

```js
const CONFIG = {
  defaultName: 'Luna',
  loveNote: 'Thank you for being my favorite adventurer. ...',
  encounterRate: 0.13,
};
```

`loveNote` is shown on the ending screen. Change it to whatever you want her to read.

## Play it online (optional)

To get a link you can open on a phone, enable **GitHub Pages** for this repo
(Settings → Pages → Deploy from branch → pick the branch → `/ (root)`).

## Files

- `index.html`: page layout (HUD, dialog box, battle screen, menus)
- `style.css`: the pastel look
- `game.js`: everything else (maps, story, critters, battles)
