-- Ride tiers: Scooty (scooter), Auto Priority (autos, offered first), Sedan and SUV (CAB stays the Mini hatchback).
ALTER TYPE "VehicleKind" ADD VALUE IF NOT EXISTS 'SCOOTY' AFTER 'BIKE';
ALTER TYPE "VehicleKind" ADD VALUE IF NOT EXISTS 'AUTO_PRIORITY' AFTER 'AUTO';
ALTER TYPE "VehicleKind" ADD VALUE IF NOT EXISTS 'SEDAN' AFTER 'CAB';
ALTER TYPE "VehicleKind" ADD VALUE IF NOT EXISTS 'SUV' AFTER 'SEDAN';
