# Zero-Commission Ride App: Plan v1

Coimbatore first · Bike, auto and cab · Drivers pay ₹2,000/month and keep 100% of every fare · Solo build, bootstrapped

---

## 1. Risks to settle before writing code

| # | Issue | Why it matters | What to do |
|---|-------|----------------|------------|
| 1 | **Private (white-plate) vehicles** | Carrying paying passengers in a private vehicle needs a permit under the Motor Vehicles Act. The 2025 update to the central aggregator guidelines lets states allow private bikes, but each state decides. Tamil Nadu's position has changed more than once, and bike taxi drivers have had vehicles seized there. | Pay a local transport lawyer for one hour (about ₹5–10k) before launch. For cabs and autos, require commercial (yellow) plates from day 1. Build a `plate_type` field so you can switch rules without changing code. |
| 2 | **Aggregator licence (your Q19)** | Yes, it's required. Section 93 of the Motor Vehicles Act (amended 2019) says an aggregator needs a licence from the state. You can run a small pilot with 10 known drivers first, but get the licence before any public launch. | Register a company (Pvt Ltd or LLP), then apply to the TN Transport Department. Ask the lawyer about current TN rules at the same time. |
| 3 | **No passenger insurance** | If there's an accident, the platform gets named in the case. Aggregator licences also usually require insurance. | Add per-ride accident cover later through an insurance partner (such as Acko or Digit). It costs about ₹1–2 per ride. Plan for it in version 1.1. |
| 4 | **"Everything Rapido has" in version 1** | Rapido has hundreds of engineers. Building every feature alone before launch could take 9 months or more. | Build the version 1 list in §4 (about 3–4 months). Everything else comes after launch. |
| 5 | **10 drivers across all of Coimbatore** | 10 drivers spread over the whole city means 15-minute pickups, and passengers leave after one bad experience. | Keep the whole city open for booking, but concentrate the pilot drivers around 2–3 busy areas (for example Gandhipuram, Peelamedu/Avinashi Road, RS Puram). |
| 6 | **Surge pricing vs "cheaper fares"** | Surge pricing works against your main promise. | Cap surge at 1.3–1.5x. All surge money goes to the driver, which is a good marketing line: "surge goes to your driver, not to us". |

You're right that **drivers taking passengers off the app doesn't hurt this model**, because you don't take a cut of rides. The real risk is **several drivers sharing one paid account**. The fix is in §5.

---

## 2. Business model

- **Driver subscription:** ₹2,000/month, the same for all vehicle types at launch. (Open question: cab drivers earn more, so a later price list could be bike ₹1,500 / auto ₹2,000 / cab ₹3,000.)
- **First month free.** Then UPI autopay through Razorpay Subscriptions. A ₹2,000 autopay mandate doesn't need extra approval from the driver each month.
- **Lifecycle:** `TRIAL (30d) → ACTIVE → GRACE (2d) → EXPIRED`. Drivers can't go online when their subscription is `EXPIRED`. Rides already in progress always finish.
- **Passengers** pay nothing to the platform. They pay the driver directly by cash or UPI.
- **GST:** once revenue passes ₹20L/year you have to register for GST and charge 18%. Decide now whether ₹2,000 includes GST (you receive ₹1,695) or GST is added on top (driver pays ₹2,360).

### Rough numbers

| Item | Monthly cost |
|------|-------------|
| AWS (small setup, see §6) | ₹6–12k |
| Maps (self-hosted routing + a cheap place-search API) | ₹0–5k at pilot scale |
| SMS OTP | ~₹0.2 per login |
| Driver KYC (one-time, per driver) | ₹30–100 |
| Razorpay fee | ~2% (about ₹40 per ₹2,000) |
| Masked calling (Exotel or similar) | ~₹0.5–1 per call |

**Break-even is about 10–15 paying drivers** for server costs. With 200 drivers, revenue is about ₹4L/month. Almost all of the cost is your own time.

---

## 3. Fares

Fixed per-km rates with a capped multiplier. Every number is set from the admin panel, per vehicle type.

```
fare = max(min_fare, base + per_km × km + per_min × minutes) × multiplier
multiplier = min(cap, time_of_day × demand_zone × festival × weather)
```

