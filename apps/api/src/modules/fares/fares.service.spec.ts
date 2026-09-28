import { TripKind, VehicleKind } from '../../generated/prisma/enums.js';
import type { GeoService } from '../geo/geo.service.js';
import type { MapsService } from '../maps/maps.service.js';
import { SETTING_DEFAULTS } from '../settings/settings.defaults.js';
import type { SettingsService } from '../settings/settings.service.js';
import { FaresService } from './fares.service.js';

const pickup = { lat: 10.98085, lng: 77.04175 };
const drop = { lat: 10.98833, lng: 76.96269 };

function service(): { fares: FaresService; estimate: ReturnType<typeof vi.fn> } {
  // The car and two-wheeler routes differ, as Google's often do.
  const estimate = vi.fn(async (p: { vehicleKind?: VehicleKind }) =>
    p.vehicleKind === VehicleKind.BIKE ? { distanceKm: 16.5, durationMin: 55 } : { distanceKm: 11.4, durationMin: 38 },
  );
  const geo = { locate: vi.fn(async () => ({ cityId: null, multiplier: 1 })), fareRule: vi.fn(async () => null) } as unknown as GeoService;
  const settings = { all: vi.fn(async () => SETTING_DEFAULTS) } as unknown as SettingsService;
  const fares = new FaresService({ estimate } as unknown as MapsService, geo, {} as never, {} as never, settings, {} as never);
  return { fares, estimate };
}

describe('FaresService', () => {
  it('books a bike at the fare P-10 showed: both priced on the one car route', async () => {
    const { fares, estimate } = service();
    const shown = (await fares.quoteAll({ pickup, drop, kind: TripKind.RIDE })).find((q) => q.vehicleKind === VehicleKind.BIKE);
    const booked = await fares.quoteOne({ pickup, drop, vehicleKind: VehicleKind.BIKE });
    expect(booked.total).toBe(shown?.total);
    expect(booked.distanceKm).toBe(11.4);
    expect(estimate.mock.calls.map((c) => (c[0] as { vehicleKind: VehicleKind }).vehicleKind)).toEqual([VehicleKind.CAB, VehicleKind.CAB]);
  });

  it('prices goods on the three-wheeler route, booked or listed', async () => {
    const { fares, estimate } = service();
    await fares.quoteAll({ pickup, drop, kind: TripKind.PARCEL });
    await fares.quoteOne({ pickup, drop, vehicleKind: VehicleKind.GOODS_BIKE });
    expect(estimate.mock.calls.map((c) => (c[0] as { vehicleKind: VehicleKind }).vehicleKind)).toEqual([VehicleKind.THREE_WHEELER, VehicleKind.THREE_WHEELER]);
  });
});
