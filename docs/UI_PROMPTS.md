# Rido: UI Design Prompts for Claude Design

Paste these parts **in order, in the same Claude Design conversation**. Part 1 sets up the design system, and every later part builds on it.

| Part | Covers | Screens |
|---|---|---|
| 1 | Design system and core components | 1 board |
| 2 | Passenger app: sign-in and booking a ride | 12 |
| 3 | Passenger app: during and after the ride, account | 13 |
| 4 | Passenger app: Send Parcel | 10 |
| 5 | Driver app: sign-up, KYC and subscription | 12 |
| 6 | Driver app: home, rides, deliveries, earnings | 14 |
| 7 | Empty, loading and error states (both apps) | 16 |

---

## PART 1: Design system

```
You are designing the mobile UI for "Rido", a ride-hailing and parcel delivery app for Coimbatore, India. Rido charges drivers a flat monthly subscription instead of commission, so drivers keep 100% of every fare and passengers pay lower fares.

There are TWO Android apps, and both use the same design system:
1. Rido (passenger app): book bike, auto and cab rides, and send parcels
2. Rido Driver (driver app): for ride drivers and delivery drivers

In this first step, create ONLY the design system board. I will ask for screens in later messages, and every later screen must follow this system exactly. The design will be rebuilt in Flutter (Material 3), so keep everything consistent, reusable and easy to map to widgets.

BRAND
- Name: Rido. Wordmark: lowercase "rido" in bold, rounded, geometric type, with the dot of the "i" in coral.
- Personality: friendly, simple, trustworthy and local. It should feel warm and easy for everyone in Coimbatore: students, office workers, shop owners and older users. Not corporate, not flashy.
- Light mode only.

COLOURS
Primary: Coral
- coral-500 #F4511E (brand colour: logo, illustrations, large highlights, active icons)
- coral-600 #D84315 (primary button fill and coral text, so white text on it stays readable)
- coral-50  #FFF1EC (tinted backgrounds, selected cards, chips)
- coral-100 #FFDCCF (borders of selected items)
Secondary: Navy
- navy-900 #1E293B (headings, main text, dark buttons, top of the driver app)
- navy-700 #334155 (secondary text)
- navy-500 #64748B (hints, captions, inactive icons)
Neutrals
- surface #FFFFFF, background #F8FAFC, divider #E2E8F0, input-bg #F1F5F9
Status
- success #16A34A (online, completed, paid, verified)
- warning #F59E0B (grace period, pending review, surge)
- error   #B91C1C (errors, rejected)
- sos     #DC2626 (SOS button only: always a filled red circle with a white icon and the label "SOS")
Map markers
- Pickup: green dot with a white ring. Drop: coral pin. Driver vehicle: small navy top-down vehicle icon (bike, auto, car or truck). Route line: coral-500, 5px.

TYPOGRAPHY
- Headings: Poppins (SemiBold 600 / Bold 700)
- Body and UI: Inter (Regular 400 / Medium 500 / SemiBold 600)
- Scale: Display 28/36 Bold · H1 22/30 SemiBold · H2 18/26 SemiBold · Body 16/24 · Body-small 14/20 · Caption 12/16 · Button 16/24 SemiBold
- Prices, fares, OTPs and timers use tabular (fixed-width) numbers. Currency is always shown as ₹ with Indian number formatting (₹1,420, ₹35,000).

LAYOUT
- Frame: 390 × 844 (Android phone), with a status bar
- 8pt spacing grid (4, 8, 12, 16, 24, 32). Side padding 16px.
- Corner radius: 12px cards and inputs, 16px bottom sheets, full-round buttons and chips
- Shadows: soft only (y 2, blur 8, navy at 8%)
- Minimum tap target 48 × 48. Icons: rounded outline style (Material Symbols Rounded), 24px.

COMPONENTS (show each one on the board, with its states)
- Buttons: Primary (coral-600 fill, white text, 52px tall, full width), Secondary (navy-900 outline), Text button, Danger, Disabled, Loading (with spinner)
- Swipe-to-confirm button (driver app: "Swipe to start ride")
- Inputs: phone input with +91 prefix, text field, search field with a location icon, a 4-box OTP input and a 6-box OTP input; show focused and error states
- Location row: dot or pin icon + title + subtitle address; show the connected pickup → drop pair with a dotted line
- Vehicle option card: vehicle illustration, name, ETA, seats or capacity, fare, and a "Lowest" or "Fastest" badge; show selected and unselected
- Chips: filter chip, choice chip (selected / unselected), status pill (Online, Offline, Active, Grace, Expired, Pending, Verified, Rejected)
- Bottom sheet over a map (peek, half and full heights), with a drag handle
- Driver info card: photo, name, rating, vehicle model, number plate in an Indian plate style (e.g. "TN 37 AB 4521"), and call and chat buttons
- Fare breakdown table
- Banners: info (navy), warning (amber), success (green), error (red), with an icon and an optional action
- Top app bar and back button; bottom navigation (4 items)
- List tile, divider, avatar, rating stars (display and input)
- Toast or snackbar, dialog, full-screen modal
- A small "0% commission" badge (coral-50 background, coral-600 text), used across the driver app
- Illustrations: flat, friendly, 2–3 colours from the palette, used for onboarding, empty states and success screens

MAP STYLE
Use a muted light-grey map (soft grey roads, pale blue water, light green parks, very few labels) so the coral route and markers stand out. Show real Coimbatore street layouts where possible.

SAMPLE DATA
Always use realistic Coimbatore data, never lorem ipsum:
- Places: Gandhipuram Central Bus Stand, Brookefields Mall, RS Puram, Peelamedu, PSG Tech, Coimbatore Junction, Coimbatore International Airport, Tidel Park, Race Course, Saibaba Colony, Prozone Mall (Saravanampatti), Ukkadam, Town Hall, Singanallur
- Passenger: Priya Raman, +91 98765 43210
- Drivers: Karthik S (bike, Honda Activa, TN 37 AB 4521, 4.8★), Murugan P (auto, Bajaj RE, TN 38 C 7810, 4.7★), Arun Kumar (cab, Maruti Dzire, TN 66 D 3302, 4.9★), Selvam R (mini truck, Tata Ace, TN 37 F 9914, 4.6★)
- Fares (Gandhipuram → Brookefields, 4.2 km): Bike ₹38, Auto ₹72, Cab ₹145

Output the design system as a single, well-organised board with labelled sections: Brand, Colours, Typography, Spacing and radius, Components, Map markers, Illustrations.
```

