# IoSphere — Firebase Data Contract

This is the single agreement between every ESP32 module and the Flutter app.
**If a path or type is not in this file, don't use it.** Ask the backend team to add it first.

- Firebase project: `iosphere-643dc`
- Database: Realtime Database, `https://iosphere-643dc-default-rtdb.europe-west1.firebasedatabase.app`
- Enforced by: [`firebase/database.rules.json`](../firebase/database.rules.json)

---

## 1. The tree

```
/
├── devices/
│   └── {moduleId}/                 one node per student module, e.g. "parking_module"
│       ├── info/                   who/what this module is              ← ESP32 (on boot)
│       ├── sensors/                latest sensor readings               ← ESP32
│       ├── actuators/              actual state of each actuator        ← ESP32
│       ├── commands/               desired state requested by the user  ← App
│       ├── settings/               thresholds and automation switches   ← App
│       └── status/                 heartbeat and connection info        ← ESP32
├── alerts/
│   └── {pushId}/                   critical events from any module      ← ESP32 creates, App acknowledges
├── history/                        (bonus) past readings for charts
│   └── {moduleId}/{sensorName}/{pushId}/                                ← ESP32
└── users/
    └── {uid}/                      (bonus) user profile and role        ← Firebase console only
```

### Who may write what

| Node | ESP32 (device account) | App (human users) |
|---|---|---|
| `info`, `sensors`, `actuators`, `status` | write | read |
| `commands` | read, and may reset a command | write |
| `settings` | read | write |
| `alerts` | create new | read, set `acknowledged` |
| `history` | create new | read |

---

## 2. Naming rules

- `moduleId`: lowercase `snake_case`, ending in `_module`, e.g. `parking_module`.
- Every key below a module uses **camelCase**, e.g. `slot1Distance`, `nearThreshold`.
- Units are **fixed**, and the key never includes the unit:

  | Quantity | Unit | Example key |
  |---|---|---|
  | Distance | cm (number) | `vehicleDistance`, `slot1Distance` |
  | Time settings | seconds (number) | `crossingTime`, `gateOpenTime` |
  | Detected-type values | `true` / `false` | `crossRequest`, `slot1Occupied` |

- Command and actuator values are UPPERCASE strings from a fixed list:

  | Actuator kind | Allowed values |
  |---|---|
  | On/off devices (LEDs, street light) | `"ON"` / `"OFF"` |
  | Pedestrian signal | `"WALK"` / `"STOP"` |
  | Gate (servo) | `"OPEN"` / `"CLOSED"` |

---

## 3. Each node in detail

### `devices/{moduleId}/info`
Written once by the ESP32 when it boots.

| Key | Type | Example |
|---|---|---|
| `name` | string | `"Smart Parking"` |
| `owner` | string | `"Student name"` |
| `type` | string | `"pedestrian"`, `"lighting"`, `"parking"` (the app picks an icon from this) |
| `firmware` | string | `"1.0.0"` |

### `devices/{moduleId}/sensors`
Latest value only: overwrite it, don't append. Values must be a number, boolean or string.
Send a value every **2–5 s**, or immediately when it changes for event sensors (button, detected, occupied).

### `devices/{moduleId}/actuators`
The **actual** state after the ESP32 applied a command or an automation rule, e.g. `fan: "ON"`.
The app shows this, not `commands`, so the user sees what really happened.

### `devices/{moduleId}/commands`
The **desired** state, written by the app, e.g. `fan: "ON"`.
The ESP32 listens to this node (a stream) and applies changes within a few seconds.
A command keeps its value; it is **not** deleted after it's applied.

### `devices/{moduleId}/settings`
Automation parameters that the user changes in the app. The ESP32 reads them on boot and listens for changes.

| Key | Type | Meaning |
|---|---|---|
| `autoMode` | boolean | `true` = automation rules run; `false` = manual commands only |
| `...Threshold` | number | e.g. `tempThreshold: 35` (fan turns on above 35 °C) |

### `devices/{moduleId}/status`

| Key | Type | Meaning |
|---|---|---|
| `lastSeen` | number (ms since epoch) | **Must be the Firebase server timestamp**, not the ESP32's own clock |
| `rssi` | number (dBm) | WiFi signal strength (optional) |
| `ip` | string | local IP address (optional) |

The ESP32 writes `lastSeen` **every 10 seconds**.
The app shows a module as **offline** when `lastSeen` is more than **30 seconds** old.

### `alerts/{pushId}`
Created by the ESP32 with `push()`, so Firebase generates the ID. Never overwrite an existing alert.

| Key | Type | Example |
|---|---|---|
| `moduleId` | string | `"parking_module"` |
| `type` | string | `"parkingFull"`, `"gateBlocked"`, `"sensorFailure"` (see 6.4) |
| `severity` | string | `"critical"`, `"warning"` or `"info"` |
| `message` | string | `"All 3 parking slots are occupied"` |
| `timestamp` | number | server timestamp (ms) |
| `acknowledged` | boolean | `false` when created; the app sets it to `true` |

Don't flood this node: send **one** alert when a condition starts, not one per loop.

### `history/{moduleId}/{sensorName}/{pushId}` (bonus)
`{ "value": 24.5, "timestamp": <server timestamp> }`, pushed every **60 s** for the sensors you want charts of.

---

## 4. For ESP32 developers