- **Time of day:** peak hours such as 8–10am and 5–8pm → 1.1–1.2
- **Demand zone:** open requests ÷ free drivers in an area, recalculated every minute → 1.0–1.3
- **Festival calendar:** dates the admin enters (Pongal, Deepavali, Karthigai Deepam) → 1.1–1.2
- **Weather:** rain, from a weather API or switched on by the admin → 1.1
- **Cap:** 1.5x overall.
- The fare shown before booking is locked in. The final fare only changes if the route changes a lot, for example the passenger adds a stop.
- Set base rates about 10–15% below Rapido's in Coimbatore. Check their prices by hand before launch.

---

## 4. Version 1 scope (three apps plus admin panel)

### Passenger app (Flutter, Android)
- Phone number and OTP login
- Pickup and drop search, pick location on a map, saved places
- Choose vehicle type, see fare estimate and pickup time
- Book, see the driver's details, live tracking, **OTP to start the ride**
- Masked call to the driver, preset chat messages
- **SOS button**, share trip link, emergency contacts
- Option to request women drivers only (when available)
- Rate the ride, ride history, raise a complaint

### Driver app (Flutter, Android, separate app)
- OTP login, then **KYC** (driving licence, RC, Aadhaar through a third-party KYC service, selfie check)
- Subscription screen: trial, pay, autopay status, days left
- Online/offline switch, background location
- Incoming ride request: accept or decline within 15 seconds
- Navigate to pickup, enter OTP, navigate to drop, end ride, show fare
- Earnings summary (only for the driver's own tracking), ratings, SOS

### Admin panel (Next.js)
- Approve or reject drivers and review KYC documents
- Subscription list and payment status, give extra days by hand
- Live map of online drivers and ongoing rides
- Fare settings per vehicle type, festival calendar, surge cap, service area
- **SOS alerts dashboard** with live location
- Complaints and support tickets, block or unblock users

### Small web page (Next.js, same deployment as admin)
- The trip-share link (`/t/{token}`) that emergency contacts open. They won't have the app.

### After version 1 (1.1 and later)
In-app payments, per-ride insurance, scheduled rides, referral codes, Tamil language, iOS, daily or weekly plans, driver incentives, multiple stops, rentals.

---

## 5. Safety and trust

- **OTP ride start:** a 4-digit code on the passenger's screen that the driver types in.
- **SOS:** one tap calls 112, sends an SMS with a live location link to emergency contacts, and triggers an alert with sound on the admin dashboard.
- **Route deviation alert:** if the driver goes more than 500m off the expected route for over 2 minutes, both people get a "Is everything OK?" message and admin is notified.
- **Masked numbers:** neither side sees the other's real phone number.
- **Stop account sharing:** each driver account is locked to one device. The driver takes a **random selfie check** when going online (at most once a day), matched against the KYC photo.
- **Ratings:** drivers under 4.0 over their last 50 rides get reviewed. Passengers can be rated too.
- **Support (your Q34):** start with in-app tickets plus one WhatsApp Business number that you answer yourself. Once you reach about 300 drivers, hire one support person from the drivers' own community.

---

## 6. Technical architecture

```
Flutter passenger app ─┐                         ┌─ PostgreSQL + PostGIS (RDS)
Flutter driver app ────┼─ HTTPS + WebSocket ─→ NestJS API ─┼─ Redis (ElastiCache): GEO, locks, pub/sub, BullMQ
Next.js admin ─────────┘      (ALB)             (ECS)     ├─ S3 (KYC docs, private)
                                                          ├─ OSRM (self-hosted routing on OpenStreetMap)
                                                          └─ External: Razorpay, KYC API, MSG91 SMS, FCM push, Exotel
```

**Start with a single NestJS app split into modules, not microservices.** You're one person, and a single app is easier to build and run. Modules:
`auth` · `users` · `drivers` · `kyc` · `subscriptions` · `vehicles` · `pricing` · `rides` · `matching` · `location` · `realtime` (Socket.IO gateway) · `safety` · `support` · `notifications` · `admin`

### Key design decisions
- **Live driver locations:** the driver app sends a location every 4–5 seconds while online. Store it in Redis with `GEOADD drivers:{vehicleType}` and use a 30-second expiry so a driver who drops off disappears. Don't write every location update to Postgres. Only save sampled points during trips, for the route record and disputes.
- **Matching:** use `GEOSEARCH` within 2km, and widen to 4km then 6km if nobody is found. Keep only drivers who are free, have an active subscription and the right vehicle type. Send the request to the **nearest 3 at once**; the first to accept wins. Use a Redis `SET NX` lock on `ride:{id}` so only one driver can accept each ride. A BullMQ job ends the search after 60 seconds if nobody accepts.
- **Realtime updates:** Socket.IO with the Redis adapter, so it keeps working when you run more than one copy of the backend. Use FCM push as a backup when the app is in the background.
- **Ride states:** `REQUESTED → ACCEPTED → ARRIVED → STARTED → COMPLETED`, plus `CANCELLED_BY_RIDER / CANCELLED_BY_DRIVER / NO_DRIVER`. Enforce this in one service and store every state change as an event.
- **Maps (your Q38):** Google Maps gets expensive at scale. Instead:
  - **Routing, distance and pickup time:** self-hosted **OSRM** on Tamil Nadu map data from OpenStreetMap, on one small EC2 instance. It's free, fast, and you have the DevOps skills to run it.
  - **Place search:** Ola Maps or MapMyIndia (Mappls), both of which have India-focused free tiers. Keep Google Places as a fallback and cache results.
  - **Map display in the app:** `flutter_map` or MapLibre with OpenStreetMap tiles (or Ola or Mappls tiles).
  - Put this behind a `MapsProvider` interface so you can switch providers later.
- **Subscriptions:** Razorpay Subscriptions with UPI autopay. Webhooks (`subscription.charged`, `subscription.halted`, etc.) update the subscription status. A daily BullMQ job handles the change from grace period to expired and sends reminder pushes at 3 days, 1 day and at expiry.
- **Background location on Android:** needs a foreground service with a visible notification. The Play Store also requires a location permission declaration and a video showing why you need it. Allow 1–2 weeks for Play Store review.

### AWS setup (ap-south-1, Mumbai)
- Pilot: **one EC2 instance (t4g.medium) running Docker Compose** for NestJS, Redis and OSRM, plus RDS Postgres db.t4g.micro and S3. About ₹5–6k/month.
- Growth: move to ECS Fargate behind an ALB, ElastiCache Redis, RDS Multi-AZ, and CloudFront for the admin panel. Use Terraform from the start so the move is easy.
- CI/CD: GitHub Actions → ECR → deploy. Sentry for errors, CloudWatch for logs.

### Folder layout
```
/apps/passenger   (Flutter)
/apps/driver      (Flutter)
/packages/shared  (Dart: models, API client, map widgets)
/backend          (NestJS)
/admin            (Next.js; admin panel + trip-share page)
/infra            (Terraform, docker-compose)
```

---

## 7. Timeline (solo, full-time)

| Weeks | What |
|-------|------|
| 0–2 | Lawyer consult, company registration, app name, Razorpay and KYC vendor accounts, get OSRM running, database schema |
| 3–6 | Backend: auth, drivers, KYC, subscriptions, pricing, rides, matching, realtime |
| 5–10 | Driver app and passenger app (build in parallel with the backend, using the shared package) |
| 9–11 | Admin panel, SOS, trip-share page, masked calling |
| 11–12 | Test with your 10 drivers and 20–30 friends as passengers, in 2–3 areas |
| 13–14 | Play Store submission, fixes, soft launch |
| 15+ | Sign up more drivers (target 100 in the first 60 days), then open to the public |

---

## 8. Open decisions

1. App name and brand
2. Same ₹2,000 for bike, auto and cab, or different prices?
3. ₹2,000 including GST or plus GST?
4. What the lawyer says about white-plate bikes in TN
5. KYC vendor (compare pricing: IDfy, HyperVerge, Surepass, Signzy)
6. Base fare, per-km and per-minute rates per vehicle type (after checking Rapido's Coimbatore prices)
7. Pilot areas (2–3 areas)