---

## PART 2: Passenger app, sign-in and booking a ride

```
Using the Rido design system from before, design the following PASSENGER APP screens. Label each frame with its ID and name (e.g. "P-01 Splash"). Use realistic Coimbatore sample data.

Passenger bottom navigation (on main screens): Ride · Parcel · Activity · Account

P-01 Splash
- Coral-500 full background, white "rido" wordmark in the centre, and the small tagline "Fair rides. Full fare to your driver." near the bottom.

P-02 Onboarding (3 slides in one frame, or 3 frames)
- Slide 1: "Lower fares, every ride". Illustration of a bike taxi in a city street.
- Slide 2: "Your driver keeps 100%". Illustration of a smiling driver; small caption: "Rido takes 0% commission."
- Slide 3: "Rides and parcels in one app". Illustration of a bike and a small delivery truck.
- Page dots, "Skip" at the top right, and a primary "Get started" button on the last slide.

P-03 Phone number
- Title "Enter your mobile number", subtitle "We'll send you a 6-digit OTP".
- Phone input with a +91 prefix (filled: 98765 43210), primary "Send OTP" button.
- Small text at the bottom: "By continuing, you agree to our Terms & Privacy Policy" with links.

P-04 OTP verification
- Title "Verify OTP", "Sent to +91 98765 43210" with an "Edit" link.
- 6-box OTP input (filled 4 8 2 9 1 _), "Resend OTP in 0:24" countdown, and a primary "Verify" button.

P-05 Profile setup (first time only)
- "What should we call you?" Name field (Priya Raman), optional email, gender selection (Female / Male / Prefer not to say, used for the women-driver preference), "Continue".

P-06 Location permission
- Illustration of a map pin, "Allow location access", one line explaining why, primary "Allow" and text button "Enter location manually".

P-07 Home (Ride tab)
- Full-screen muted map centred on the user's location (Gandhipuram), with 4–5 small navy bike, auto and car icons nearby.
- Top: avatar on the left, "Good afternoon, Priya" and an SOS shortcut icon on the right.
- Bottom sheet (half height):
  - Large search field: "Where are you going?"
  - Saved places row: Home (Saibaba Colony), Work (Tidel Park), + Add
  - Recent destinations list (2 rows): Brookefields Mall · Coimbatore Junction
  - A small promo banner card: "Your driver keeps 100% of your fare".
- Bottom nav with Ride active.

P-08 Search pickup and drop
- Top: connected pickup field ("Current location, Gandhipuram") and drop field (focused, typing "Brook").
- Suggestions list with location icons: Brookefields Mall (Krishnasamy Road), Brookefields Plaza, Brookebond Road.
- Buttons "Set on map" and "Add stop" (disabled with a "Coming soon" hint).

P-09 Pin on map (fine-tune location)
- Full map with a fixed centre pin, an address card at the bottom ("Brookefields Mall, Krishnasamy Rd, RS Puram") and a "Confirm drop" button.

P-10 Choose vehicle
- Map on top showing the coral route from Gandhipuram to Brookefields with pickup and drop markers, and a "4.2 km · 14 min" label.
- Bottom sheet with vehicle cards:
  - Bike: 2 min away · 1 seat · ₹38 · badge "Lowest"
  - Auto: 4 min away · 3 seats · ₹72
  - Cab: 6 min away · 4 seats · ₹145 · badge "Comfort"
- Bike card selected (coral-50 background, coral-100 border).
- Row: payment "Cash / UPI to driver" (with a small info icon: "Pay your driver directly"), and a "Prefer women driver" toggle (off).
- Primary button "Book Bike · ₹38".

P-11 Fare details (bottom sheet on top of P-10)
- Breakdown: Base fare ₹12 · Distance 4.2 km × ₹5 = ₹21 · Time charge ₹2 · Subtotal ₹35 · Peak time (1.1x) +₹3 · Total ₹38.
- Notes: "Your fare is locked at booking." "Surge is capped at 1.5x and goes to your driver."

P-12 Finding your driver
- Map with an animated coral pulse ring around the pickup point.
- Bottom sheet: "Finding a nearby bike…" with a progress bar, trip summary (pickup → drop, ₹38) and a text button "Cancel request".
```

