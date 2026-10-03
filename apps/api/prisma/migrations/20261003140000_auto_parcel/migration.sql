-- Parcel on Auto: a booking tier (up to 100 kg inside the auto) served by passenger autos that take parcels and by
-- goods 3-wheelers. Never a driver's own vehicle.
ALTER TYPE "VehicleKind" ADD VALUE 'AUTO_PARCEL' AFTER 'GOODS_BIKE';
