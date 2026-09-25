import { decodePolyline } from './polyline.js';

describe('decodePolyline', () => {
  it('decodes the Google reference example', () => {
    // Arrange: example from Google's polyline algorithm docs.
    const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    // Act
    const points = decodePolyline(encoded);
    // Assert
    expect(points).toEqual([
      { lat: 38.5, lng: -120.2 },
      { lat: 40.7, lng: -120.95 },
      { lat: 43.252, lng: -126.453 },
    ]);
  });

  it('returns nothing for an empty string', () => {
    expect(decodePolyline('')).toEqual([]);
  });
});
