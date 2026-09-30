#!/usr/bin/env python3
"""Books up to 4 test trips (rides or parcels) from test riders near a driver on staging, to watch requests arrive
and stack in the driver app.

  python3 scripts/book_test_trips.py book [LAT LNG] [--driver PHONE|ID] [--vehicle KIND] [--parcel | --mix]
                                          [--gap SECONDS] [--count N] [--extra RUPEES] [--extra-after SECONDS]
      --driver   whose requests to test (default Arun 9100000101, a cab); the trip type follows that driver's
                 vehicle: goods drivers get parcels, bike / auto / cab drivers get rides
      --vehicle  book this vehicle instead (BIKE, AUTO, CAB, GOODS_BIKE, THREE_WHEELER, MINI_TRUCK, PICKUP, TRUCK)
      --parcel   a bike driver: goods-bike parcels instead of rides (parcel on bike)
      --mix      a bike driver: rides and goods-bike parcels in turn (a mixed request stack)
      LAT LNG    around this spot, else the driver's live GPS on staging (go online in the app first)
      --gap      one trip every SECONDS (default 5; 0 = all at once); --count N trips (default 4, max 4)
      --extra    then the rider adds this much extra to each trip still searching (e.g. 20), after
                 --extra-after SECONDS (default 8)
  python3 scripts/book_test_trips.py cancel     # cancels every searching / assigned trip of these riders

Needs the staging SSH key (~/.ssh/rido-key.pem): the sign-in code (DEV_OTP_CODE) and the driver's position are read
on the server. TT_OTP=<code> skips reading the code.
"""
import json
import os
import shlex
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

API = "https://api.65-0-233-253.sslip.io/v1"
SERVER = "ubuntu@65.0.233.253"
RIDERS = [
    ("+918825945628", "Dhivya prabha"),
    ("+919200000002", "Test Rider Kavya"),
    ("+919200000003", "Test Rider Ravi"),
    ("+919200000004", "Test Rider Lakshmi"),
]
DROPS = [
    (11.0183, 76.9725, "Gandhipuram Central Bus Stand"),
    (11.0250, 77.0020, "Peelamedu"),
    (10.9925, 76.9614, "Ukkadam Bus Stand"),
    (11.0090, 76.9600, "Brookefields Mall"),
]
# Pickups a few hundred metres to ~1 km around the driver (lat, lng offsets).
OFFSETS = [(0.003, 0.002), (-0.004, 0.003), (0.006, -0.004), (-0.002, -0.007)]
RIDE_KINDS = ("BIKE", "AUTO", "CAB")
GOODS_KINDS = ("GOODS_BIKE", "THREE_WHEELER", "MINI_TRUCK", "PICKUP", "TRUCK")
# A parcel that fits the vehicle: (category, weight band) per trip.
PARCELS = {
    "GOODS_BIKE": [("documents", "under5"), ("food", "under5"), ("clothes", "from5to20"), ("electronics", "under5")],
    "THREE_WHEELER": [("household", "from20to100"), ("electronics", "from20to100"), ("food", "from5to20"), ("other", "from20to100")],
    "MINI_TRUCK": [("furniture", "from100to500"), ("household", "from100to500"), ("other", "from100to500"), ("electronics", "from20to100")],
    "PICKUP": [("furniture", "from100to500"), ("household", "from100to500"), ("other", "from100to500"), ("furniture", "from100to500")],
    "TRUCK": [("furniture", "over500"), ("household", "over500"), ("other", "over500"), ("furniture", "from100to500")],
}
RECEIVERS = [("Meena", "9300000001"), ("Raja", "9300000002"), ("Sathya", "9300000003"), ("Hari", "9300000004")]