1. **Sign in** with the shared device account `devices@iosphere.app`.
   - Get the password from the backend team.
   - Keep it in `secrets.h` and **never commit that file**.
   - The database rejects any write from a different account.
2. **Server timestamp:** with the *Firebase ESP Client* library use `Firebase.RTDB.setTimestamp(&fbdo, path)`, or with *FirebaseClient* write `{".sv": "timestamp"}`.
3. **Heartbeat:** every 10 s, using `millis()` instead of `delay()`, write `status/lastSeen`.
4. **Listen** to `commands` and `settings` with a stream, instead of polling every loop.
5. **On boot:** write `info`, read `settings`, then start streaming.
6. Any write that doesn't match this contract is **rejected** by the security rules. If a write fails, check the key names and types first.

---

## 5. Example: a complete module

```json
"devices": {
  "lighting_module": {
    "info":      { "name": "Smart Street Lighting", "owner": "Student name", "type": "lighting", "firmware": "1.0.0" },
    "sensors":   { "vehicleDistance": 12.5 },
    "actuators": { "streetLight": "ON" },
    "commands":  { "streetLight": "ON" },
    "settings":  { "autoMode": true, "nearThreshold": 20, "lightOffDelay": 5 },
    "status":    { "lastSeen": 1795000000000, "rssi": -61, "ip": "192.168.1.23" }
  }
}
```

---

## 6. The modules

There are three modules. Each owner checks that their table matches their hardware.
To change a key, tell the backend team; don't just change it in your ESP32 code.

In every module:
- `autoMode = true` means the ESP32 runs the automation below.
- `autoMode = false` means it only follows `commands` sent from the app.
- The ESP32 always reports the real output state in `actuators`.

### 6.1 Pedestrian Crossing: `pedestrian_module`
`info.type = "pedestrian"`

| Node | Key | Type / values | Hardware |
|---|---|---|---|
| sensors | `crossRequest` | bool | push button: a pedestrian asks to cross |
| sensors | `pedestrianDetected` | bool | PIR / IR sensor: a person is waiting at the crossing |
| actuators, commands | `walkSignal` | `"WALK"` / `"STOP"` | pedestrian LEDs: green = WALK, red = STOP |
| settings | `autoMode` | bool | |
| settings | `crossingTime` | number, s | how long WALK stays on |

**Automation:**
1. While `walkSignal = "STOP"`: `crossRequest` **or** `pedestrianDetected` → `walkSignal = "WALK"`.
2. After `crossingTime` seconds → `walkSignal = "STOP"`.

### 6.2 Smart Street Lighting: `lighting_module`
`info.type = "lighting"`

| Node | Key | Type / values | Hardware |
|---|---|---|---|
| sensors | `vehicleDistance` | number, cm | analog IR distance sensor; the ESP32 converts the reading to cm |
| actuators, commands | `streetLight` | `"ON"` / `"OFF"` | street light LEDs |
| settings | `autoMode` | bool | |
| settings | `nearThreshold` | number, cm | a vehicle closer than this counts as "near" |
| settings | `lightOffDelay` | number, s | how long the lights stay on after the vehicle leaves |

**Automation:**
1. `vehicleDistance < nearThreshold` → `streetLight = "ON"`.
2. Once no vehicle is near for `lightOffDelay` seconds → `streetLight = "OFF"`.

### 6.3 Smart Parking: `parking_module`
`info.type = "parking"`

| Node | Key | Type / values | Hardware |
|---|---|---|---|
| sensors | `slot1Distance`, `slot2Distance`, `slot3Distance` | number, cm | one ultrasonic sensor per slot |
| sensors | `gateDistance` | number, cm | ultrasonic sensor at the entrance |
| sensors | `slot1Occupied`, `slot2Occupied`, `slot3Occupied` | bool | worked out by the ESP32: distance < `occupiedDistance` |
| sensors | `carAtGate` | bool | worked out by the ESP32: `gateDistance` < `occupiedDistance` |
| sensors | `freeSlots` | number, 0–3 | worked out by the ESP32 |
| actuators | `slot1Led`, `slot2Led`, `slot3Led` | `"ON"` / `"OFF"` | one LED per slot, ON while a car is parked there |
| actuators, commands | `gate` | `"OPEN"` / `"CLOSED"` | servo barrier |
| settings | `autoMode` | bool | |
| settings | `occupiedDistance` | number, cm | a slot (or the gate) is occupied when the distance is below this |
| settings | `gateOpenTime` | number, s | how long the gate stays open |

**Automation:**
1. Each slot LED follows its slot: `slotNOccupied` → `slotNLed = "ON"`, otherwise `"OFF"`. The slot LEDs always follow the sensors; the app can't control them.
2. `carAtGate` **and** `freeSlots > 0` → `gate = "OPEN"` for `gateOpenTime`, then `"CLOSED"`.
3. `freeSlots == 0` → the gate stays `"CLOSED"`.

### 6.4 Alerts

| type | severity | sent by | when |
|---|---|---|---|
| `parkingFull` | info | parking_module | `freeSlots` becomes 0 |
| `gateBlocked` | warning | parking_module | `carAtGate` while `freeSlots == 0` |
| `sensorFailure` | warning | any module | a sensor gives no valid reading, e.g. ultrasonic timeout or a 0 cm reading |

Send each alert **once**, when its condition starts, and not again until the condition has cleared.
