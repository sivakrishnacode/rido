# Rido: Business Model

**Zero-commission rides and parcel delivery for Coimbatore.**
Drivers pay one flat subscription and keep 100% of every fare. Passengers pay lower fares, directly to the driver.

Version 1.0 · September 2026 · Status: pre-launch (prototype built)

> Figures marked **(assumption)** are planning estimates to be validated in the pilot. Competitor figures come from
> public sources (brineweb.com Rapido analysis, Rapido Captain Terms) and should be re-checked before external use.

---

## 1. Summary

| | |
|---|---|
| **What** | Ride-hailing (bike, auto, cab) and parcel/goods delivery (bike to 17ft truck) in one passenger app, with a separate driver app |
| **Where** | Coimbatore first; then Tier 2 cities in Tamil Nadu and Kerala (Tiruppur, Erode, Salem, Madurai, Kochi) |
| **How we earn** | Driver subscriptions (monthly, auto-debited by UPI Autopay). No commission on any fare |
| **Why drivers join** | A full-time driver keeps ₹6,000–8,500 more per month than on a 20–30% commission platform |
| **Why passengers use it** | Fares 10–15% below competitors, fare locked at booking, surge capped at 1.5x, pay the driver directly |
| **Why we can be cheap** | No fare collection, no payouts, no commission accounting; lean cloud stack (₹6k–40k/month) |
| **Break-even (servers)** | ~15 paying drivers. Break-even (small team) ~250 drivers **(assumption)** |

---

## 2. The problem

**Drivers:** commission platforms take 15–40% of every fare (bike taxis 15–20%, cabs 20–30% plus fees). A driver
earning ₹35,000/month in fares can lose ₹7,000–10,500 to the platform. Commission also rises with effort: the more a
driver works, the more they pay.

**Passengers:** part of every fare pays the platform's cut, so fares stay high. Surge pricing is unpredictable, and
the extra rarely reaches the driver.

**Tier 2 cities:** public transport is patchy, two-wheelers and autos dominate short trips, and price sensitivity is
high. Large platforms tune pricing for metros.

---

## 3. The solution

