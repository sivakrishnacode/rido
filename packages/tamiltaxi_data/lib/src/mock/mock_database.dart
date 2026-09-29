import '../models/driver.dart';
import '../models/people.dart';
import '../models/trip.dart';
import '../seed.dart';

/// In-memory state shared by all mock repositories. "Reset all seed data" rebuilds it.
class MockDatabase {
  MockDatabase();

  // Passenger
  bool hasSeenOnboarding = false;
  bool passengerLoggedIn = false;
  bool passengerIsNew = true;
  PassengerProfile passenger = Seed.priya;
  List<Trip> trips = Seed.passengerHistory();
  List<SupportTicket> tickets = Seed.tickets();

  // Driver
  bool driverLoggedIn = false;
  DriverProfile driver = Seed.karthik;
  EmergencyContact driverEmergencyContact =
      const EmergencyContact(id: 'dec-1', name: 'Lakshmi S', relation: 'Wife', phone: '+91 98940 66123');
  List<KycDocument> kyc = List.of(Seed.kycFresh);
  SubscriptionPlan plan = Seed.plan();
  List<PaymentRecord> payments = Seed.payments();
  int todayEarnings = Seed.todayEarnings;
  int todayRides = Seed.todayRides;
  List<EarningsTrip> todayTrips = Seed.todayTrips();
  int requestCounter = 0;
}
