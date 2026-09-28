import { describe, expect, it } from "vitest";

import { isSosActive, safetyEventLine, sosMapUrl, sosSourceLabel } from "@/lib/safety";

describe("SOS helpers", () => {
  it("labels where an SOS came from", () => {
    expect(sosSourceLabel("BUTTON")).toBe("Pressed SOS");
    expect(sosSourceLabel("CHECK")).toBe("Asked for help (safety check)");
    expect(sosSourceLabel("ARRIVAL")).toBe("Didn't reach safely");
    expect(sosSourceLabel("something")).toBe("Pressed SOS");
  });

  it("links to the map only with a position", () => {
    expect(sosMapUrl({ lat: 11.01834, lng: 76.97251 })).toBe("https://maps.google.com/?q=11.01834,76.97251");
    expect(sosMapUrl({ lat: null, lng: 76.9 })).toBeNull();
  });

  it("open and acknowledged still need someone", () => {
    expect(isSosActive("OPEN")).toBe(true);
    expect(isSosActive("ACKNOWLEDGED")).toBe(true);
    expect(isSosActive("RESOLVED")).toBe(false);
    expect(isSosActive("FALSE_ALARM")).toBe(false);
  });
});

describe("safetyEventLine", () => {
  it("words an SOS event", () => {
    expect(safetyEventLine({ kind: "SOS_LINKED", payload: { role: "DRIVER", source: "BUTTON", sosId: "x" } })).toEqual({ title: "SOS", detail: "Driver · Pressed SOS" });
    expect(safetyEventLine({ kind: "SOS_LINKED", payload: null }).detail).toBe("Passenger · Pressed SOS");
  });

  it("words a long stop and the rider's answer", () => {
    expect(safetyEventLine({ kind: "STOP", payload: { minutes: 6, pushed: true } })).toEqual({
      title: "Long stop",
      detail: 'Stopped 6 min away from pickup and drop · rider asked "Is everything OK?"',
    });
    expect(safetyEventLine({ kind: "STOP", payload: { minutes: 5, pushed: true, answer: "HELP" } }).detail).toMatch(/rider asked for help$/);
    expect(safetyEventLine({ kind: "STOP", payload: { minutes: 5, pushed: false } }).detail).toBe("Stopped 5 min away from pickup and drop");
  });

  it("words a route deviation and the night checks", () => {
    expect(safetyEventLine({ kind: "DEVIATION", payload: { offM: 1520, night: true, pushed: true } })).toEqual({
      title: "Off route",
      detail: '1520 m from the quoted route at night · rider asked "Is everything OK?"',
    });
    expect(safetyEventLine({ kind: "DEVIATION", payload: { offM: 400, night: false, pushed: false } }).detail).toBe("400 m from the quoted route");
    expect(safetyEventLine({ kind: "NIGHT_CHECK", payload: { check: "NIGHT_START", pushed: true } }).detail).toBe('Night ride: "Share your trip" reminder sent');
    expect(safetyEventLine({ kind: "NIGHT_CHECK", payload: { check: "SAFE_ARRIVAL", answer: "OK" } }).detail).toBe('"Did you reach safely?" sent · rider said OK');
  });
});
