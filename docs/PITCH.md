---
marp: true
theme: default
paginate: true
size: 16:9
title: Zero-Commission Ride Platform, Investor Presentation
---

<!-- _paginate: false -->

# Rido
## Zero-commission rides for Coimbatore

Bike · Auto · Cab

Drivers pay one flat monthly fee and keep **100% of every fare**.
Passengers pay **lower fares**.

Siva Krishna · sivakrishnacoc@gmail.com · +91 78100 02624

---

## The problem

**Drivers lose 30–40% of every fare to commission** (what Coimbatore drivers told us about their current platforms).

| On a ₹100 ride | Today |
|---|---|
| Passenger pays | ₹100 |
| Driver receives | ₹60–70 |
| Platform takes | ₹30–40 |

- Drivers earn less, so they cancel short or low-value rides and ask passengers for extra cash
- Passengers pay more, and platforms raise fares during peak hours to protect their cut
- Drivers are unhappy and don't stay, so the service gets worse for passengers

---

## Our solution

**A ride app that charges drivers a subscription, not a commission.**

- Drivers pay **₹2,000/month**, whether they do 10 rides or 500
- **The driver keeps 100% of every fare**, including any surge
- The driver has no reason to overcharge, so **fares can be lower**
- Passengers pay the driver directly (cash or UPI). The platform never handles ride money.

> Our revenue depends on how many drivers subscribe, not on how much each ride costs.

---

## What a driver saves

A full-time driver earning **₹35,000/month** in fares (about ₹1,350/day × 26 days):

| | Commission platform (30%) | **Us** |
|---|---|---|
| Paid to platform | ₹10,500 | **₹2,000** |
| Driver keeps | ₹24,500 | **₹33,000** |
| **Extra income** | | **+₹8,500/month (+35%)** |

The more a driver drives, the more they save. The drivers who drive most are also the ones most worth winning.

---

## What passengers get

- Fares **10–15% below** current platforms in Coimbatore
- Price is **shown and locked before booking**
- Surge is **capped at 1.5x**, and all of it goes to the driver
- Safety as standard: OTP to start the ride, SOS, live trip sharing, masked phone numbers, verified drivers, option to request women drivers only
- Fewer cancellations, because drivers want every ride

---

## Why Coimbatore first

- **~10,000 active Rapido drivers in Coimbatore**. These drivers already work on ride apps and already pay commission, so they're the people we'd sign up first.
- Tamil Nadu's second-largest city, with a large industrial, textile and IT workforce
- Many colleges and a large student population who need cheap daily transport
- Two-wheelers and autos already dominate daily trips
- Big national platforms focus on metros, so a tier-2 city is less contested
- Siva Krishna is based here, knows the drivers and can run operations directly

**Then:** Tiruppur, Erode, Salem, Madurai, Trichy, followed by other tier-2 cities across South India.

---

## Business model

| | |
|---|---|
| **Who pays** | Drivers only |
| **Price** | ₹2,000/month (flat, all vehicle types at launch) |
| **Trial** | First month free |
| **Collection** | UPI autopay through Razorpay Subscriptions |
| **Missed payment** | 2-day grace period, then the driver can't go online |
| **Coming later** | Daily and weekly plans, different prices per vehicle type, per-ride insurance add-on, sponsored placements |

**Why this model is attractive:**
- Monthly recurring revenue we can predict, like a software subscription
- No payment handling or reconciliation for rides
- Revenue grows with the number of drivers, not with fare prices, so cheaper fares don't cost us anything

---

## Revenue scenarios

*Examples to show the scale, not forecasts. Gross revenue, before GST.*

| Paying drivers | Monthly revenue | Annual run-rate |
|---|---|---|
| 100 | ₹2.0 L | ₹24 L |
| 500 | ₹10 L | ₹1.2 Cr |
| 1,000 | ₹20 L | ₹2.4 Cr |
| 3,000 (Coimbatore + 2 cities) | ₹60 L | ₹7.2 Cr |

**Coimbatore alone:** ~10,000 active Rapido drivers × ₹2,000 = **₹2 Cr/month if we signed up every one of them**. Getting just **10% of them (1,000 drivers) = ₹20 L/month**, and that's before counting Uber, Ola and independent auto drivers.

