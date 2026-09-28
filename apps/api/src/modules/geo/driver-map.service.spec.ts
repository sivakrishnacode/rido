import { areaName } from './driver-map.service.js';

describe('areaName', () => {
  it('takes the locality from a full Google address', () => {
    expect(areaName('12, Cross Cut Rd, Gandhipuram, Coimbatore, Tamil Nadu 641012, India')).toBe('Gandhipuram');
    expect(areaName('Avinashi Rd, Peelamedu, Tamil Nadu 641004, India')).toBe('Peelamedu');
  });

  it('drops plus codes, door numbers and the city', () => {
    expect(areaName('8Q7X+2R Ondipudur, Coimbatore, Tamil Nadu')).toBe('Ondipudur');
    expect(areaName('42, Coimbatore')).toBeNull();
  });

  it('keeps a single place name as is', () => {
    expect(areaName('Ukkadam Bus Stand')).toBe('Ukkadam Bus Stand');
    expect(areaName('')).toBeNull();
    expect(areaName(null)).toBeNull();
  });
});
