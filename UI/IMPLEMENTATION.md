# Rebound UI implementation

## Scope
Complete front-end, tutorial, pause/results, preferences, HUD and feedback.
Stage 4 currency banking, records and permanent upgrades remain unimplemented.

## Foundation batch
- Shared dark arcade theme with green focus accents.
- Preferences store with versioning, type/range validation, safe defaults, save error reporting and reset support.
- Not registered as an autoload yet; no preferences applied to gameplay yet.

## Remaining work
1. Register settings and UI managers; reusable controls, navigation and confirmation modal.
2. Title, optional first-launch setup, paged tutorial and truthful credits.
3. Real loading transitions; pause/results integration preserving pausable enemies.
4. Functional tabbed settings, rebindable inputs, display rollback and accessibility.
5. Unified responsive HUD, event feedback and settings hooks.
6. Automated navigation, pause/death, settings persistence and runtime checks; interactive layout review.

Do not show unsupported settings as functioning. Do not manufacture records or a win screen for endless survival.
Keep existing movement/combat balance unchanged during UI integration.