**Cost structure (at pilot scale):**
- Infrastructure: ₹6–12k/month on AWS, with self-hosted maps and routing
- Driver KYC: ₹30–100 per driver, paid once
- Payment gateway: ~2% of the subscription
- **Server costs are covered at ~15 paying drivers**

---

## Competition

| | Commission-based (Uber, Ola, Rapido bike taxi*) | Subscription/zero-commission (Namma Yatri, Rapido auto/cab*) | **Us** |
|---|---|---|---|
| Driver cost | 20–40% of every fare | Daily fee or small per-ride fee | **Flat ₹2,000/month** |
| Passenger fare | High, uncapped surge | Medium | **Low, surge capped at 1.5x** |
| Tier-2 focus | Low | Growing | **Local-first** |
| Cost to run | High | Medium | **Very low (lean, self-hosted)** |

\*Models vary by city and vehicle type.

**What we're betting on:** the subscription model already works (others are proving it). We can win in tier-2 cities by being cheaper, local, and running at a fraction of competitors' costs.

---

## Traction so far

- **10+ Coimbatore drivers** have agreed to join at launch
- ₹2,000/month price **checked with drivers**, who said they'd accept it
- Built in-house by a full-stack developer and DevOps engineer, **so there's no outsourced development cost**
- Product plan, architecture and legal checklist are ready

**Next milestone:** 100 active drivers and 1,000 rides/week within 60 days of launch.

---

## Go-to-market

**Drivers (supply):**
- Start with the 10+ committed drivers, who then refer others (referral bonus = free days)
- Sign-up desks at auto stands, bike taxi hotspots and fuel stations
- First month free, so there's no risk in trying
- Driver WhatsApp groups and word of mouth: "keep what you earn"

**Passengers (demand):**
- Launch in 2–3 busy areas first (e.g. Gandhipuram, Peelamedu / Avinashi Road, RS Puram) so pickups are quick
- College ambassador programme, and promotions at IT parks and offices
- Local Instagram and Tamil influencers, stickers on driver vehicles
- Message: "Same ride, lower fare, and your driver keeps it all"

---

## The product: three apps and an admin panel

**Passenger app (Android):** OTP login · pickup and drop search · fare estimate · book bike, auto or cab · live tracking · OTP ride start · masked call and chat · SOS · trip sharing · ratings · ride history · support

**Driver app (Android):** KYC sign-up · subscription and autopay · online/offline switch · accept or decline rides · navigation · OTP start and end ride · earnings view · SOS

**Admin panel (web):** driver approval and KYC review · subscription management · live map · fare and surge settings · festival calendar · SOS alert dashboard · complaints · block or unblock users

**Trip-share web page:** emergency contacts can follow a ride live without installing the app

---

## Technology: architecture

```
 Passenger app (Flutter) ─┐
 Driver app (Flutter) ────┼── HTTPS + WebSocket ──►  NestJS backend (AWS)
 Admin panel (Next.js) ───┘                             │
                                                        ├─ PostgreSQL + PostGIS   (rides, users, geo data)
                                                        ├─ Redis                  (live locations, matching, queues)
                                                        ├─ OSRM (self-hosted)     (routing, distance, ETA)
                                                        ├─ S3                     (KYC documents, encrypted)
                                                        └─ Razorpay · KYC API · SMS OTP · push notifications · masked calling
```

- **Flutter:** one codebase for both apps, with shared code between them
- **NestJS:** one backend split into clear modules, so it's quick for a small team to build and can be split into separate services later if needed
- **AWS Mumbai region**, with all infrastructure defined in code (Terraform) and automatic deployments

---

## Technology: key parts of the system

**Real-time driver matching**
- Drivers' phones send their location every 4–5 seconds; the server keeps it in memory (Redis) for fast lookup
- For each ride request, the server finds nearby available drivers, starting at 2km and widening to 6km, and offers the ride to the 3 closest at once
- The first to accept gets the ride; a lock makes sure two drivers can't both accept it
- Live updates go over WebSockets, with push notifications as a backup

**Fare engine**
- `fare = (base + per_km × km + per_min × min) × multiplier`
- Multiplier = time of day × local demand × festival calendar × weather, **capped at 1.5x**
- The admin can change every rate for each vehicle type without a new app release

**Subscription system**
- Razorpay UPI autopay, with status updated automatically when payments succeed or fail
- Automatic reminders, a 2-day grace period, and drivers blocked from going online when a subscription expires

