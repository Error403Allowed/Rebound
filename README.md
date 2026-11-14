# Rebound

**Game Jam Project**  
**3D · First-Person · Low-Poly**

Showcase references: Polyjump, Stilt, Deku Deals, Stylized Snow & Pine Forest

## 1. Project Overview

| Field | Details |
|---|---|
| Working title | Rebound |
| Genre | 3D First-Person Platformer / Physics-Based Adventure |
| Perspective | First-person |
| Art style | Low-poly, colourful, stylised environments |
| Platform | PC |
| Engine recommendation | Godot 4 |
| Development team | 2 developers |
| Estimated development time | 11 hours |

### Concept

Rebound is a fast-paced, physics-based first-person platformer in which the player must climb an enormous mountain using strategically placed trampolines, floating platforms and environmental obstacles.

Rather than relying on traditional climbing mechanics, the player must use momentum, timing and spatial awareness to launch themselves between increasingly difficult sections of the mountain.

The mountain acts as one enormous vertical obstacle course. Every trampoline presents an opportunity to gain height, while poorly timed jumps can send the player falling back toward lower sections.

The ultimate objective is simple:

**Reach the summit of the mountain.**

The game should feel satisfying, slightly chaotic and rewarding, with a strong emphasis on momentum-based movement and increasingly challenging jumps.

## 2. Core Gameplay

### Primary Gameplay Loop

1. Explore the mountain and identify the next trampoline.
2. Jump onto the trampoline.
3. Build or maintain momentum.
4. Get launched into the air.
5. Steer toward the next platform.
6. Land successfully and continue climbing.
7. Reach the summit.

The central mechanic is the interaction between the player and trampolines.

### Player Controls

| Input | Action |
|---|---|
| WASD | Movement |
| Mouse | Camera control |
| Space | Jump |
| Shift | Sprint |
| Esc | Pause |

### Movement Mechanics

#### Walking and Sprinting

- Standard first-person movement.
- Sprinting increases horizontal speed.
- Air control allows the player to adjust their trajectory.

#### Jumping

- Standard jump with adjustable horizontal movement.
- Jump height should be consistent and predictable.
- Jumping is primarily used for small gaps and platform adjustments.

#### Trampoline Bouncing

- Contact with a trampoline launches the player upwards.
- Different trampolines can have different bounce strengths.
- The player retains some horizontal momentum.
- Landing near the centre could provide a stronger bounce than landing near the edge.

#### Air Control

- The player can influence their direction while airborne.
- Momentum should still matter, preventing instant changes in direction.
- The physics should feel responsive rather than excessively realistic.

## 3. Level Design

The game should feature one continuous mountain divided into distinct sections. Each section introduces a new challenge or mechanic.

### Section 1 — The Foothills — Easy

- Introduces basic movement and jumping.
- Large, stable trampolines.
- Wide platforms with generous landing areas.
- Minimal hazards.

**Purpose:** Teach players how bouncing works without immediately punishing mistakes.

### Section 2 — The Forest — Medium

- Trampolines positioned between trees.
- Smaller landing platforms.
- Greater vertical distances.
- Introduction of angled trampolines.

**Purpose:** Introduce precision and momentum management.

### Section 3 — The Rocky Cliffs — Hard

- Narrow platforms.
- Stronger trampoline launches.
- Larger gaps.
- Moving platforms or rotating obstacles.

**Purpose:** Test the player’s understanding of movement and airborne control.

### Section 4 — The Snowy Peak — Very hard

- Smaller trampolines.
- High-altitude jumps.
- Limited landing areas.
- Strong winds or other environmental obstacles.

**Purpose:** Provide a final challenge before reaching the summit.

### Section 5 — The Summit — Completion

- Final trampoline sequence.
- Large summit platform.
- Panoramic mountain view.
- Victory screen.

**Purpose:** The summit should provide a satisfying visual payoff for completing the climb.

## 4. Visual Direction and Art Style

The game will use a low-poly art style to keep development achievable within the time limit while creating a distinctive visual identity.

### Environment Design

| Environment | Visual characteristics |
|---|---|
| Foothills | Bright green grass, simple trees, flowers |
| Forest | Pine trees, darker grass, wooden platforms |
| Rocky cliffs | Brown rocks, grey stone, steep cliffs |
| Snowy peak | White snow, blue ice, cold lighting |
| Summit | Snow-covered peak, clouds and panoramic views |

### Colour Palette

- Grass
- Forest
- Rock
- Snow
- Sky

### Trampoline Design

Trampolines should be visually distinctive and immediately recognisable.

- Circular trampoline surface.
- Simple metallic or wooden frame.
- Brightly coloured bouncing surface.
- Animated deformation when the player lands.
- Visual particles when launching.

| Colour | Bounce strength |
|---|---|
| Green | Standard bounce |
| Blue | Strong bounce |
| Purple | Extremely strong bounce |

This communicates gameplay information without requiring tutorials or complicated UI.

## 5. Game Mechanics and Additional Features

These features should be prioritised according to their development cost.