---

## PART 3: Passenger app, during and after the ride, account

```
Continue with the Rido design system. Design these PASSENGER APP screens, labelled with IDs.

P-13 Driver assigned / arriving
- Map: driver bike icon approaching the pickup along a coral route, with an ETA bubble "3 min".
- Bottom sheet:
  - "Karthik is on the way" · "Arriving in 3 min"
  - Driver info card: photo, Karthik S, 4.8★ (1,240 rides), Honda Activa · Grey, plate "TN 37 AB 4521"
  - A large "Ride OTP: 4 8 2 9" box (coral-50 background, big tabular digits), with the caption "Share this with your driver to start the ride"
  - Action row: Call (masked), Chat, Share trip, Cancel
  - Trip summary: pickup → drop, ₹38, Cash / UPI.

P-14 Chat with driver
- Simple chat screen with the driver's name and "Number hidden for privacy".
- Quick replies: "I'm at the pickup point", "Please come fast", "I'm wearing a blue shirt", "Where are you?"
- 3–4 sample messages.

P-15 Driver has arrived
- Banner: "Karthik has arrived at your pickup". OTP box emphasised. Small "Waiting time starts in 2:45" timer.

P-16 Ride in progress
- Map with a coral route to the drop, a moving bike icon and an "Arriving at 3:42 PM · 9 min" chip.
- Bottom sheet (collapsed): driver name and plate, drop address, ₹38.
- Big red "SOS" button floating on the map (bottom right, above the sheet).
- "Share trip" button in the top bar.

P-17 SOS screen
- Full-screen modal with a red header "Emergency help".
- Big "Call 112" button (sos red).
- "Alert my emergency contacts": list of 2 contacts (Amma, Ravi), each with a status "Live location sent ✓".
- "Rido safety team has been notified" (green check).
- Trip details: driver, plate, current location.
- "I'm safe" secondary button at the bottom.

P-18 Share trip
- Bottom sheet: a live tracking link preview card, share buttons (WhatsApp, SMS, Copy link) and the note "They can see your live location until the ride ends."

P-19 Ride completed / pay driver
- Success illustration, "You've arrived!" and a large "₹38" with "Pay Karthik directly: Cash or UPI".
- Card: "Scan Karthik's UPI QR on his phone, or pay cash".
- Trip summary: 4.2 km · 14 min · Gandhipuram → Brookefields.
- Line: "Karthik keeps the full ₹38. Rido takes 0%."
- Primary button "Done, rate your ride".

P-20 Rate driver
- Driver photo and name, a large 5-star input (4 filled), and tag chips (Safe driving, On time, Polite, Clean vehicle, Knew the route); comment field; "Submit". "Skip" text button.

P-21 Activity (ride and parcel history)
- Tabs: All · Rides · Parcels.
- List cards: date and time, vehicle icon, pickup → drop, fare, status pill (Completed / Cancelled).
  Sample: "Today, 3:28 PM · Bike · Gandhipuram → Brookefields · ₹38 · Completed"; "Yesterday · Auto · RS Puram → Coimbatore Junction · ₹64 · Completed"; "22 Sep · Parcel (Bike) · Peelamedu → Race Course · ₹49 · Delivered"; "20 Sep · Cab · Home → Airport · ₹310 · Cancelled".

P-22 Trip details
- Small static map with the route, date and time, driver card, fare breakdown, trip ID, "Get help with this trip" and "Download receipt".

P-23 Account
- Header: avatar, Priya Raman, +91 98765 43210, "Edit".
- List: Saved places, Emergency contacts, Safety preferences (women-driver preference, auto-share trips), Help & support, Terms & privacy, About Rido, Log out.
- Bottom nav with Account active.

P-24 Emergency contacts
- List of up to 3 contacts with a relation label, "Add contact" button, and a toggle "Auto-share every trip with these contacts".

P-25 Help & support
- Search field, topic list (Lost item, Driver behaviour, Fare issue, Parcel issue, App problem, Safety concern), "Recent trip" shortcut card, "Raise a ticket" button, "Chat on WhatsApp" secondary button, and "My tickets" with one open ticket showing an "In progress" status.
```

