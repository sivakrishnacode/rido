import { areaName } from './driver-map.service.js';

/** The city and state names a test city has in the database. */
const CITY = new Set(['coimbatore', 'tamil nadu']);

describe('areaName', () => {
  it('takes the locality from a full Google address', () => {
    expect(areaName('12, Cross Cut Rd, Gandhipuram, Coimbatore, Tamil Nadu 641012, India', CITY)).toBe('Gandhipuram');
    expect(areaName('Avinashi Rd, Peelamedu, Tamil Nadu 641004, India', CITY)).toBe('Peelamedu');
  });

  it('drops plus codes, door numbers and the city', () => {
    expect(areaName('8Q7X+2R Ondipudur, Coimbatore, Tamil Nadu', CITY)).toBe('Ondipudur');
    expect(areaName('42, Coimbatore', CITY)).toBeNull();
  });

  it('keeps a single place name as is', () => {
    expect(areaName('Ukkadam Bus Stand', CITY)).toBe('Ukkadam Bus Stand');
    expect(areaName('', CITY)).toBeNull();
    expect(areaName(null, CITY)).toBeNull();
  });
});
