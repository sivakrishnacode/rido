/// Shows the "Design gallery" entry in the Account tab: off in the apps people use, on for development with
/// `--dart-define=TT_DESIGN_GALLERY=true`. The gallery itself stays (`/gallery`, and `scripts/export_design.py`).
const bool kShowDesignGallery = bool.fromEnvironment('TT_DESIGN_GALLERY');
