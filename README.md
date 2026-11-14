# REBOUND

**Game Pitch — “Bounce Back”**

## Pitch

**Rebound** is a fast-paced 2D trampoline-ricochet game where players are constantly falling, but can choose their next ricochet from any trampoline.

You play as an explorer trapped inside a collapsing tower. Jumping is impossible, and flying cannot save you. There is only one solution: land on trampolines, briefly slow time, and choose the trajectory for your next launch.

But launching straight up is not allowed. To move further, you must use ceilings, walls, moving trampolines, and other obstacles to redirect your fall.

## How It Works

When you land on a trampoline, time briefly slows down. A launch arc appears, showing where you will go based on your aim and current momentum.

Move the mouse to choose your rebound angle, then click or release to launch. The faster you are falling, the more force you have — but that also makes the launch harder to control.

Trampolines are not just springs; they are aiming tools. You are not simply jumping upward — you are reading your momentum, planning a trajectory, and using the environment to keep moving.

## Gameplay Loop

- Start near the bottom of a collapsing tower.
- The camera slowly rises, creating constant pressure to move upward.
- If you fall below the camera, you lose.
- Steer slightly in the air and look for the next trampoline.
- When you land, time slows for a fraction of a second.
- Aim your rebound, launch, and keep going.
- Navigate short, hand-designed tower sections with safe, risky, and hidden routes.

Some routes are safe but slow. Others require risky wall rebounds, precise angle changes, or powerful launches from smaller trampolines.

## Why It Fits “Bounce Back”

**Rebound** fits the theme in two ways:

- **Literally**, you constantly bounce back from trampolines, walls, and ceilings.
- **Thematically**, every setback creates an opportunity. A dangerous fall gives you more momentum, while a missed route can send you toward a different path.

You are always recovering, redirecting, and finding a new way upward. The game is not about avoiding falls — it is about using them.

## What Makes It Different

Most vertical jumping games focus on bouncing from platform to platform and climbing as high as possible. **Rebound** is different because you control the direction of every launch.

Instead of only steering while airborne, each trampoline gives you a short aiming window. You choose your angle, consider your speed, and use the tower’s walls and hazards to create your own route upward.

The result is less like an endless climber and more like a fast, precision ricochet game with a clear goal: escape the tower before time runs out.

## Core Features

- Fast 2D trampoline-ricochet movement
- Aim-and-launch system for choosing every rebound angle
- Momentum-based launches — harder falls create more force
- Short slow-motion aiming window after every landing
- Walls, ceilings, and hazards that redirect the player
- Hand-designed tower sections with safe, risky, and hidden routes
- Rising camera and timer for constant pressure
- Three trampoline types: normal, power, and angle
- Quick restarts and a clear escape goal

## Trampoline Types

| Type | Description |
|---|---|
| **Normal** | Provides a balanced launch and is used for reliable movement through the tower. |
| **Power** | Launches you much higher, but the extra force makes it harder to control. Great for reaching high areas quickly, but risky when precision is needed. |
| **Angle** | Does not launch you as high, but allows sharp redirection. Essential for wall rebounds, tight corridors, and alternate routes. |

## Visual Style

**Rebound** uses a clean, high-contrast arcade look: a dark industrial tower, glowing trampolines, bright launch arcs, and bold particles whenever you rebound.

- Trampolines squash when you land and stretch back when you launch.
- The player stretches in the direction of launch.
- A trail follows the player’s movement.
- Perfectly aimed rebounds create a particle burst and a small screen shake.

The visuals are designed to make momentum easy to read: you should instantly understand where you are going, how fast you are moving, and which route is risky.

## Game Structure

The first version is a single **90-second escape run** through a vertical tower. Your goal is to reach the exit at the top before the timer runs out.

The tower has **five main sections**, each introducing a new movement idea:

1. Basic trampolines
2. Wall rebounds
3. Moving trampolines
4. Hazards
5. Final vertical escape sequence

There are no enemies, upgrades, collectibles, or multiple levels in the first version. The focus is on making the rebound mechanic feel precise, satisfying, and easy to understand.

## Development Plan

**Rebound** is being built in **Godot** as a 2D game.

The prototype will focus on the essential systems:

- Player gravity
- Trampoline collisions
- Aiming
- Launch force
- Wall rebounds
- Camera pressure
- Timer
- Death and restart

Once the core mechanic feels good, polish will include:

- Trampoline squash-and-stretch
- Launch trails
- Particles
- Screen shake
- Sound effects

## Controls

| Input | Action |
|---|---|
| `A` / `D` or arrow keys | Slight horizontal movement while airborne |
| Mouse | Aim rebound direction after landing on a trampoline |
| Left click / release | Launch |
| `R` | Restart the run instantly |

## Closing

**Rebound** is a game about turning every fall into a decision.

You fall, you aim, you rebound, and you escape the tower before it collapses.

You do not just bounce back — **you choose how.**

Sources