### Essential Features

| Feature | Description | Priority |
|---|---|---|
| First-person movement | Walking, sprinting and jumping | Critical |
| Trampoline physics | Launches the player upwards | Critical |
| Air control | Steering while airborne | Critical |
| Mountain environment | Continuous climbing level | Critical |
| Checkpoints | Save progress at certain locations | High |
| Death and respawning | Return player to checkpoint | High |
| Win condition | Detect summit completion | High |

### Optional Features

1. Different Trampoline Types
   - Standard trampolines.
   - Super trampolines.
   - Directional trampolines that launch players at an angle.

2. Environmental Hazards
   - Falling rocks.
   - Wind zones.
   - Moving platforms.
   - Slippery ice.

3. Collectibles
   - Small floating objects scattered throughout the mountain.
   - Collectibles could provide an optional challenge for players who want to explore.

4. Timer
   - A timer tracks how long it takes to reach the summit.
   - This introduces replayability and encourages players to improve their completion time.

5. Fall Detection
   - If the player falls below a certain height, they respawn at their latest checkpoint.

## 6. User Interface and Audio

### User Interface

The interface should remain minimal to preserve immersion.

Suggested elements:

- Small central crosshair.
- Current altitude or progress indicator.
- Optional completion timer.
- Minimal checkpoint notification.
- Pause menu.
- Victory screen.

### Audio Design

Sound should reinforce the physicality of the trampoline mechanics.

| Event | Sound |
|---|---|
| Walking | Light footsteps |
| Jumping | Short jump sound |
| Trampoline contact | Spring compression sound |
| Trampoline launch | Satisfying launch sound |
| Landing | Impact sound |
| Checkpoint | Short notification |
| Reaching summit | Victory music |

Music should be relatively calm during exploration, with more energetic audio during the final section.

## 7. Technical Implementation

### Recommended Technology

- Godot 4 — recommended engine for this project.
- GDScript — built-in scripting language.
- Built-in 3D physics — suitable for movement and trampoline interactions.
- CharacterBody3D — standard 3D player controller.
- Standard 3D rendering — sufficient for the low-poly visual style.

Godot is a good fit because it is lightweight, has straightforward scripting and supports rapid prototyping.

### Core Technical Systems

#### Player Controller

Use `CharacterBody3D` for the player.

Responsibilities:

- Process keyboard movement.
- Apply gravity.
- Handle jumping.
- Control the first-person camera.
- Maintain horizontal momentum.
- Handle airborne movement.

#### Trampoline System

Use an `Area3D` or collision-based detection system.

When the player enters the trampoline:

- Detect player contact.
- Calculate the launch direction.
- Apply an upward velocity.
- Preserve appropriate horizontal momentum.
- Trigger the trampoline animation and sound.

A simple implementation could use a configurable launch velocity rather than a complicated physical simulation.

#### Checkpoint System

- Place checkpoint objects at important sections.
- Store the latest checkpoint position.
- Respawn the player at that position after falling.

#### Level System

Build the entire mountain using modular-looking but individually placed geometry.

Use:

- Cubes and simple meshes for platforms.
- Low-poly rocks.
- Simple tree models.
- Repeated trampoline designs.
- Basic terrain geometry.

Do not spend time creating a sophisticated procedural mountain generator.

### Suggested Project Structure

```text
SummitBounce/
 ├── Scenes/
 │   ├── Main.tscn
 │   ├── Player.tscn
 │   ├── Trampoline.tscn
 │   ├── Checkpoint.tscn
 │   └── Mountain.tscn
 │
 ├── Scripts/
 │   ├── player.gd
 │   ├── trampoline.gd
 │   └── checkpoint.gd
 │
 ├── Assets/
 │   ├── Materials/
 │   ├── Models/
 │   └── Audio/
 │
 └── UI/
     ├── HUD.tscn
     ├── PauseMenu.tscn
     └── WinScreen.tscn
```

## 8. Development Plan — 11-Hour Game Jam

The biggest risk is spending too long creating assets and environments before the core movement is enjoyable.

The game should be playable as early as possible.

### Development Principle

**Build the movement first, then build the game around it.**

### Hour-by-Hour Schedule

| Time | Task |
|---|---|
| Hour 0–1 | Project setup and movement |
| Hour 1–2 | Trampoline mechanics |
| Hour 2–3 | Prototype level |
| Hour 3–5 | Environment and level design |
| Hour 5–6 | Progression systems |
| Hour 6–7 | UI and audio |
| Hour 7–9 | Polish |
| Hour 9–10 | Testing |
| Hour 10–11 | Finalisation |

### Hour 0–1: Project Setup and Movement

- Create the project.
- Implement first-person camera.
- Implement WASD movement.
- Add jumping and gravity.
- Test movement in a basic environment.

### Hour 1–2: Trampoline Mechanics

- Create trampoline scene.
- Implement bounce detection.
- Tune launch velocity.
- Add horizontal momentum and air control.
- Test repeated trampoline jumps.

