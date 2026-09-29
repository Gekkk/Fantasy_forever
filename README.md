# Fantasy Forever

A cozy 2.5D fantasy RPG made with **Godot 4.7**, set in **Moonbrook City**, a magical
town where wizards still commute to the office, dragons work reception and the
sky-tram is always late.

It's your first day at **Spellwork Tower**, and someone left the Enchanted Alarm
Clock on all weekend. It soaked up every bit of Monday grumpiness in the city
and became **the Monday Monster**.

## Play

- **In a browser / on a phone:** the `docs/` folder holds a ready-made web build.
  Turn on GitHub Pages (Settings → Pages → Deploy from a branch → this branch →
  `/docs`) and open `https://<your-user>.github.io/Fantasy_forever/`.
  Hold your phone sideways for the best view.
- **On a computer with Godot:** open `godot/project.godot` in Godot 4.7 and press Play.

| | Keyboard | Phone |
|---|---|---|
| Walk | WASD / arrow keys | Left side joystick |
| Talk, confirm, swing wand | Space / Enter / E | **A** |
| Menu, back | Esc / M | **B** or "Menu" |

## How battles work

- **Timed hits:** when you attack or cast, a ring shrinks onto the target. Press
  as it lines up with the circle: *Nice!* = x1.2, *Perfect!* = x1.5.
- **Timed guards:** when a critter lunges at you, press as it arrives to block half
  the damage. A *Perfect Guard* blocks everything.
- **Intents:** each critter shows what it will do next. "Charging up!" means a
  big attack next turn.
- **Weaknesses:** Fire, Ice or Sparkle. Hitting a weakness does bonus damage and
  makes the critter dizzy for a turn.
- **Mochi** the cat fights beside you: pounces, purrs you back to health or cheers
  you on.
- Swing your wand at a critter in the overworld for a **First Strike**.
- Losing is gentle: you wake up at home, fully healed.

There are also 5 hidden **Star Shards** to find (they teach a secret spell), a
Friendbook of every critter you've cheered up, and a cafe with snacks.

## Personalize it

At the top of `godot/scripts/game.gd`:

```gdscript
const DEFAULT_NAME := "Luna"
const LOVE_NOTE := "Thank you for being my favorite adventurer..."
```

`LOVE_NOTE` appears on the ending screen. After changing it, re-export the web
build (below).

## Project layout

- `godot/`: the Godot project. Everything visual is built from code
  (`scripts/models.gd` for characters, `scripts/world.gd` for maps).
- `godot/scripts/battle.gd`: the battle system. `godot/scripts/story.gd`: all dialogue and quests.
- `tools/make_audio.py`: synthesizes all music and sound effects (needs numpy).
- `tools/make_textures.py`: draws the icons and sparkles (needs Pillow).
- `docs/`: the exported web build.
- `legacy-html/`: the first, simpler browser version.

## Rebuilding

```sh
python3 tools/make_audio.py      # regenerate music + SFX into godot/audio
python3 tools/make_textures.py   # regenerate icons into godot/textures
godot --headless --path godot --export-release "Web" ../docs/index.html
```

An automated play-through (the whole quest plus dozens of battles) can be run with:

```sh
godot --path godot -- --autotest
```