---

## Technology: low running costs

**Maps are usually a ride app's biggest tech bill. Ours is close to zero:**
- Routing, distance and ETA run on **our own OSRM server using OpenStreetMap data**: no per-request cost
- Place search through low-cost Indian providers (Ola Maps / MapMyIndia), with caching to cut repeat requests
- Map display in the app uses open-source map tiles

**Infrastructure grows in steps:**

| Stage | Setup | Cost/month |
|---|---|---|
| Pilot | One EC2 server with Docker + managed Postgres | ~₹6k |
| City scale | ECS Fargate, ElastiCache, Postgres with automatic failover, CDN | ~₹25–40k |
| Multi-city | Multiple copies of the backend in separate data centres, read replicas, driver locations split across servers | Grows in line with drivers |

DevOps is handled in-house, so there's **no need for an infrastructure team** until much later.

---

## Technology: safety and trust

- **Driver verification:** driving licence, RC and ID checked through a third-party KYC service, plus a selfie match
- **Stops account sharing:** each account is locked to one phone, with random selfie checks when a driver goes online
- **OTP ride start:** the ride only starts with the passenger's code
- **SOS:** one tap calls 112, alerts the passenger's emergency contacts with a live location link, and raises an alarm on the admin dashboard
- **Route deviation alert:** if a ride goes well off the expected route, both people get a check-in message and admin is notified
- **Masked calling:** passengers and drivers never see each other's real phone numbers
- **Ratings on both sides**, with an automatic review for drivers whose rating drops

---

## Roadmap: 3 months to launch

| When | Product | Business and legal |
|---|---|---|
| **Month 1, weeks 1–2** | Database design, AWS setup, OSRM routing server, sign-in | Company registration, legal opinion, accounts with Razorpay and the KYC service |
| **Month 1, weeks 3–4** | Backend: driver sign-up and KYC, subscriptions, fare engine, ride flow | Apply for the aggregator licence; set fares for each vehicle type |
| **Month 2, weeks 5–6** | Driver app: KYC, subscription, go online, accept and complete rides | Get all 10+ committed drivers through KYC |
| **Month 2, weeks 7–8** | Passenger app: book, track, OTP ride start, SOS, ratings | Choose 2–3 pilot areas; recruit 30 test passengers |
| **Month 3, weeks 9–10** | Admin panel, trip-share page, masked calling; **closed pilot** | Pilot with 10+ drivers and 30 passengers; fix issues |
| **Month 3, weeks 11–12** | Play Store release, monitoring, performance testing | **Public launch in Coimbatore**; driver sign-up desks, college promotions |

**Target by the end of Month 3:** app live on the Play Store · 50+ drivers signed up · first paying drivers (once free trials end)

**After launch:** grow to 500 → 1,000 drivers, then add in-app payments, insurance, Tamil language and iOS, and expand to Tiruppur and Erode

---

## Team

**Siva Krishna**
- Full-stack developer (Flutter, NestJS, Next.js)
- DevOps and cloud engineer (AWS, Terraform, CI/CD)
- Builds and runs the whole product personally, **so there's no outsourced development cost**
- Based in Coimbatore, with direct connections to local drivers

**First hires (after funding):**
1. Operations lead for driver sign-up and support (someone from the local driver community)
2. Mobile developer (Flutter)
3. Marketing lead for campus and city marketing

---

## Legal and compliance

| Area | Requirement | Status / plan |
|---|---|---|
| **Aggregator licence** | Section 93, Motor Vehicles Act (amended 2019): a platform that connects drivers and passengers needs a licence from the state government. Follows the Motor Vehicle Aggregator Guidelines 2020 and their 2025 update. | Apply to the TN Transport Department after company registration. Closed pilot with known drivers only until then. |
| **Private-plate bike taxis** | Carrying paying passengers in private (white-plate) vehicles needs state permission. The 2025 central guidelines allow it, but each state decides, and TN's position has changed over time. | Formal legal opinion before public launch. Autos and cabs must have commercial (yellow) plates. The system can switch vehicle rules without an app update. |
| **Company and tax** | Pvt Ltd / LLP registration; GST registration once revenue passes ₹20L/year (18% on subscriptions) | Register the company in Week 1. Subscription pricing will state clearly whether GST is included. |
| **Driver KYC** | Checks on driving licence, RC, insurance and ID, plus police verification (usually required under aggregator licences) | Third-party KYC service; police verification certificate collected at sign-up |
| **Passenger insurance** | Aggregator guidelines expect accident cover for passengers | Per-ride accident insurance through an insurance partner, planned for after launch |
| **Data protection** | Digital Personal Data Protection Act, 2023: consent, storing data only as long as needed, security of personal data | Consent on sign-up, KYC files encrypted, data stored only in India (AWS Mumbai), deletion requests supported |
| **Payments** | Razorpay (licensed by RBI) handles UPI autopay; the platform never holds ride money | No payment licence needed for our model |
| **Play Store** | Declarations for background location and personal data | Privacy policy, data safety form, and a video showing why the driver app needs location |

