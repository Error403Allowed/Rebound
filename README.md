# Rebound

> A first-person horde survival game where you bounce back harder every time.

Rebound is a 1st person horde survival game built for **HackClub's Haven game jam**. Survive an increasingly large and powerful horde of enemies for as long as possible. Place a trampoline, launch yourself high into the air, and crush the enemies beneath you. A roguelite-style upgrade system lets you come back stronger after every death.

## Theme: "Bounce Back"

- **Core mechanic:** trampolines launch you into the air so you can bounce onto enemies and defeat them.
- **Progression:** dying lets you spend currency on upgrades, so you literally bounce back stronger than before.

## Team

| Name | Role |
| --- | --- |
| Shrravan | Lead programmer |
| Niyat | Programmer and asset creator |

## Gameplay Loop

1. Prepare for a wave of enemies
2. Place a trampoline in a useful spot
3. Launch yourself
4. Eliminate enemies by landing on them
5. Survive the wave and repeat for the next one
6. Buy upgrades

This repeats until you are defeated. **Upgrades are kept on death.**

## Win Condition

There isn't one. The game runs on an infinite loop, and the goal is to reach the highest score possible.

## Target Platform

- **Platforms:** PC (Windows, macOS, Linux), 64-bit
- **Input:** keyboard and mouse

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` | Move |
| Mouse | Look around |
| `Space` | Jump |
| `Shift` | Sprint (toggle by default, hold mode available in settings) |
| `E` | Enter or exit trampoline placement mode |
| Left click | Place trampoline |
| `F` | Open upgrades menu (pauses the game) |
| `Esc` | Open settings |

## Game Mechanics

### Health

- Player starts with **100 health**
- Basic mobs deal **5 damage**
- No healing until you buy a passive heal upgrade
- Upgrades can increase max health

### Trampolines

- **8 second cooldown** without upgrades (can be reduced with upgrades)
- Pressing `E` shows an outline preview of where the trampoline will be placed
- Stepping on a trampoline launches the player upward (max 3 seconds to reach peak height) and destroys the trampoline
- FOV changes with player acceleration (higher while falling than while rising)
- The player accelerates quickly on descent so landings feel satisfying

### Landing

- Landing creates a small shockwave ring that spreads outward
- The ring can be upgraded to slow enemies, knock them back, and more
- The landing damage zone starts small and can be enlarged with upgrades
- Descent acceleration can also be upgraded

## Enemies

| Enemy | Role | Stomps to kill | Speed | Damage | Notes |
| --- | --- | --- | --- | --- | --- |
| Slime | Basic chaser | 1 | About player normal speed | Contact damage | Basic enemy |
| Purple Slime | Speedy | 1 | 1.1x player sprint speed | 1.1x slime | Emits a bit of light. Occasional dash *(stretch goal)* |
| Golem | Tank | 4 | 0.9x player normal speed | 3x slime | Stomp attack stuns player for 0.5s *(stretch goal)* |
| Skeleton | Ranged *(stretch goal)* | 2 | Player normal speed | Ranged | Shoots fast arrows at the player |

## UI

Minimal text with drop shadows and no backgrounds, to keep focus on the game (text size around 12-14).

- **Top left:** `[F] for upgrades`, then `Experience: xxxx`, then `Score: xxxx`
- **Top right:** trampoline cooldown with one decimal (e.g. `5.3 seconds for trampoline placement`), switching to `"E" to place trampoline` when ready. Below it: `Health: xxx/100`
- **Bottom left:** smaller text, `"Esc" to open settings`

### Settings

- FPS cap
- Resolution
- Fullscreen / borderless fullscreen / windowed
- Sprint toggle / hold mode

## Map

An open grass field surrounded by barrier walls.

## Development Notes

- Scope is kept small by taking cues from Vampire Survivors-style games rather than building a complex boss.
- Stretch goals are marked in the enemy table. The core build needs the Slime, Purple Slime and Golem; the Skeleton is optional.
- Needs custom enemy assets and a strong, unique theme.
- Enemy AI needs to be solid, or the game can feel sloppy.

## Known Bugs

None right now (for now).

## Credits

Made by Shrravan and Niyat for HackClub's Haven game jam.
