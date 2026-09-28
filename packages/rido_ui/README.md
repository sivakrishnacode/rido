# rido_ui

The Rido design system for both Flutter apps (`@rido/ui`, not published to pub.dev).

- `theme/`: colours (`RidoColors`), tokens (spacing, radius, type scale), `RidoTheme`; fonts Poppins + Inter are bundled in `assets/google_fonts`
- `widgets/`: `RidoMap` (Google Maps or flutter_map + CARTO tiles), `RidoButton`, sheets, markers, countdown ring…
- `illustrations/`: vector illustrations drawn in code
- `design_system_board.dart`: the DS-00…DS-07 frames from [docs/design/system](../../docs/design/system)

Screens must use these tokens and widgets, not literal colours or one-off styles.

```bash
npx turbo run analyze test --filter=@rido/ui
```
