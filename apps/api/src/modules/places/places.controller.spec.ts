import { originOf } from './places.controller.js';

describe('originOf (autocomplete lat / lng)', () => {
  it('reads a valid pair; anything else is no origin', () => {
    expect(originOf('10.98085', '77.04175')).toEqual({ lat: 10.98085, lng: 77.04175 });
    expect(originOf(undefined, undefined)).toBeUndefined();
    expect(originOf('10.9', undefined)).toBeUndefined();
    expect(originOf('abc', '77')).toBeUndefined();
    expect(originOf('', '')).toBeUndefined();
    expect(originOf('95', '77')).toBeUndefined();
  });
});