**Our legal approach:** get a formal legal opinion and apply for the licence *before* public launch. Build the platform so rules can change without an app update. Don't grow faster than our legal clearances allow.

---

<!-- _paginate: false -->

# Thank you

**[App Name]:** drivers keep everything, passengers pay less.

Siva Krishna · sivakrishnacoc@gmail.com · +91 78100 02624 · Coimbatore

---

<!-- _paginate: false -->

# Add-on: Parcel & Goods Delivery
## The same zero-commission model, for goods (like Porter)

Bike · 3-wheeler · Mini truck · Pickup · Trucks

Starts within 3 months after the rides launch

---

## Add-on: Parcel delivery at a glance

**Same idea as rides:** delivery drivers pay a flat monthly subscription and keep **100% of every delivery fare**.

- **Where:** Coimbatore city first, intercity routes later (e.g. Coimbatore → Tiruppur, Erode)
- **For:** individuals, small shops, textile units, restaurants, and house or office moves
- **In the same app:** a separate **"Send Parcel"** tab in the passenger app, with no second app to install
- **Who pays:** the sender or the receiver pays the driver directly (cash or UPI)
- **Delivery proof:** the receiver gives an **OTP** to confirm delivery

**How big it could be:** Porter alone has **750,000+ driver-partners across India** ([source]), all working on commission today. That's the market this model can go after.

---

## Add-on: Vehicles and subscription plans

| Vehicle | Typical use | Subscription (proposed) |
|---|---|---|
| Bike | Documents, small parcels, food packets | ₹2,000/month |
| 3-wheeler (goods auto / Ape) | Shop stock, medium loads | ₹3,000/month |
| Mini truck (Tata Ace type) | Wholesale goods, small moves | ₹4,000/month |
| Pickup (Bolero type) | Heavier loads, furniture | ₹4000+/month |
| Trucks (14ft / 17ft) | House moves, bulk textile and industrial loads | ₹4000+/month |

- **One job at a time:** a driver does either rides or deliveries, and each needs its own plan
- **Delivery fare** = base + per km + vehicle size + weight + loading time, with the same capped surge as rides
- Loading helpers are not offered; the sender handles loading

---

## Add-on: How a delivery works

1. The sender opens **Send Parcel**, enters pickup and drop, and picks a vehicle
2. They add parcel details (type, approximate weight) and choose **who pays**, sender or receiver
3. They see the fare upfront and book; the nearest free goods driver accepts
4. The driver collects the parcel; sender and receiver both track it live
5. At drop-off, the receiver shares an **OTP** and the delivery is complete
6. Payment goes directly to the driver, and both sides rate each other

**Terms:** the platform connects senders and drivers only and **is not liable for lost or damaged goods**. This is stated clearly at booking.

**Items not allowed** (proposed): cash and jewellery, alcohol, drugs and illegal items, weapons, hazardous or flammable goods, live animals.

---

## Add-on: Technology

Parcel delivery **runs on the same platform** as rides, so there's no second system to build:

- **Same matching engine:** goods vehicles are just more vehicle types in the live driver search
- **Same fare engine:** adds pricing by vehicle size, weight and loading time on top of per-km pricing
- **Same subscription system:** a separate plan price for each goods vehicle type
- **New pieces:** parcel details on bookings, sender or receiver as payer, OTP from the receiver at drop-off, and a Send Parcel tab in the passenger app
- **Admin panel:** goods vehicle approvals, delivery fare settings, and a list of banned items