def call(method, path, body=None, token=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read()
            return r.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def on_server(cmd):
    key = os.path.expanduser("~/.ssh/rido-key.pem")
    run = subprocess.run(["ssh", "-4", "-i", key, SERVER, cmd], capture_output=True, text=True, timeout=30)
    if run.returncode == 255:
        sys.exit(f"Can't reach the server over SSH: {run.stderr.strip()} (is your IP allowed in rido-sg?)")
    return run.stdout.strip()


_otp = None


def otp_code():
    """Staging only accepts its secret dev code (DEV_OTP_CODE in /opt/tamiltaxi/.env)."""
    global _otp
    if _otp is None:
        _otp = os.environ.get("TT_OTP") or on_server("grep '^DEV_OTP_CODE=' /opt/tamiltaxi/.env | cut -d= -f2- | tr -d '\"'")
        if not _otp:
            sys.exit("No DEV_OTP_CODE on the server: set TT_OTP=<code>")
    return _otp


def find_driver(ref):
    """(driver id, name, vehicle kind) for a phone number (any format) or a driver id."""
    digits = "".join(ch for ch in ref if ch.isdigit())
    where = f"u.phone = '+91{digits[-10:]}'" if len(digits) >= 10 else f"d.id = '{ref}'"
    sql = f'select d.id, u.name, d."vehicleKind" from "Driver" d join "User" u on u.id = d."userId" where {where}'
    row = on_server("docker exec tamiltaxi-postgres-1 psql -U tamiltaxi -d tamiltaxi -tAc " + shlex.quote(sql))
    if not row:
        sys.exit(f"No driver found for {ref}")
    driver_id, name, kind = row.split("|")
    return driver_id, name, kind


def driver_position(driver_id):
    """The driver's last GPS fix from staging Redis (lat, lng), or exits if they're not online."""
    raw = on_server(f"docker exec tamiltaxi-redis-1 redis-cli get driver:alive:{driver_id}")
    if not raw:
        sys.exit(f"{driver_id} has no live position: go online in the app first (or pass LAT LNG)")
    lat, lng = raw.split(",")[:2]
    return float(lat), float(lng)


def login(phone, name):
    call("POST", "/auth/otp", {"phone": phone})
    status, res = call("POST", "/auth/verify", {"phone": phone, "code": otp_code()})
    if status != 200:
        sys.exit(f"Sign-in for {name} failed: {status} {res.get('message') if res else ''}")
    token = res["accessToken"]
    call("PATCH", "/me", {"name": name}, token)
    return token


def trip_body(i, lat, lng, vehicle, rider):
    dlat, dlng = OFFSETS[i]
    pickup = {"lat": lat + dlat, "lng": lng + dlng, "name": f"Test pickup {i + 1}"}
    d = DROPS[i]
    drop = {"lat": d[0], "lng": d[1], "name": d[2]}
    if vehicle in RIDE_KINDS:
        return {"kind": "RIDE", "vehicleKind": vehicle, "pickup": pickup, "drop": drop}
    category, weight = PARCELS[vehicle][i]
    receiver, receiver_phone = RECEIVERS[i]
    parcel = {
        "category": category,
        "weight": weight,
        "senderName": rider[1],
        "senderPhone": rider[0],
        "receiverName": receiver,
        "receiverPhone": receiver_phone,
        "pickupNote": "Test parcel, call on arrival",
        "dropNote": "",
        "hasPhoto": False,
    }
    return {"kind": "PARCEL", "vehicleKind": vehicle, "pickup": pickup, "drop": drop, "parcel": parcel, "payer": "SENDER"}


def book(lat, lng, vehicles, gap=5.0, extra=0, extra_after=8.0):
    riders = RIDERS[: len(vehicles)]
    tokens = [login(p, n) for p, n in riders]
    results = [None] * len(riders)

    def one(i):
        results[i] = call("POST", "/trips", trip_body(i, lat, lng, vehicles[i], riders[i]), tokens[i])

    def report(i):
        name = riders[i][1]
        status, body = results[i]
        stamp = time.strftime("%H:%M:%S")
        if status == 201:
            what = "parcel" if body["kind"] == "PARCEL" else "ride"
            print(f"{stamp}  {name}: {vehicles[i]} {what} {body['id']} · ₹{body['fareTotal']} · "
                  f"{body['distanceKm']:.1f} km → {body['dropName']}", flush=True)
        else:
            print(f"{stamp}  {name}: {status} {body.get('message')}", flush=True)

    if gap <= 0:
        threads = [threading.Thread(target=one, args=(i,)) for i in range(len(riders))]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        for i in range(len(riders)):
            report(i)
    else:
        for i in range(len(riders)):
            if i:
                print(f"          … next trip in {gap:g} s", flush=True)
                time.sleep(gap)
            one(i)
            report(i)

    if extra > 0:
        print(f"          … adding ₹{extra} extra in {extra_after:g} s to trips still searching", flush=True)
        time.sleep(extra_after)
        for i, (status, body) in enumerate(results):
            if status != 201:
                continue
            s, res = call("POST", f"/trips/{body['id']}/extra", {"amount": extra}, tokens[i])
            stamp = time.strftime("%H:%M:%S")
            if s == 200:
                print(f"{stamp}  {riders[i][1]}: +₹{extra} extra → ₹{res['fareTotal']}", flush=True)
            else:
                print(f"{stamp}  {riders[i][1]}: extra {s} {res.get('message')}", flush=True)


def cancel():
    for phone, name in RIDERS:
        token = login(phone, name)
        _, trips = call("GET", "/trips", token=token)
        for t in trips or []:
            if t["status"] in ("SEARCHING", "DRIVER_ASSIGNED", "DRIVER_ARRIVED"):
                status, _ = call("POST", f"/trips/{t['id']}/cancel", {}, token)
                print(f"{name}: cancelled {t['id']} ({status})")


def vehicles_for(kind, args, count):
    """The vehicle of each trip: the driver's own (or --vehicle), goods-bike parcels for a bike with --parcel, or
    rides and parcels in turn with --mix."""
    def opt(flag, default):
        return args[args.index(flag) + 1] if flag in args else default

    vehicle = opt("--vehicle", kind).upper()
    if vehicle not in RIDE_KINDS + GOODS_KINDS:
        sys.exit(f"Unknown vehicle {vehicle}")
    if "--parcel" in args or "--mix" in args:
        if vehicle != "BIKE":
            sys.exit("--parcel and --mix are for bike drivers (bikes take goods-bike parcels too)")
        if "--mix" in args:
            return [("BIKE" if i % 2 == 0 else "GOODS_BIKE") for i in range(count)]
        vehicle = "GOODS_BIKE"
    return [vehicle] * count


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["cancel"]:
        cancel()
    elif args[:1] == ["book"] or not args:
        def opt(flag, default):
            return args[args.index(flag) + 1] if flag in args else default

        driver_id, name, kind = find_driver(opt("--driver", "9100000101"))
        count = min(4, max(1, int(opt("--count", 4))))
        vehicles = vehicles_for(kind, args, count)
        nums = [a for a in args[1:3] if not a.startswith("--")]
        lat, lng = (float(nums[0]), float(nums[1])) if len(nums) == 2 else driver_position(driver_id)
        print(f"{' / '.join(dict.fromkeys(vehicles))} trips for {name} ({kind}) around {lat:.5f}, {lng:.5f}", flush=True)
        book(lat, lng, vehicles, gap=float(opt("--gap", 5.0)), extra=int(opt("--extra", 0)),
             extra_after=float(opt("--extra-after", 8.0)))
    else:
        sys.exit(__doc__)
