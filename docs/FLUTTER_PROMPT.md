# Rido: Flutter Code Generation Prompt

Use this prompt with Claude Code, run from the project root so it can read `UI_PROMPTS.md`. If you exported designs from Claude Design (screenshots or code), put them in `/design` first; the prompt tells Claude to match them.

---

```
Build two Flutter apps for "Rido", a zero-commission ride-hailing and parcel delivery platform for Coimbatore, India:

1. apps/passenger: "Rido" (passengers book rides and send parcels)
2. apps/driver: "Rido Driver" (ride drivers and delivery drivers)

This is a FRONTEND-ONLY, clickable prototype. There is NO backend. All data comes from built-in seed data. Every button must work. The prototype must feel like a real app: flows move forward on their own using timers where a real backend would push updates (e.g. "driver found").

======================================================================
1. SOURCE OF TRUTH
======================================================================
- Screen specifications: read UI_PROMPTS.md in the project root. It defines the design system (Part 1) and every screen, with IDs (P-xx passenger, PP-xx parcel, D-xx driver, S-xx states). Implement EVERY screen listed there, with the layout, text and seed data described.
- Visual designs: docs/design/index.md lists every exported frame (PNG, 390×844 exported at 2x) in docs/design/system, docs/design/passenger, docs/design/parcel, docs/design/driver and docs/design/states. BEFORE building each screen, open its PNG and match it closely: layout, spacing, colours, text, icons and sample data. Where a PNG conflicts with UI_PROMPTS.md on visuals, the PNG wins; on flow and behaviour, this prompt wins.
- Variant frames use letter suffixes (e.g. P-07b trip-in-progress banner, D-17-error, D-24b paused, D-24c cancelled, D-25a grace, D-25b expired, D-18b driver SOS, P-23b / P-24b / P-25b forms, D-23b trip detail sheet). Build each variant as a state of the same screen, or as its own screen/sheet where it is a different screen.
- The maps in the PNGs are stylised placeholders; use real CARTO light tiles (section 3).

======================================================================
2. TECH STACK AND PROJECT STRUCTURE
======================================================================
- Flutter stable (latest), Dart 3, Material 3, null safety. Android only (portrait lock). Light theme only.
- Packages (use only these unless something is truly necessary; if you add one, say why):
  go_router, flutter_riverpod, google_fonts, flutter_map, latlong2, qr_flutter, fl_chart, intl, material_symbols_icons
- Icons: use material_symbols_icons (Symbols.* rounded style) so every icon name matches the designs exactly.
- Monorepo layout using path dependencies:

  /apps/passenger          Flutter app (applicationId: com.rido.passenger)
  /apps/driver             Flutter app (applicationId: com.rido.driver)
  /packages/rido_ui        Theme + all shared widgets
  /packages/rido_data      Models, seed data, mock repositories, simulation engine

- Inside each app:
  lib/
    main.dart
    router/app_router.dart          (every route defined here, nowhere else)
    router/routes.dart              (route path constants)
    features/<feature>/<screen>.dart
    features/design_gallery/        (see section 7)
- Screen class names use the frame ID: P10ChooseVehicleScreen, PP06ChooseGoodsVehicleScreen, D15IncomingRideRequestScreen, S01NoDriversScreen, etc.
- Route paths are readable: /ride/choose-vehicle, /parcel/review, /driver/request, etc.

======================================================================
3. DESIGN SYSTEM (packages/rido_ui)
======================================================================
Put every value from UI_PROMPTS.md Part 1 into code. No hardcoded colours or font sizes inside screens.
- RidoColors (const): coral500 #F4511E, coral600 #D84315, coral50 #FFF1EC, coral100 #FFDCCF, navy900 #1E293B, navy700 #334155, navy500 #64748B, surface #FFFFFF, background #F8FAFC, divider #E2E8F0, inputBg #F1F5F9, success #16A34A, warning #F59E0B, error #B91C1C, sos #DC2626
- RidoTheme.light(): builds ThemeData with ColorScheme (primary = coral600, secondary = navy900), TextTheme (Poppins headings, Inter body via google_fonts; sizes from the Part 1 type scale), plus a ThemeExtension<RidoTokens> for spacing (4/8/12/16/24/32), radii (12 card, 16 sheet, full pill) and shadows.
- Use tabular figures (FontFeature.tabularFigures()) for fares, OTPs and timers. Format money with an Indian-locale helper: formatInr(1420) → "₹1,420".
- Shared widgets (each in its own file, each with a short doc comment):
  RidoButton (primary / secondary / text / danger; disabled and loading states), SwipeToConfirm, PhoneInput (+91), OtpInput (4 or 6 boxes), SearchField, LocationRow + PickupDropConnector, VehicleOptionCard (selected / disabled + reason), ChoiceChips, StatusPill, MapBottomSheet (DraggableScrollableSheet with peek / half / full), DriverInfoCard (with an Indian number-plate widget), FareBreakdown, RidoBanner (info / warning / success / error), RidoAppBar, RidoBottomNav, RatingStars (display + input), CountdownRing, StepperTimeline, SosButton, CommissionBadge ("0% commission"), EmptyState (illustration + title + message + action), SkeletonBox (shimmer done with an AnimationController; no package), RidoMap (see below).
- Illustrations: draw simple flat illustrations with widgets / CustomPainter / Material icons in brand colours. Do not use network images. Driver and user photos: coloured circle avatars with initials.
- RidoMap: a flutter_map wrapper using the CARTO light-grey tiles
  https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png (subdomains a,b,c,d)
  with the required "© OpenStreetMap contributors © CARTO" attribution. It supports pickup marker (green dot with white ring), drop marker (coral pin), vehicle markers (navy icons for bike / auto / car / truck), a coral 5px route polyline, a pulse ring, and demand zones (translucent coral circles). If tiles fail to load (offline), show a plain #F1F5F9 background; the app must never crash.

======================================================================
4. SEED DATA AND MOCK LAYER (packages/rido_data)
======================================================================
- Models (immutable, with copyWith): Place, SavedPlace, VehicleType (rides + goods, with capacityKg, seats, fare rules), FareQuote, DriverProfile, PassengerProfile, Trip (ride or parcel), ParcelDetails, TripStatus enum, ChatMessage, EmergencyContact, SupportTicket, PlanStatus enum (trial, active, grace, expired), SubscriptionPlan, PaymentRecord, KycDocument + KycStatus enum, EarningsDay.
- Repositories as abstract interfaces + Mock implementations (AuthRepository, PlacesRepository, RideRepository, ParcelRepository, DriverRepository, SubscriptionRepository, SupportRepository). Mock versions use in-memory seed data and Future.delayed(300–800ms) so loading states are visible. Riverpod providers expose them, so a real API can replace them later without touching the UI.
- Seed data (use exactly these values; add more of the same style where lists need it):
  Places with approximate coordinates:
    Gandhipuram Central Bus Stand (11.0183, 76.9725), Brookefields Mall (11.0090, 76.9600), RS Puram (11.0089, 76.9500), Peelamedu (11.0290, 77.0270), PSG Tech (11.0247, 77.0028), Coimbatore Junction (10.9960, 76.9660), Coimbatore International Airport (11.0300, 77.0434), Tidel Park (11.0310, 77.0280), Race Course (10.9990, 76.9780), Saibaba Colony (11.0240, 76.9440), Prozone Mall Saravanampatti (11.0550, 76.9950), Ukkadam (10.9880, 76.9610), Town Hall (10.9930, 76.9610), Singanallur (10.9990, 77.0290)
  Passenger: Priya Raman, +91 98765 43210, female; Home = Saibaba Colony, Work = Tidel Park; emergency contacts Amma (+91 94430 11223), Ravi (+91 90030 44556)
  Drivers: Karthik S (bike, Honda Activa Grey, TN 37 AB 4521, 4.8★, 1,240 rides, UPI karthik@okaxis); Murugan P (auto, Bajaj RE, TN 38 C 7810, 4.7★); Arun Kumar (cab, Maruti Dzire, TN 66 D 3302, 4.9★); Selvam R (3-wheeler goods, Bajaj Maxima Cargo, TN 37 F 9914, 4.6★)
  Ride vehicles: Bike (1 seat), Auto (3 seats), Cab (4 seats)
  Goods vehicles: Bike (10 kg), 3-wheeler (500 kg), Mini truck (750 kg), Pickup (1,500 kg), Truck 14ft/17ft (4,000 kg)
  Fare engine (pure Dart function, used everywhere): fare = max(minFare, base + perKm × km + perMin × min) × multiplier (cap 1.5).
    Tune the rates so Gandhipuram → Brookefields (4.2 km, 14 min) = Bike ₹38, Auto ₹72, Cab ₹145, and Peelamedu → Race Course (6.8 km) = goods Bike ₹49, 3-wheeler ₹180, Mini truck ₹420. Current multiplier 1.1 ("Peak time"). The fare breakdown shows peak as its own line, e.g. Bike: Base ₹12 + Distance ₹21 + Time ₹2 = Subtotal ₹35, Peak time (1.1x) +₹3, Total ₹38. Round fares DOWN to the whole rupee (₹35 × 1.1 = ₹38.50 → ₹38; the peak line shows the difference, ₹3), and make every line in the breakdown add up exactly to the total. Distance = haversine × 1.3 road factor, duration = distance ÷ 18 km/h.
  Ride OTP: 4829. Delivery OTP: 7153. Login OTP: any 6 digits works except 000000 (shows "Incorrect OTP").
  Passenger history: the 4 trips listed in P-21. Receiver: Meena Ravi, +91 94433 21098.
  Driver: plan Bike ₹2,000/month, trial started today, next debit 24 Oct 2026; payment history Aug 2026 ₹2,000 paid; weekly earnings Mon–Sun [1120, 1340, 980, 1560, 1420, 1650, 870] (= ₹8,940), 86 rides, 42 online hours; lifetime commission saved ₹18,400. Subscription prices: bike/auto/cab ₹2,000, 3-wheeler ₹3,000, mini truck ₹4,000, pickup/truck "₹—".
  Chat quick replies and sample messages as in P-14. One open support ticket.
- Simulation engine (in rido_data): a TripSimulator that drives a trip through its statuses with timers and moves the vehicle marker along the route polyline (generate a slightly curved path between the two coordinates; no routing API). All timings are constants in one file, and the Demo Controls (section 7) have a "fast mode" that divides them by 3.

======================================================================
5. PASSENGER APP: NAVIGATION MAP (every button must do exactly this)
======================================================================
Startup: P-01 Splash (1.5 s) → first launch? P-02 Onboarding : logged in? Home : P-03.
- P-02: Skip / Get started → P-03
- P-03: Send OTP (enabled at 10 digits) → P-04. Terms / Privacy links → a simple scrollable text screen.
- P-04: Edit → back to P-03. Resend (after the countdown) → restarts the timer + SnackBar "OTP resent". Verify → new user ? P-05 : Home. 000000 → inline error.
- P-05: Continue → P-06
- P-06: Allow / Enter manually → Home (P-07)
- Home shell: StatefulShellRoute with 4 tabs (Ride = P-07, Parcel = PP-01, Activity = P-21, Account = P-23). Each tab keeps its own navigation stack.
- P-07: search field → P-08. Saved place or recent destination → P-10 with that drop. "+ Add" → a saved-place editor (simple screen). Avatar → Account tab. SOS shortcut → P-17.
- P-08: suggestion tap → P-10. "Set on map" → P-09. "Add stop" → disabled with a "Coming soon" tooltip.
- P-09: Confirm drop → P-10
- P-10: vehicle card tap → selects it (button label updates: "Book Auto · ₹72"). Fare info → P-11 bottom sheet. Women-driver toggle → state only. Book → P-12.
- P-12: after 3 s → P-13 (or S-01 if Demo Control "No drivers" is on). Cancel request → Home.
- P-13: Call → SnackBar "Calling Karthik (number hidden)". Chat → P-14. Share → P-18 sheet. Cancel → S-03 dialog (Cancel ride → Home + a cancelled trip appears in Activity; Keep ride → close). After 5 s → P-15. Demo Control "Driver cancels" → S-02, which re-searches and returns to P-13.
- P-14: quick reply or send → adds a message; after 2 s a seeded driver reply appears.
- P-15: after 4 s (the driver "enters the OTP") → P-16
- P-16: SOS → P-17. Share trip → P-18. The vehicle moves along the route; on arrival → P-19.
- P-17: Call 112 → confirmation dialog, then SnackBar "Calling 112". Contacts show "Live location sent ✓" one by one. I'm safe → back to the previous screen.
- P-19: Done, rate your ride → P-20
- P-20: Submit / Skip → Home; the trip is added to the top of Activity as Completed.
- P-21: tabs filter the list; item → P-22
- P-22: Get help with this trip → P-25 (with the trip preselected). Download receipt → SnackBar "Receipt saved".
- P-23: Saved places / Safety preferences / Terms & privacy / About Rido → simple screens in the same style. Emergency contacts → P-24. Help & support → P-25. Design gallery → section 7. Log out → confirmation dialog → P-03 (clears the stack).
- P-24: Add contact → a form sheet (max 3 contacts; adds to the list); swipe or delete icon removes one; the auto-share toggle stays switched.
- P-25: topic or Raise a ticket → a ticket form → submit adds it to "My tickets" as Open. Chat on WhatsApp → SnackBar "Opening WhatsApp".
Parcel tab:
- PP-01: Pickup card → PP-02. Deliver-to card → PP-03. Vehicle tile → preselects that vehicle and goes to PP-02. Recent parcel → P-22.
- PP-02 Confirm pickup → PP-03 → Confirm drop → PP-04
- PP-04: chips select; "See list" → PP-05 sheet; Continue is disabled until the prohibited-items box is ticked → PP-06
- PP-06: only vehicles that can carry the chosen weight are selectable (others greyed with a reason); payer segmented control; Book → PP-07
- PP-07 (3 s) → PP-08 → driver reaches pickup (4 s) → "Picked up" → PP-09 → arrives → PP-10
- PP-10: shows payer-specific text; rating + Done → Parcel tab; the parcel is added to Activity as Delivered.

======================================================================
6. DRIVER APP: NAVIGATION MAP
======================================================================
Startup: D-01 (1.5 s) → logged in? Home (D-13) : D-02.
- D-02: Join as a driver → D-03 (sign-up flow). "Already registered? Log in" → D-03 (login flow: after OTP go straight to D-13 as Karthik).
- D-03 (sign-up) → D-04 → D-05 (options depend on the work type: Rides = bike/auto/cab, Deliveries = bike/3-wheeler/mini truck/pickup/truck) → D-06 → D-07
- D-07: each "Upload" row → D-08 (simulated capture: "Take photo" shows a placeholder card image; "Use photo" → back, row becomes "Under review", then "Verified" after 3 s). Continue (enabled when all 5 are uploaded) → D-09 → D-10.
- D-10: after 4 s, or the "Check status" button → approved → D-11 (if Demo Control "Reject KYC" is on → S-09 with Re-upload → D-08).
- D-11: Set up UPI Autopay → D-12 (frame 1: pick a UPI app → 2 s processing → frame 2 success). Go online → Home (D-13) already online (D-14).
- Home shell: 4 tabs (Home = D-13/D-14, Earnings = D-23, Plan = D-24, Account = D-26).
- D-13: GO ONLINE → if the daily selfie check is due (the first time each app session) → S-13 → D-09 camera → back → D-14. If the plan is expired → the button is disabled and the D-25 expired banner is shown.
- D-14: Go offline → D-13. After 5 s online → incoming request: D-15 for ride drivers, D-20 for delivery drivers (based on the work type).
- D-15 / D-20: the 15 s CountdownRing runs; Accept → D-16 / D-21; Decline or timeout → back to D-14 (timeout shows the S-11 banner); the next request arrives 8 s later.
- D-16: Navigate → SnackBar "Opening Google Maps". Call / Chat → same pattern as the passenger app. "Arrived at pickup" swipe → D-17. Overflow → Cancel ride → reason dialog → D-14.
- D-17: OTP 4829 → Start ride → D-18. Any other code → shake animation + "Wrong OTP, please try again".
- D-18: SOS → a driver version of P-17. "Swipe to end ride" → D-19.
- D-19: "Received cash" or "Received on UPI" → a small passenger-rating sheet → D-14; today's earnings and ride count go up by the fare.
- D-21: StepperTimeline advances with a swipe at each step (Reached pickup → Picked up → Reached drop) → D-22.
- D-22: OTP 7153 → Complete → the collect-payment view (same as D-19, amount ₹180, "Paid by receiver" if set) → D-14.
- D-23: Today / Week / Month tabs switch the seed numbers; the chart uses fl_chart; trip list items → a simple trip detail sheet.
- D-24: Change UPI app → D-12 frame 1. Pause plan → confirmation dialog → status "Paused" + banner. Cancel plan → confirmation dialog (red) → status "Cancelled, active till 24 Oct 2026".
- D-25: Grace banner "Pay ₹2,000 now" → D-12 frame 1 → success → status Active. Expired "Renew ₹2,000" → same.
- S-14 (payment failed dialog) is shown when Demo Control "Fail next payment" is on and the driver pays; "Retry with another UPI app" → D-12; "Pay later" → Grace status.
- S-16 (GPS weak banner) appears on D-14 when Demo Control "GPS lost" is on; "Fix now" → SnackBar "Opening location settings".
- D-26: Documents → D-07 (read-only, all verified). Vehicle details / UPI ID / Emergency contact → simple edit screens. Refer a driver → a share sheet with the referral code "KARTHIK7". Help & support → the same support screens as P-25. Design gallery → section 7. Log out → confirmation → D-02.

======================================================================
7. DESIGN GALLERY (in BOTH apps)
======================================================================
Add a "Design gallery" item in the Account/Profile tab of both apps (visible in all builds for now; controlled by a const kShowDesignGallery = true).

The gallery screen has two tabs:

Tab 1: "Screens"
- A grouped list of EVERY frame in docs/design/index.md for that app, including all variant frames (a/b/c/-error), by part (Passenger app: Part 2, Part 3, Part 4, Part 7 passenger states; Driver app: Part 5, Part 6, Part 7 driver states), plus the design system board.
- Each row: frame ID chip (e.g. "P-10"), screen name, and a tag: "In flow" or "Showcase only".
- Tap → opens that screen on its own with seed data (bottom sheets and dialogs open over a plain background; states and variants such as D-25 grace/expired, S-01…S-16 and skeleton loading show their exact state).
- Screens that are not reachable in the normal flow MUST be listed here, so every designed screen can be viewed. Also add a search field that filters by ID or name.
- A "Design system" entry that shows a live board: colour swatches with hex values, the type scale, spacing and radius, and every rido_ui widget in all its states (buttons, inputs, chips, pills, cards, banners, OTP input, swipe button, rating stars, countdown ring, stepper, map markers).

Tab 2: "Demo controls"
- Switches that change the mock data so every state can be shown inside the real flow:
  Passenger: No drivers nearby, Driver cancels, Offline mode (shows S-04 on data screens), Location denied (S-05), Outside service area (S-08), Empty activity (S-06), Slow loading (shows skeletons for 3 s, S-07)
  Driver: Plan status (Trial / Active / Grace / Expired), Reject KYC, Account on hold (S-10), Fail next payment, GPS lost, Empty earnings (S-15), Work type (Rides / Deliveries)
  Both: Fast mode (timers ÷ 3), Reset all seed data
- Changes apply immediately (Riverpod state).

======================================================================
8. QUALITY RULES
======================================================================
- NO dead buttons. Every tappable widget must navigate, open a sheet or dialog, change visible state, or show a meaningful SnackBar. The only "Coming soon" allowed is "Add stop" on P-08.
- The Android back button behaves correctly everywhere: sheets close first, dialogs close, and flows go back a step. During an active trip, back on P-16 / D-18 asks "Leave this screen? Your trip continues." and returns to Home with a "Trip in progress" banner that reopens the trip.
- Timers are cancelled when a screen is disposed; no setState after dispose; no memory leaks.
- Every screen works on 360–430 px wide phones with no overflow, and scrolls when the keyboard opens.
- Semantic labels on icon-only buttons; tap targets ≥ 48 px.
- `flutter analyze` must show zero issues in all 4 packages. Use const constructors where possible.
- Tests (in each app):
  1. A widget test that opens EVERY route from the Design gallery list and asserts it builds without exceptions or overflow errors.
  2. An integration-style widget test for the main path: passenger books a bike ride Gandhipuram → Brookefields through to rating; driver goes online → accepts → OTP 4829 → ends ride → collects payment. (Use fast mode and fake async.)
- Add a README.md at the root: how to run each app (`cd apps/passenger && flutter run`), the folder structure, where seed data lives, and how to swap mock repositories for a real API.

======================================================================
9. HOW TO WORK
======================================================================
Build in this order, and run `flutter analyze` after each step, fixing everything before moving on:
1. Workspace + packages scaffold, rido_ui theme and all shared widgets, the design system board
2. rido_data models, seed data, fare engine, mock repositories, TripSimulator
3. Passenger app: routing shell + Parts 2 and 3
4. Passenger app: Part 4 (Parcel) + passenger state screens + Design gallery
5. Driver app: Part 5, then Part 6, then driver state screens + Design gallery
6. Tests + README
At the end, give me a checklist table of every screen ID with: implemented ✓, reachable in the flow (yes/no), listed in the gallery ✓.
```
