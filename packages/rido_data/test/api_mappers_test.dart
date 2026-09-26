import 'package:flutter_test/flutter_test.dart';
import 'package:rido_data/rido_data.dart';
import 'package:rido_data/src/api/api_mappers.dart';

/// Shapes as the Rido API returns them (see apps/api trips.service TRIP_INCLUDE, dispatch offerDetails).
const _trip = {
  'id': 'cmtrip1',
  'kind': 'RIDE',
  'status': 'DRIVER_ASSIGNED',
  'vehicleKind': 'BIKE',
  'pickupName': 'Gandhipuram',
  'pickupAddr': 'Cross Cut Rd',
  'pickupLat': 11.0183,
  'pickupLng': 76.9725,
  'dropName': 'Brookefields Mall',
  'dropAddr': 'RS Puram',
  'dropLat': 11.009,
  'dropLng': 76.96,
  'distanceKm': 2.4,
  'durationMin': 8,
  'fare': {
    'vehicleKind': 'BIKE', 'distanceKm': 2.4, 'durationMin': 8, 'base': 20, 'distanceCharge': 12, 'timeCharge': 2,
    'minFareTopUp': 0, 'subtotal': 34, 'multiplier': 1, 'peakCharge': 0, 'total': 34,
  },
  'fareTotal': 34,
  'otp': '4821',
  'paymentMode': 'CASH',
  'createdAt': '2026-09-26T05:30:00.000Z',
  'driver': {
    'id': 'cmdrv1', 'vehicleKind': 'BIKE', 'vehicleModel': 'Honda Activa', 'vehicleColor': 'Grey', 'plate': 'TN 37 AB 1234',
    'upiId': 'k@okaxis', 'rating': 4.9, 'ridesCount': 120,
    'user': {'id': 'u2', 'name': 'Karthik S', 'phone': '+919876500002', 'gender': 'MALE'},
  },
  'passenger': {'id': 'u1', 'name': 'Priya R', 'phone': '+919876500001'},
};