### 3.1 For drivers ("Rido Driver" app)
- One flat monthly plan per vehicle type. **First month free.**
- Keep **100% of every fare**, including any peak/surge amount.
- Paid **directly by the passenger** (cash or UPI to the driver's own UPI ID, with an in-app QR).
- Plan auto-debits by **UPI Autopay**; a **2-day grace period** after a missed payment.
- Pause or cancel any time; plan stays active until the end of the paid month.

### 3.2 For passengers ("Rido" app)
- Bike, auto, cab rides and parcels (documents to house moves) in one app.
- Fare shown and **locked at booking**; itemised breakdown; surge **capped at 1.5x**.
- Safety: ride OTP, SOS with live location to 3 emergency contacts, trip sharing, masked calls, women-driver preference.

### 3.3 For businesses (later)
- Corporate ride accounts (employee commute), shop and SME delivery accounts (textile, wholesale, pharma).

---

## 4. Revenue model

### 4.1 Core: driver subscriptions

**Pricing: daily, weekly and monthly plans per vehicle**

Priced against the market: Rapido charges autos ~₹9–29/day and cabs ₹500/month (after ₹10,000 earnings), and still
takes 15–20% commission on bikes, which is where Rido wins clearly. Price points **(assumption, to validate in the
pilot)**:

| Vehicle | Daily pass | Weekly plan | Monthly plan | Versus Rapido / others |
|---|---|---|---|---|
| Bike (rides) | ₹79 | ₹449 | ₹1,499 | ~₹3,000–4,000 commission on ₹20k fares |
| Auto | ₹35 | ₹199 | ₹749 | ₹270–870/month login fees |
| Cab | ₹49 | ₹279 | ₹999 | ₹500/month + other platform fees |
| Bike (parcel) | ₹79 | ₹449 | ₹1,499 | Porter/Rapido parcel fees |
| 3-wheeler goods | ₹99 | ₹549 | ₹1,999 | Porter commission ~15–20% |
| Mini truck | ₹149 | ₹799 | ₹2,999 | Porter commission |
| Pickup / trucks | ₹199 | ₹1,099 | ₹3,999 | Porter commission |

**How the three plans work**

| | Daily pass | Weekly plan | Monthly plan |
|---|---|---|---|
| Best for | Trying Rido, weekend or part-time drivers | Drivers paid weekly, or unsure about committing | Full-time drivers (cheapest per day) |
| Validity | Midnight to midnight, starts on first "Go online" of the day | 7 days from purchase | 30 days, auto-renews |
| Payment | UPI one-time, pay before going online | UPI one-time or Autopay (weekly mandate) | UPI Autopay (monthly mandate) |
| Cost per day (bike) | ₹79 | ~₹64 | ~₹50 |
| Unused days | – | – | Pause up to 7 days/month; unused days roll over |
| Switching | Upgrade any time; the day's pass is credited | Upgrade to monthly; the remaining days are credited | Downgrade at the next renewal |

- **Auto-upgrade nudge:** after 5 daily passes in a week, the app suggests the weekly plan; after 3 weekly plans in a
  row, the monthly plan ("You'd have saved ₹X").
- **Never pay more than monthly:** daily and weekly spend in a calendar month is capped at the monthly price. Once a
  driver's passes add up to the monthly price, the rest of the month is free.

Plan rules:
- **First month free**; referral: **7 free days** per driver referred who completes 20 rides.
- **Earn-first threshold:** the plan only charges once the driver has earned ₹5,000 in fares that month,
  so part-time drivers never pay more than they make.
- Monthly is the cheapest per day for anyone driving 20+ days a month.
- **GST:** plans are shown **GST-inclusive** (₹1,499 includes 18% GST; Rido receives ₹1,270; ₹79 daily → ₹67). Registration is required
  once turnover passes ₹20 lakh/year.

### 4.2 Secondary revenue (after product-market fit)

| Stream | Model | When | Notes |
|---|---|---|---|
| Business accounts | Monthly invoice, 3–5% service fee paid by the business, not the driver | Month 6+ | Corporate commute, SME delivery |
| Insurance distribution | Referral fee from partner (Acko/Digit) for driver health/vehicle cover | Month 6+ | Also optional ₹1–2 per-ride passenger accident cover |
| Driver services | Partner referral fees: vehicle loans/EMI, fuel cards, servicing, EV leasing | Month 9+ | Never deducted from fares |
| Priority listing / fleet plans | Fleet owners pay per vehicle (5% discount at 10+ vehicles) | Month 6+ | Fleet dashboard |
| In-app ads | Local brands on booking-complete and parcel screens only | Year 2 | Low priority; must not slow booking |
| Passenger "Rido Plus" | ₹49/month: free cancellations, priority matching, parcel discounts | Year 2 | Test demand first |

**Guardrail:** Rido never takes a percentage of a driver's fare. Any new revenue must come from businesses, partners
or optional passenger services.

---

## 5. Unit economics

### 5.1 Driver economics (monthly, full-time, 26 days)

| Vehicle | Fares earned **(assumption)** | Commission platform | Rido monthly plan | Driver gains with Rido |
|---|---|---|---|---|
| Bike | ₹20,000 | ₹3,000–4,000 (15–20%) | ₹1,499 | **+₹1,500–2,500** |
| Auto | ₹30,000 | ₹270–870 (Rapido SaaS) / ₹6,000 (20% apps) | ₹749 | **Parity vs Rapido; +₹5,250 vs commission apps** |
| Cab | ₹45,000 | ₹500 (Rapido) / ₹9,000–13,500 (Uber/Ola 20–30%) | ₹999 | **+₹8,000–12,500 vs Uber/Ola** |
| 3-wheeler goods | ₹35,000 | ₹5,250–7,000 (15–20%) | ₹1,999 | **+₹3,250–5,000** |
| Mini truck | ₹50,000 | ₹7,500–10,000 | ₹2,999 | **+₹4,500–7,000** |

Example: a cab driver earning ₹45,000 on a 25% commission app pays ₹11,250; on Rido the monthly plan is ₹999, so they
keep **+₹10,250/month**.

### 5.2 Rido economics per paying driver (blended)

| Line | Per driver / month |
|---|---|
| Blended plan price (50% bike, 30% auto, 15% cab, 5% goods; monthly-equivalent) | ~₹1,260 |
| Less GST (18%, inclusive) | −₹192 |
| Less payment gateway (~2%) | −₹25 |
| Less SMS OTP, masked calls, maps (**assumption**) | −₹40 |
| Less cloud infra share (at 1,000 drivers, ₹35k/month) | −₹35 |
| **Contribution per driver** | **~₹970 (77%)** |

### 5.3 Acquisition cost (assumption)

| Item | Driver | Passenger |
|---|---|---|
| KYC and background check | ₹30–100 (one-time) | – |
| Field onboarding (stands, camps) | ₹150–250 | – |
| First month free (revenue forgone) | ~₹1,260 | – |
| Launch offers (first 3 rides ₹20 off, paid by Rido to the driver) | – | ₹60 |
| Referrals, posters, local social ads | ₹100 | ₹20–40 |
| **Total CAC** | **~₹1,600** | **~₹90** |

**Driver payback:** ~2 paying months (CAC ₹1,600 ÷ contribution ₹970). Target driver retention: 70% at 6 months.
**Driver lifetime value (18-month average life):** ~₹17,000.

---

## 6. Revenue scenarios

Monthly recurring revenue (MRR), GST-inclusive, paying drivers only:

| Paying drivers | Monthly revenue (blended ~₹1,260) | Annual |
|---|---|---|
| 100 (pilot) | ₹1.3 L | ₹15 L |
| 500 | ₹6.3 L | ₹76 L |
| 1,000 | ₹12.6 L | ₹1.5 Cr |
| 3,000 (Coimbatore + 2 cities) | ₹38 L | ₹4.5 Cr |
| 10,000 (6 cities) | ₹1.26 Cr | ₹15 Cr |

Daily and weekly passes are counted at their monthly-equivalent value (capped at the monthly price). Lower prices for
autos and cabs trade revenue per driver for many more drivers, who are the majority in Tier 2 cities.

**Market size, Coimbatore (assumption):** ~10,000 active app drivers plus ~15,000 independent autos. At 10% share
(2,500 drivers): ~₹31 L/month.

---

## 7. Cost structure

| Cost | Pilot (≤200 drivers) | City scale (1,000–3,000) |
|---|---|---|
| Cloud (AWS Mumbai; self-hosted routing, CARTO/OSM maps) | ₹6–12k | ₹25–40k |
| SMS OTP, masked calling | ₹2–5k | ₹15–30k |
| Payment gateway (Razorpay Subscriptions, ~2%) | ₹4k | ₹25–75k |
| Support (1 → 3 people, Tamil + English) | ₹20k | ₹60k |
| Field onboarding agents | ₹15k | ₹45k |
| Marketing (posters, auto-stand camps, local Instagram) | ₹20k | ₹1–1.5 L |
| Legal, accounting, insurance | ₹10k | ₹25k |
| **Total monthly** | **~₹0.8–0.9 L** | **~₹3–4.2 L** |

**Operating break-even:** ~70 paying drivers in the pilot setup, ~330 at city scale **(assumption)**.

---

## 8. Pricing for passengers

- Fare = max(minimum fare, base + per-km × distance + per-minute × time) × demand multiplier, capped at 1.5x.
- Every line is rounded down to the rupee, so the breakdown always adds up.
- Base rates are set 10–15% below the leading platform in Coimbatore (checked by hand before launch).
- The peak amount goes 100% to the driver.
- Sample fares (4.2 km, Gandhipuram → Brookefields): **Bike ₹38, Auto ₹72, Cab ₹145.**
- Sample goods fares (6.8 km, Peelamedu → Race Course): **Bike ₹49, 3-wheeler ₹180, Mini truck ₹420.**
- Parcel: sender or receiver can pay; loading and unloading is done by the customer.

---

## 9. Competitive landscape

| | Rapido | Uber / Ola | Porter | Namma Yatri | **Rido** |
|---|---|---|---|---|---|
| Driver cost: bike | 15–20% commission | 20–30% | – | Small fee | **Flat plan** |
| Driver cost: auto/cab | Daily/monthly subscription | 20–30% + fees | – | Small daily fee | **Flat plan** |
| Goods delivery | Bike parcel only | Limited | Main business, commission | No | **Bike to 17ft truck, flat plan** |
| Rides + trucks in one app | No | No | No | No | **Yes** |
| Fare locked, surge cap | Varies | Surge | Varies | Varies | **Locked, 1.5x cap, surge to driver** |
| Focus | 100+ cities | Metros | Metros + Tier 2 | Bengaluru/Chennai | **Tier 2, local-first** |

**Where Rido wins:**
1. **Bikes and goods**, where competitors still take a commission.
2. **One app for rides and trucks** (a textile shop owner in Tiruppur uses the same app for a cab and a mini truck).
3. **Fairer driver terms** (see §10) than the industry standard.
4. **Local operations**: Tamil-first support, auto-stand onboarding camps, city-specific pricing.

**Honest risks:** Rapido already uses subscriptions for autos and cabs, and can extend them to bikes. "0% commission"
alone is not a lasting moat; driver trust, liquidity (short ETAs) and the combined ride + goods network must be.

---

## 10. Driver terms (a selling point)

Industry terms (e.g. Rapido's) let the platform change fees at will, cap its own liability at ₹1,000 while drivers
indemnify it without limit, and terminate accounts without notice. Rido's driver promise:

| Rido commitment | Detail |
|---|---|
| **Price lock** | Plan price fixed for 12 months; 30 days' notice before any change |
| **No hidden fees** | The plan is the only charge. No per-ride, login or "convenience" fees on drivers |
| **Fair deactivation** | Written reasons, a warning first (except safety or criminal cases), appeal within 7 days |
| **No-lead refund** | If you're online 40+ hours in a week and get no requests, that week's fee is credited |
| **Your data** | Export your trip and earnings history any time |
| **Tax help** | Free monthly invoices and a GST/income summary |
| **Insurance** | Group accident cover included from 500+ drivers (partner quote needed) |
| **Non-exclusive** | Drive on other apps too; no lock-in |

Legal structure (as used by Rapido for autos/cabs): Rido is a **software and lead-generation platform**. Drivers run
their own business, collect fares directly and issue their own invoices. To be confirmed with a Tamil Nadu transport
lawyer, including aggregator licensing and bike-taxi rules.

---

## 11. Go-to-market

**Phase 0: pilot (months 1–3)**
- 100–200 drivers in 3 zones: Gandhipuram, Peelamedu/Avinashi Road, RS Puram.
- Onboarding camps at auto stands and bike-taxi hubs; driver referral (7 free days).
- Passenger launch: colleges (PSG Tech, CIT), IT parks (Tidel Park, Saravanampatti), malls; ₹20 off the first 3 rides.
- **Liquidity goal:** ETA under 5 minutes in pilot zones, 7 AM to 10 PM.

**Phase 1: Coimbatore city (months 4–9)**
- 1,000+ drivers; parcel and goods launch (textile, hardware, wholesale markets such as Town Hall and Ukkadam).
- Business accounts for 20+ SMEs and 3+ IT companies.

**Phase 2: Tier 2 expansion (months 10–18)**
- Tiruppur (textile goods-heavy), Erode, Salem, then Madurai and Kochi.
- Playbook per city: 1 city lead, 2 field agents, launch at 200 drivers.

---

## 12. Key metrics

| Metric | Pilot target | City-scale target |
|---|---|---|
| Paying drivers | 150 | 1,000+ |
| Driver 6-month retention | 60% | 70% |
| Trial → paid conversion (after free month) | 50% | 60% |
| Rides per online driver-hour | 1.2 | 1.8 |
| Median ETA in active zones | < 5 min | < 4 min |
| Passenger repeat rate (30-day) | 35% | 50% |
| Rides / day | 500 | 8,000 |
| Payment failure rate (Autopay) | < 8% | < 5% |
| Contribution margin | > 60% | > 75% |

**North-star metric:** *driver earnings kept per online hour.* It shows the value to drivers and the platform's liquidity at once.

---

## 13. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Bike-taxi rules in Tamil Nadu (private plates) | Could stop bike rides | Lawyer review before launch; autos/cabs on commercial plates from day 1; parcel works regardless |
| Rapido cuts prices or extends subscriptions to bikes | Weaker price advantage | Tiered daily/weekly/monthly pricing, driver-terms advantage, rides + goods in one app, local operations |
| Low liquidity (long ETAs) in early months | Passengers churn | Launch zone by zone; guarantee early drivers ₹X/hour minimum for the first 2 weeks (funded from marketing) |
| Payment collection (Autopay failures) | Revenue leakage | 2-day grace, retry with another UPI app, fall back to a daily or weekly pass |
| Safety incident | Brand and legal risk | KYC + police verification, SOS, trip sharing, masked calls, insurance partner |
| Drivers skip the app for repeat passengers | Lower engagement (not lost revenue: plans are flat) | Acceptable by design; the flat plan still earns |
| GST and regulatory compliance | Fines | Register early; GST-inclusive pricing; aggregator licence as required |

---

## 14. Funding needs (bootstrap-first)

| Stage | Need | Use |
|---|---|---|
| Pilot (3 months) | ₹3–5 L | Legal, KYC, field camps, marketing, cloud |
| City scale (months 4–9) | ₹25–40 L | Team of 6–8, marketing, insurance, goods launch |
| Expansion (months 10–18) | ₹1.5–2.5 Cr | 5 new cities, business accounts, EV partnerships |

---

## 15. Decisions still open

1. Final daily/weekly/monthly price points (test two price levels by zone in the pilot).
2. Whether plan prices include GST (recommended: yes, show one clear number).
3. The earn-first threshold amount (₹5,000 proposed).
4. The insurance partner and whether cover is bundled or optional.
5. Bike-taxi launch timing, pending Tamil Nadu legal advice.
