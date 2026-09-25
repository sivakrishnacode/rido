import { cellAt, cellsForCircle, validateCells } from './h3.util.js';

describe('h3 utils', () => {
  it('covers an 18 km circle around Coimbatore at resolution 8', () => {
    const cells = cellsForCircle({ lat: 11.0168, lng: 76.9658, radiusKm: 18, resolution: 8 });
    expect(cells.length).toBeGreaterThan(1000);
    expect(cells).toContain(cellAt(11.0183, 76.9725, 8)); // Gandhipuram
  });

  it('rejects invalid or wrong-resolution cells', () => {
    const good = cellAt(11.0183, 76.9725, 8);
    const wrongRes = cellAt(11.0183, 76.9725, 9);
    expect(validateCells([good, good, wrongRes, 'nope'], 8)).toEqual({ valid: [good], invalid: [wrongRes, 'nope'] });
  });
});
