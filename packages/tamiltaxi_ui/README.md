# tamiltaxi_ui

The Tamil Taxi design system for both Flutter apps (`@tamiltaxi/ui`, not published to pub.dev).

- `theme/`: colours (`TtColors`), tokens (spacing, radius, type scale), `TtTheme`; fonts Poppins + Inter are bundled in `assets/google_fonts`
- `widgets/`: `TtMap` (Google Maps or flutter_map + CARTO tiles), `TtButton`, sheets, markers, countdown ring…
- `illustrations/`: vector illustrations drawn in code
- `design_system_board.dart`: the live design-system board (screenshots in [docs/design/system](../../docs/design/system))

Screens must use these tokens and widgets, not literal colours or one-off styles.

```bash
npx turbo run analyze test --filter=@tamiltaxi/ui
```