### Hour 2–3: Prototype Level

- Create basic mountain geometry.
- Place trampolines.
- Create platforms and gaps.
- Ensure the entire climbing sequence is possible.

### Hour 3–5: Environment and Level Design

- Create distinct mountain sections.
- Add trees, rocks and snow.
- Improve trampoline appearance.
- Add environmental variation.

### Hour 5–6: Progression Systems

- Implement checkpoints.
- Add fall detection.
- Implement respawning.
- Add summit completion detection.

### Hour 6–7: UI and Audio

- Add timer and crosshair.
- Add checkpoint notifications.
- Add sound effects.
- Create victory screen.

### Hour 7–9: Polish

- Improve lighting.
- Add particles.
- Add trampoline animations.
- Improve camera feedback.
- Adjust level difficulty.

### Hour 9–10: Testing

- Complete the entire game.
- Fix bugs and unreachable jumps.
- Check respawning.
- Test different movement situations.

### Hour 10–11: Finalisation

- Fix remaining issues.
- Improve the start screen.
- Export the game.
- Test the exported build.

### Division of Work

For a two-person team, split responsibilities according to systems rather than trying to work on the same scripts simultaneously.

| Developer 1 | Developer 2 |
|---|---|
| Player controller | Environment design |
| Trampoline mechanics | Mountain level construction |
| Physics tuning | Checkpoint placement |
| Movement bugs | Environmental assets |
| Bounce animations | Lighting and atmosphere |

Both developers should collaborate on testing, UI and final polish.

**Important:** Avoid building a reusable component framework. Create only the individual scenes and scripts necessary for the finished game. A single configurable trampoline scene is sufficient.

## 9. Scope Management

Given the 11-hour development window, feature prioritisation is essential.

### Must-Have vs Stretch Goals

| Must-have | Stretch goals |
|---|---|
| First-person movement | Wind physics |
| Trampoline bouncing | Multiple trampoline types |
| One complete mountain | Collectibles |
| Checkpoints | Moving platforms |
| Death and respawning | Timer leaderboard |
| Summit victory condition | Dynamic weather |
| Basic environment | Advanced particles |

Do not sacrifice a complete playable game for optional features.

A polished game with one excellent climbing sequence is preferable to a large unfinished mountain.

### Features to Cut if Development Falls Behind

- Collectibles.
- Moving platforms.
- Different trampoline types.
- Advanced environmental effects.
- Complex UI.

Keep the core movement, trampoline physics and mountain progression intact.

## 10. Difficulty and Game Balancing

The difficulty should increase gradually rather than relying entirely on increasingly difficult jumps.

| Section | Platform size | Bounce strength | Difficulty |
|---|---|---|---|
| Foothills | Large | Medium | 2/10 |
| Forest | Medium | Medium | 4/10 |
| Rocky cliffs | Small | High | 7/10 |
| Snowy peak | Small | Variable | 9/10 |
| Summit | Large | High | 6/10 |

These are initial design targets, not fixed values.

The most important balancing consideration is that players should feel responsible for their mistakes. A failed jump should generally result from poor positioning or timing, not unpredictable physics.

Checkpoints should prevent players from having to repeat large sections of the mountain.

## 11. Potential Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Unresponsive movement | Very high | Prototype and tune movement immediately |
| Unpredictable trampoline physics | Very high | Use controlled launch velocities |
| Poor level progression | High | Test every jump |
| Excessive development time | High | Prioritise core features |
| Inconsistent visual style | Medium | Use a limited colour palette |
| Performance issues | Medium | Use simple geometry and lighting |
| Unreachable platforms | High | Test the entire level repeatedly |

## 12. Definition of a Successful Final Product

The project will be considered complete when:

- The player can move around in first person.
- The player can jump and control their movement in the air.
- Trampolines launch the player consistently.
- The player can climb the entire mountain.
- The level contains distinct environmental sections.
- Falling causes the player to respawn.
- Checkpoints function correctly.
- The summit triggers a victory screen.
- The game has consistent low-poly visuals.
- The game has basic sound effects.
- The exported PC build works correctly.

## 13. Final Vision

The final product should feel like a small but polished indie platformer.

Its defining feature is the trampoline-based movement system. Players should enjoy experimenting with momentum, making difficult jumps and gradually mastering the mountain.

The visual design should be colourful, readable and cohesive, while the level design should create a clear sense of vertical progression.

The game should be immediately understandable without requiring lengthy tutorials.

### Ideal Player Experience

- The first few jumps teach the mechanics.
- The middle sections challenge the player’s precision.
- The final sections test their mastery of movement.
- Reaching the summit provides a satisfying conclusion.

### Overall Project Priorities

| Area | Priority allocation |
|---|---|
| Movement and trampoline physics | 40% |
| Level design | 25% |
| Visuals and environment | 20% |
| UI, audio and polish | 15% |

This is a suggested allocation of development effort, not additional hours.

### Central Design Decision

**Make the trampoline mechanic exceptionally satisfying. Everything else should support that mechanic rather than compete with it.**