void main() {
  test('phones are sent in the API format', () {
    expect(apiPhone('98430 12345'), '+919843012345');
    expect(apiPhone('+91-98430-12345'), '+919843012345');
    expect(apiPhone('+919843012345'), '+919843012345');
  });

  test('enum names round-trip between API and app', () {
    expect(enumToApi(VehicleKind.goodsBike), 'GOODS_BIKE');
    expect(enumToApi(KycDocType.policeVerification), 'POLICE_VERIFICATION');
    expect(vehicleKindFromApi('MINI_TRUCK'), VehicleKind.miniTruck);
    expect(vehicleKindFromApi('???'), VehicleKind.bike);
  });

  test('trip with driver and itemised fare', () {
    final t = tripFromJson(_trip);
    expect(t.status, TripStatus.driverAssigned);
    expect(t.vehicle, VehicleKind.bike);
    expect(t.pickup.location.latitude, 11.0183);
    expect(t.fare, 34);
    expect(t.quote!.total, 34);
    expect(t.driver!.name, 'Karthik S');
    expect(t.driver!.rides, 120);
    expect(t.otp, '4821');
  });

  test('NO_DRIVERS folds into cancelled; parcel details and delivery OTP', () {
    expect(tripStatusFromApi('NO_DRIVERS'), TripStatus.cancelled);
    final parcel = tripFromJson({
      ..._trip,
      'kind': 'PARCEL',
      'vehicleKind': 'GOODS_BIKE',
      'status': 'PICKED_UP',
      'payer': 'RECEIVER',
      'parcel': {'category': 'food', 'weight': 'from5to20', 'senderName': 'A', 'senderPhone': '1', 'receiverName': 'B', 'receiverPhone': '2'},
    });
    expect(parcel.isParcel, isTrue);
    expect(parcel.status, TripStatus.pickedUp);
    expect(parcel.parcel!.category, ParcelCategory.food);
    expect(parcel.parcel!.weight, WeightBand.from5to20);
    expect(parcel.parcel!.payer, ParcelPayer.receiver);
    expect(parcel.parcel!.deliveryOtp, '4821');
  });

  test('driver offer becomes a request card without the OTP', () {
    final r = rideRequestFromOffer({
      'trip': {..._trip, 'status': 'SEARCHING', 'otp': ''},
      'passenger': {'name': 'Priya R', 'phone': '+919876500001'},
      'pickupKm': 0.8,
      'pickupEtaMin': 3,
      'expiresInSeconds': 15,
    });
    expect(r.customerName, 'Priya R');
    expect(r.pickupDistanceKm, 0.8);
    expect(r.pickupEtaMin, 3);
    expect(r.otp, isEmpty);
    expect(r.fare, 34);
  });

  test('chat direction depends on the side', () {
    final m = {'id': 'm1', 'from': 'DRIVER', 'text': 'On my way', 'at': '2026-09-26T05:31:00.000Z'};
    expect(chatFromJson(m, iAmDriver: true).fromMe, isTrue);
    expect(chatFromJson(m, iAmDriver: false).fromMe, isFalse);
  });

  test('earnings, plan, payments, KYC, profile', () {
    final e = earningsFromJson({
      'total': 540, 'rides': 6, 'onlineHours': 5.5, 'rating': 4.9, 'commissionSaved': 160,
      'bars': [{'label': '8 AM', 'amount': 120, 'rides': 2}],
      'trips': [{'id': 't', 'at': '2026-09-26T05:31:00.000Z', 'from': 'A', 'to': 'B', 'fare': 60, 'paymentMode': 'UPI', 'distanceKm': 3, 'durationMin': 11, 'passengerName': 'P', 'isDelivery': false}],
    });
    expect(e.onlineHours, 6);
    expect(e.bars.single.rides, 2);
    expect(e.trips.single.paymentMode, PaymentMode.upi);

    final plan = planFromJson({
      'status': 'TRIAL', 'startsAt': '2026-09-01T00:00:00.000Z', 'endsAt': '2026-10-01T00:00:00.000Z', 'upiApp': 'PhonePe',
      'plan': {'vehicleKind': 'AUTO', 'period': 'MONTHLY', 'price': 999},
    });
    expect(plan.status, PlanStatus.trial);
    expect(plan.vehicle, VehicleKind.auto);
    expect(plan.monthlyPrice, 999);

    final pay = paymentFromJson({'amount': 999, 'status': 'PAID', 'createdAt': '2026-09-01T00:00:00.000Z', 'subscription': {'plan': {'period': 'WEEKLY'}}});
    expect(pay.label, 'Weekly plan');
    expect(pay.status, PaymentRecordStatus.paid);

    expect(kycFromJson({'type': 'VEHICLE_RC', 'status': 'UNDER_REVIEW'}).type, KycDocType.vehicleRc);

    final me = passengerFromJson({
      'name': 'Priya R', 'phone': '+919876500001', 'gender': 'FEMALE', 'preferWomenDriver': true,
      'savedPlaces': [{'id': 's1', 'label': 'Home', 'kind': 'home', 'name': 'Home', 'address': 'RS Puram', 'lat': 11.0, 'lng': 76.9}],
      'emergencyContacts': [{'id': 'c1', 'name': 'Amma', 'relation': 'Mother', 'phone': '+919800000000'}],
    });
    expect(me.gender, Gender.female);
    expect(me.savedPlaces.single.kind, SavedPlaceKind.home);
    expect(me.emergencyContacts.single.relation, 'Mother');
  });

  test('demand map: hotspots with nested hexes and the service-area outline', () {
    final m = DemandMap.fromJson({
      'at': '2026-09-26T15:00:00.000Z',
      'hotspots': [
        {
          'cell': '8761a2', 'level': 'high', 'score': 1, 'multiplier': 1.2, 'centre': [11.0168, 76.9779],
          'boundary': [[11.0, 76.9], [11.1, 76.9], [11.1, 77.0]],
          'nested': [{'cell': '8861a2', 'score': 0.5, 'boundary': [[11.0, 76.95], [11.02, 76.95], [11.02, 76.97]]}],
        },
      ],
      'serviceArea': [[[10.9, 76.8], [11.2, 76.8], [11.2, 77.1]]],
    });
    final h = m.hotspots.single;
    expect(h.level, HotspotLevel.high);
    expect(h.isSurging, isTrue);
    expect(h.centre.latitude, 11.0168);
    expect(h.boundary, hasLength(3));
    expect(h.nested.single.score, 0.5);
    expect(m.serviceArea.single, hasLength(3));
  });
}
