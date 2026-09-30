/**
 * Privacy policy, terms and account deletion text. The apps carry shorter versions of the same text
 * (apps/passenger/lib/features/onboarding/legal_screen.dart and the driver's copy): keep them in line.
 * Every claim here must match what the code does (data model: apps/api/prisma/schema.prisma).
 */
import { site } from "./site";

export type LegalSection = {
  heading: string;
  paragraphs: readonly string[];
  list?: readonly string[];
  link?: { href: string; label: string };
};

export type LegalDoc = { title: string; updated: string; intro: string; sections: readonly LegalSection[] };

export const privacy: LegalDoc = {
  title: "Privacy policy",
  updated: "30 September 2026",
  intro:
    `This policy covers the ${site.apps.rider.name} rider app, the ${site.apps.driver.name} app and this website. ` +
    "We collect only what we need to run rides and deliveries. We do not show ads and we never sell your data.",
  sections: [
    {
      heading: "What we collect from riders",
      paragraphs: [],
      list: [
        "Your mobile number, used to sign in with a one-time code.",
        "Your name and, if you add them, your email, gender, saved places and emergency contacts.",
        "Your trips and parcels: pickup, drop, route, fare, payment mode (cash or UPI), ratings and cancellations.",
        "Your device location while you book or ride.",
      ],
    },
    {
      heading: "What we collect from drivers",
      paragraphs: [],
      list: [
        "Your name, mobile number, vehicle details (type, model, colour and number plate) and the UPI ID riders pay you on.",
        "Your documents: driving licence, Aadhaar, vehicle RC, insurance and police verification.",
        "A profile photo, and the selfie from your identity check.",
        "Your location while you are online or on a job, and the route of each trip.",
        "Your trips, ratings, cancellations and booking preferences.",
      ],
    },
    {
      heading: "Identity checks",
      paragraphs: [
        "Identity checks are run by Didit (didit.me): they scan your ID and take a live selfie. Drivers must pass " +
          "one before going online. For riders it is optional and adds a Verified badge.",
        "From the check we keep the result, your name and date of birth as read from the ID and the last 4 digits " +
          "of each document number. For drivers we also keep the selfie, to confirm that your profile photo is you.",
      ],
    },
    {
      heading: "How we use it",
      paragraphs: [
        "To sign you in, match riders with nearby drivers, show each side where the other is, work out fares, send " +
          "trip notifications, check that a trip is going as planned (long stops, route changes) and help when " +
          "something goes wrong.",
      ],
    },
    {
      heading: "What the other person on your trip sees",
      paragraphs: [
        "Your driver sees your name, phone number, pickup and drop, and whether you are verified. If you ask for a " +
          "woman driver (Butterfly), your driver sees that it is a Butterfly ride.",
        "Riders see their driver's name, photo, rating, phone number, vehicle, number plate and UPI ID, and the " +
          "driver's location during the trip. Phone numbers are shared so that you can call each other about the " +
          "current trip.",
      ],
    },
    {
      heading: "Location",
      paragraphs: [
        "The rider app uses your location only while the app is open or a trip is in progress. You can turn it off " +
          "in your phone settings and type your pickup instead.",
        "The driver app shares your location while you are online or on a job, including when the app is in the " +
          "background: a notification shows while it is on. Going offline stops it.",
      ],
    },
    {
      heading: "App permissions",
      paragraphs: [],
      list: [
        "Location (both apps): to find drivers, show pickups and track trips.",
        "Notifications (both apps): trip updates and, for drivers, new requests.",
        "Camera (driver app): your selfie and profile photo.",
        "Display over other apps and full-screen alerts (driver app): the floating bubble and the incoming-request " +
          "screen, so that you see requests while you use other apps.",
      ],
    },
    {
      heading: "Who we share it with",
      paragraphs: [
        "Only with the other person on your trip; with your emergency contacts when you share a trip or use SOS; " +
          "with emergency services when you use SOS; with the service providers below; and when the law requires it.",
      ],
      list: [
        "Amazon Web Services: our servers and file storage, in Mumbai, India.",
        "Google Maps Platform: maps, address search and routes.",
        "Firebase Cloud Messaging (Google): notifications.",
        "Didit: identity checks.",
        "An SMS provider: sign-in codes.",
      ],
    },
    {
      heading: "Security",
      paragraphs: [
        "The apps talk to our servers over HTTPS. Documents and photos are kept in private, encrypted storage that " +
          "only our servers can read.",
      ],
    },
    {
      heading: "Keeping and deleting data",
      paragraphs: [
        "Trip records are kept for 3 years for safety and tax purposes. You can ask us to delete your account and " +
          "personal data at any time.",
      ],
      link: { href: "/delete-account/", label: "How to delete your account" },
    },
    {
      heading: "This website",
      paragraphs: ["This website sets no cookies and runs no analytics or trackers."],
    },
    {
      heading: "Changes and contact",
      paragraphs: [
        "If we change this policy we update the date at the top. Questions: write to " +
          `${site.email}, or use Help & support in the app.`,
      ],
    },
  ],
};