---

## PART 4: Passenger app, Send Parcel

```
Continue with the Rido design system. Design the SEND PARCEL flow inside the passenger app. It lives in the "Parcel" tab of the bottom navigation. Label frames with IDs.

Parcel vehicles:
- Bike: up to 10 kg
- 3-wheeler (goods auto): up to 500 kg
- Mini truck (Tata Ace): up to 750 kg
- Pickup (Bolero): up to 1,500 kg
- Truck 14ft / 17ft: up to 4,000 kg
Use a small, clear illustration for each.

PP-01 Parcel home
- Header "Send anything, anywhere in Coimbatore".
- Two stacked input cards: "Pickup from" (Peelamedu, Avinashi Road) and "Deliver to" (tap to add).
- Vehicle category grid (2 columns) with an illustration, name and capacity for each vehicle.
- Info strip: "Your driver keeps 100% of the fare".
- Recent parcels list (1 item).
- Bottom nav with Parcel active.

PP-02 Pickup details
- Map pin location card plus fields: sender name (Priya Raman), sender phone, building / floor / landmark. "Confirm pickup".

PP-03 Drop / receiver details
- Drop address (Race Course, Coimbatore), receiver name (Meena Ravi), receiver phone (+91 94433 21098) with a "Choose from contacts" icon, landmark, "Confirm drop".

PP-04 Parcel details
- "What are you sending?" chips: Documents, Food, Clothes / Textiles, Electronics, Household, Furniture, Other (Clothes selected).
- Weight choice chips: Under 5 kg · 5–20 kg · 20–100 kg · 100–500 kg · 500 kg+ (5–20 kg selected).
- Optional "Add photo of parcel" tile.
- Checkbox (must be ticked): "My parcel has no prohibited items". Link "See list" opens PP-05.

PP-05 Prohibited items (bottom sheet)
- Icon list: cash and jewellery, alcohol, drugs and illegal items, weapons, hazardous or flammable goods, live animals.
- "Got it" button.

PP-06 Choose goods vehicle and review
- Map with the route Peelamedu → Race Course (6.8 km).
- Vehicle cards (only the ones that fit the chosen weight are enabled; the rest greyed out with "Too small for 5–20 kg"):
  - Bike: ₹49 · 3 min (disabled: over 10 kg, still shown greyed)
  - 3-wheeler: ₹180 · 6 min · "Best value" (selected)
  - Mini truck: ₹420 · 9 min
- "Who pays the driver?" segmented control: Sender (me) / Receiver.
- Fare breakdown link, note "Loading and unloading is done by the sender and receiver."
- Liability note (small, navy-500): "Rido connects you with drivers and is not liable for lost or damaged goods."
- Primary button "Book 3-wheeler · ₹180".

PP-07 Finding a goods driver
- Same pattern as ride search: pulse animation, "Finding a nearby 3-wheeler…", summary card, "Cancel".

PP-08 Driver assigned / picking up
- Driver card: Selvam R, 4.6★, Bajaj Maxima Cargo, plate "TN 37 F 9914".
- Status stepper: Driver assigned ● → At pickup ○ → Picked up ○ → Delivered ○
- Box: "Delivery OTP: 7 1 5 3. Sent to Meena by SMS. The driver needs it at drop-off."
- Call / Chat / Share tracking / Cancel.

PP-09 Parcel in transit
- Map with live tracking to the drop, stepper at "Picked up", ETA "Arriving 4:10 PM", "Share tracking with receiver" button, SOS not shown (goods only). Instead, "Help" icon in the top bar.

PP-10 Parcel delivered
- Success illustration, "Delivered to Meena Ravi at 4:08 PM", "Verified with OTP ✓".
- "Pay ₹180 to Selvam: Cash or UPI" (or "Receiver will pay ₹180" if Receiver was chosen).
- Rate the driver (stars) and "Done".
```

