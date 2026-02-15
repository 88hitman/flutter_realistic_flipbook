## 0.1.4

- Add a navigation watchdog to detect stalled mid-flip states.
- Recover stalled flips/slides with animated settle/revert before hard reset.
- Improve resilience when gesture end/cancel signals are missed.

## 0.1.3

- Add `onFlipGuard` callback to validate a flip before animation starts.
- Add `FlipbookNavigationDirection` and `FlipbookFlipGuardCallback`.
- Prevent swipe/tap/programmatic flip start when guard returns `false`.

## 0.1.2

- Rework widget-page flip rendering pipeline for production stability.
- Use GPU snapshots (`ui.Image`) with `RawImage` during 3D strip rendering.
- Remove transient flash/disappearance at flip start in widget mode.
- Improve verso/recto continuity for widget pages during page curl.
- Update README with explicit Image mode vs Widget mode documentation.

## 0.1.1

- Fix README preview image for pub.dev by using an absolute HTTPS URL.
- Update README install snippet to `^0.1.1`.

## 0.1.0

- BREAKING: rename page chrome API to the new book* naming.
- Clean public docs and examples to book terminology only.
- Keep realistic page-turn rendering and interaction improvements.

## 0.0.2

- Add demo GIF preview in README.
- Improve example fullscreen layout for capture/demo.
- Fix and polish realistic page flip rendering behavior.

## 0.0.1

Initial public release of `flutter_realistic_flipbook`.

### Added

- Realistic 3D page turn rendering using polygon strips.
- Perspective transform pipeline with diffuse and specular lighting.
- Manual drag flip with velocity-aware completion.
- Automatic flip animation with start/end callbacks.
- Zoom support with animated transitions and wheel mode.
- Single-page and double-page layouts.
- Controller API (`flipLeft`, `flipRight`, `zoomIn`, `zoomOut`, `goToPage`).
- Hi-res image support via `FlipbookPage.hiResImage`.
- Optional book-style page chrome:
  - configurable top/bottom/side insets
  - per-page header/footer text
  - configurable border, shadow, and typography