export const terms: LegalDoc = {
  title: "Terms of service",
  updated: "30 September 2026",
  intro: `These terms cover the ${site.apps.rider.name} and ${site.apps.driver.name} apps.`,
  sections: [
    {
      heading: "About Tamil Taxi",
      paragraphs: [
        "Tamil Taxi is a technology platform that connects passengers and senders in Coimbatore with independent " +
          "drivers of bikes, autos, cabs and goods vehicles. Tamil Taxi does not own vehicles or employ drivers.",
      ],
    },
    {
      heading: "Free to use",
      paragraphs: [
        "Tamil Taxi takes 0% commission on rides and deliveries and charges no subscription, for any vehicle type. " +
          "It runs on voluntary contributions from drivers and riders (Account › Contribute in the app). " +
          "Contributing is never required to book or to get requests.",
      ],
    },
    {
      heading: "Fares and payment",
      paragraphs: [
        "The fare shown before you book is locked at booking. Peak-time pricing is capped at 1.5x and goes to your " +
          "driver. You pay the driver directly by cash or UPI; Tamil Taxi does not collect fares. Drivers keep " +
          "100% of every fare, tip and waiting charge.",
      ],
    },
    {
      heading: "Cancellations",
      paragraphs: [
        "You can cancel a request at any time before the ride starts. Repeated late cancellations may limit your " +
          "access to the app so that drivers are not kept waiting.",
      ],
    },
    {
      heading: "Safety and conduct",
      paragraphs: [
        "Treat each other with respect, follow traffic rules, wear a helmet on bike rides and never carry " +
          "prohibited items. In an emergency, use SOS in the app or call 112. Repeated complaints may put an " +
          "account on hold while we review them.",
      ],
    },
    {
      heading: "Parcels",
      paragraphs: [
        "You are responsible for what you send. Tamil Taxi connects you with drivers and is not liable for lost or " +
          "damaged goods; loading and unloading is done by the sender and receiver.",
      ],
    },
    {
      heading: "Drivers",
      paragraphs: [
        "Every driver is an independent service provider. You must keep a valid driving licence, vehicle RC, " +
          "insurance and police verification, and pass an identity check. We may ask for a quick selfie before you " +
          "go online to confirm it is you.",
      ],
    },
    {
      heading: "Service area",
      paragraphs: [
        "Tamil Taxi currently operates across Coimbatore. Bookings with a pickup outside the service area cannot " +
          "be made.",
      ],
    },
    {
      heading: "Contact and law",
      paragraphs: [
        `Questions about these terms? Write to ${site.email} or use Help & support in the app. These terms are ` +
          "governed by the laws of India, with courts in Coimbatore, Tamil Nadu.",
      ],
    },
  ],
};

/** Google Play asks for a web page where anyone can request deletion, without the app installed. */
export const deletion = {
  deleted: [
    "Your profile: name, mobile number, email and gender.",
    "Saved places and emergency contacts.",
    "Photos, documents and identity-check results (drivers).",
    "Vehicle details, UPI ID and booking preferences (drivers).",
    "Notification tokens for your devices.",
  ],
  kept: [
    "Trip records (date, route, fare, vehicle) for 3 years, for safety and tax purposes. After that they are deleted.",
  ],
} as const;