---

## PART 5: Driver app, sign-up, KYC and subscription

```
Continue with the Rido design system, now for the RIDO DRIVER app (a separate app). Its look differs slightly: the top area of the home screen uses navy-900, with coral for main actions, so drivers can tell it apart from the passenger app at a glance. Label frames "D-xx".

Drivers do ONE type of job: either rides (passengers) or deliveries (goods), chosen at sign-up.

Subscription plans:
- Bike ₹2,000/month
- Auto ₹2,000/month
- Cab ₹2,000/month
- 3-wheeler goods ₹3,000/month
- Mini truck ₹4,000/month
- Pickup and trucks: price to be decided, show "₹—" with "Contact us"
- First month free for every plan. 2-day grace period after a missed payment.

D-01 Splash
- Navy-900 background, white "rido" wordmark and a coral "DRIVER" tag.

D-02 Welcome
- Illustration of a happy driver, headline "Keep 100% of what you earn", 3 benefit rows (0% commission on every ride · One flat monthly plan · First month free), primary "Join as a driver", text "Already registered? Log in".

D-03 Phone and OTP
- Same pattern as the passenger app: +91 phone, then 6-digit OTP, combined into one frame showing both steps side by side or as 2 frames.

D-04 Choose work type
- Two large selectable cards: "Rides: carry passengers" (bike, auto, cab illustrations) and "Deliveries: carry goods" (bike, 3-wheeler, truck illustrations). "Rides" selected. "Continue".

D-05 Choose vehicle
- Grid of vehicle types for the chosen work type (Rides: Bike, Auto, Cab), each showing the monthly plan price and a "1st month free" tag. Bike selected.

D-06 Personal details
- Profile photo upload circle, full name (Karthik S), date of birth, gender, city (Coimbatore, locked), emergency contact, UPI ID for receiving fares (karthik@okaxis).

D-07 Documents / KYC checklist
- Progress bar "3 of 5 done".
- List rows with status pills:
  - Driving licence: Verified ✓ (green)
  - Aadhaar: Verified ✓
  - Vehicle RC: Uploaded, under review (amber)
  - Vehicle insurance: Upload (button)
  - Police verification certificate: Upload (button)
- Tip: "Clear photos get approved faster".

D-08 Upload document (camera flow)
- Camera frame with a rectangle guide for the card, labels "Front side" and "Back side", "Retake" and "Use photo" buttons, and a sample captured image of a driving licence (blurred personal details).

D-09 Selfie verification
- Circular face guide, instruction "Look straight, remove helmet or cap", "Take selfie" button; small note "We match this with your documents to keep riders safe."

D-10 Application under review
- Illustration of a clock or document, "We're verifying your documents", "Usually within 24 hours", checklist summary, "Contact support" text button.

D-11 Choose plan and start free trial
- Plan card: "Bike plan: ₹2,000 / month", "First month FREE", benefits list (Unlimited rides, keep 100% of fares, 0% commission, cancel anytime).
- Comparison line: "On a commission app, ₹35,000 in fares costs you ~₹10,500. On Rido: ₹2,000."
- "Set up UPI Autopay" primary button, with the caption "₹0 today. ₹2,000 auto-debits on 24 Oct 2026. Cancel anytime."

D-12 UPI Autopay setup and success
- Frame 1: list of UPI apps (GPay, PhonePe, Paytm, BHIM) to approve the mandate, and a summary box: Rido Driver Plan · ₹2,000 monthly · starts 24 Oct 2026.
- Frame 2: success screen "You're all set!", "Free trial active: 30 days left", button "Go online".
```

