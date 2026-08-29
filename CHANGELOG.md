# Changelog

## Unreleased

- Added a persistent left/right **Dock Side** choice in Scene's menu.
- The two-pixel sensor, shelf placement, entrance/exit motion, dismiss arrow, footer hint, and 48-point rearm zone now mirror as one system.
- Existing `library.json` files decode as Left without resetting any book or reader preference.
- Entrance and exit motion now respect Reduce Motion.

## 0.2.0 — 2026-08-29

- First independent Scene release.
- Added a passive left-edge dwell sensor that never consumes clicks.
- Added Dock-like slide, hover breathing, and natural dismissal.
- Kept `⌥B`, per-book reader routing, Libby, and optional Mirror handoff.
- Reused the machine's stable signing identity so Documents access is requested once rather than after each local rebuild.
- Deferred the first library scan until Scene is deliberately revealed, keeping background launch silent.
