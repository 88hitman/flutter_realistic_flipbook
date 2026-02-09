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
- Optional Mushaf-style page chrome:
  - configurable top/bottom/side insets
  - per-page header/footer text
  - configurable border, shadow, and typography