---

## PART 6: Driver app, home, rides, deliveries, earnings

```
Continue with the Rido design system for the RIDO DRIVER app. Label frames "D-xx".

Driver bottom navigation: Home · Earnings · Plan · Account

D-13 Home (offline)
- Navy-900 header: avatar, "Hi, Karthik", status pill "Offline" (grey), and a "0% commission" badge.
- Muted map below, showing the driver's location.
- Today's summary card: "₹0 today · 0 rides".
- Big coral "GO ONLINE" button at the bottom (swipe-to-confirm or large round button).
- Small subscription strip: "Plan active till 24 Oct 2026".

D-14 Home (online, waiting for rides)
- Header status pill "Online" (green), with a pulsing ring around the driver marker.
- Optional "busy area" soft coral zones on the map, labelled "High demand: Gandhipuram".
- Today card: "You kept ₹1,420 today · 14 rides · ₹0 commission".
- "Go offline" secondary button.

D-15 Incoming ride request
- Full-screen takeover with a strong coral top area.
- Circular countdown ring "15" around the fare, "₹38", "Bike ride".
- Pickup: "Gandhipuram Central Bus Stand · 0.8 km away · 3 min"; Drop: "Brookefields Mall · 4.2 km trip".
- Passenger: "Priya · 4.9★".
- Big "Accept" (coral, bottom) and a small "Decline" text button.

D-16 Navigate to pickup
- Map with the route to the pickup, a "Navigate" button (opens Google Maps), passenger name, Call / Chat buttons, pickup address card, "Arrived at pickup" swipe button, and "Cancel ride" in an overflow menu.

D-17 Enter ride OTP
- "Ask Priya for the 4-digit OTP", 4-box OTP input (filled 4 8 2 9), "Start ride" primary button; error state hint "Wrong OTP, please try again" shown in small text under the design.

D-18 Ride in progress
- Map with route to the drop, ETA, drop address, SOS button (driver side), and a "Swipe to end ride" button.

D-19 Collect payment
- Big "Collect ₹38" and "Cash or UPI".
- Large UPI QR code (driver's own UPI ID karthik@okaxis) for the passenger to scan.
- Two buttons: "Received cash" / "Received on UPI".
- Line: "You keep 100% of this fare".
- Then rate the passenger (stars, small).

D-20 Incoming delivery request (for delivery drivers)
- Same layout as D-15 but for goods: "₹180 · 3-wheeler delivery", parcel type "Clothes / Textiles · 5–20 kg", pickup Peelamedu (1.1 km away), drop Race Course (6.8 km), "Paid by: Receiver" tag, Accept / Decline, 15s countdown.

D-21 Delivery in progress
- Stepper: Go to pickup → Picked up → Go to drop → Delivered.
- Current step "Go to drop" with map, receiver name "Meena Ravi", call receiver button, parcel info, and a "Reached drop location" swipe button.

D-22 Complete delivery with OTP
- "Ask Meena for the delivery OTP", 4-box OTP (7 1 5 3), optional "Take photo of delivered parcel", "Complete delivery"; then "Collect ₹180 from receiver" with UPI QR (same pattern as D-19).

D-23 Earnings
- Tabs: Today · Week · Month.
- Big number "₹8,940 this week" and "You kept 100%. Commission saved: ~₹2,680."
- Simple bar chart (Mon–Sun) in coral bars.
- Stats: rides 86 · online hours 42h · rating 4.8★.
- Trip list (time, route, fare, Cash / UPI tag).

D-24 Plan (subscription)
- Status card: "Bike plan · Active", "Next auto-debit ₹2,000 on 24 Oct 2026", "UPI Autopay: GPay ✓".
- Payment history list (Sep 2026 · Free trial, Aug 2026 · ₹2,000 · Paid).
- Buttons: "Change UPI app", "Pause plan", "Cancel plan" (text, red).
- Savings callout: "Since joining, you saved ~₹18,400 in commission".

D-25 Plan in grace period / expired (2 frames)
- Grace: amber banner on home "Payment failed. 2 days left to renew. You can still go online." with a "Pay ₹2,000 now" button.
- Expired: home screen with the GO ONLINE button disabled, red banner "Plan expired. Renew to go online again", primary "Renew ₹2,000".

D-26 Driver account
- Profile header (photo, Karthik S, 4.8★, Bike · TN 37 AB 4521), list: Documents, Vehicle details, UPI ID, Emergency contact, Refer a driver ("Get 7 free days for every driver who joins"), Help & support, Terms, Log out.
```

---

## PART 7: Empty, loading and error states

```
Continue with the Rido design system. Design these STATE screens for both apps. Use friendly flat illustrations in the brand palette, a short title, one line of explanation and one clear action. Label frames "S-xx".

PASSENGER APP
S-01 No drivers nearby: map with an empty search ring, "No bikes nearby right now", "Try Auto or Cab, or try again in a few minutes", buttons "Try Auto · ₹72" and "Retry".
S-02 Driver cancelled: "Karthik had to cancel. We're finding you another driver", auto-searching progress bar.
S-03 Ride cancelled by you (confirmation dialog): reasons list (Driver too far, Changed my plan, Booked by mistake, Other), "Cancel ride" (red) and "Keep ride".
S-04 No internet: "You're offline", "Check your connection and try again", "Retry".
S-05 Location permission denied: "Location is off", "Rido needs your location to find nearby drivers", "Open settings".
S-06 Empty activity: "No trips yet", "Your rides and parcels will show here", "Book a ride".
S-07 Loading skeletons: Home bottom sheet and Activity list in skeleton loading state (grey shimmer blocks).
S-08 Service not available: pin outside Coimbatore, "Rido isn't in this area yet", "We're live across Coimbatore. More cities coming soon."

DRIVER APP
S-09 KYC rejected: red status on "Vehicle RC", reason "Photo is blurry. Please upload a clearer image", "Re-upload".
S-10 Account blocked (temporary): "Your account is on hold", reason "Multiple ride complaints under review", "Contact support".
S-11 Missed ride request: toast or banner "You missed a ride request. Stay alert to get more rides."
S-12 No ride requests yet (online, quiet): "Waiting for rides…", tip "Busy areas right now: Gandhipuram, Peelamedu", with the soft demand zones on the map.
S-13 Selfie check required before going online: "Quick selfie check", "We verify it's you to keep riders safe", "Take selfie".
S-14 Autopay payment failed: amber dialog "Your ₹2,000 payment didn't go through", "Retry with another UPI app", "Pay later (2 days left)".
S-15 Empty earnings: "No earnings yet this week", "Go online to start earning. You keep 100%."
S-16 GPS weak / location off while online: red top banner "GPS signal lost. Riders can't see you", "Fix now".
```

---

## Handover notes for converting to Flutter

- Keep the frame IDs (P-xx, PP-xx, D-xx, S-xx) as Flutter screen or route names, e.g. `P10ChooseVehicleScreen` or route `/ride/choose-vehicle`.
- Put the Part 1 colours into `ColorScheme` + `ThemeExtension` and the type scale into `TextTheme`, using `google_fonts` for Poppins and Inter.
- Shared components (vehicle card, location row, OTP input, driver card, banners, swipe button) go in a shared Dart package, since both apps use them.
- Map: `flutter_map` or `maplibre_gl` with a light-grey style, matching the plan's open-source map stack.
