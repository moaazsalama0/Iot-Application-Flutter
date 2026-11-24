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
│   └── {moduleId}/                 one node per student module, e.g. "door_module"
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

- `moduleId`: lowercase `snake_case`, ending in `_module`, e.g. `door_module`, `lighting_module`.
- Every key below a module uses **camelCase**, e.g. `temperature`, `gasLevel`, `tempThreshold`.
- Units are **fixed**, and the key never includes the unit:

  | Quantity | Unit | Example key |
  |---|---|---|
  | Temperature | °C (number) | `temperature` |
  | Humidity | % (number, 0–100) | `humidity` |
  | Distance | cm (number) | `distance` |
  | Light level | % (number, 0–100) | `lightLevel` |
  | Gas / smoke | raw ADC (number, 0–4095) | `gasLevel` |
  | Motion / flame / detected-type sensors | `true` / `false` | `motion`, `flame` |

- On/off commands and actuator states use the strings **`"ON"`** / **`"OFF"`**.
  - Locks use **`"LOCKED"`** / **`"UNLOCKED"`**.
  - A servo angle is a number from 0 to 180.

---

## 3. Each node in detail

### `devices/{moduleId}/info`
Written once by the ESP32 when it boots.

| Key | Type | Example |
|---|---|---|
| `name` | string | `"Smart Door"` |
| `owner` | string | `"Student name"` |
| `type` | string | `"door"`, `"lighting"`, `"alarm"`, `"parking"` (the app picks an icon from this) |
| `firmware` | string | `"1.0.0"` |

### `devices/{moduleId}/sensors`
Latest value only: overwrite it, don't append. Values must be a number, boolean or string.
Send a value every **2–5 s**, or immediately when it changes for event sensors (motion, flame).

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
| `armed` | boolean | for security modules: send alerts only while armed |

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
| `moduleId` | string | `"alarm_module"` |
| `type` | string | `"gas"`, `"flame"`, `"highTemperature"`, `"intrusion"` |
| `severity` | string | `"critical"`, `"warning"` or `"info"` |
| `message` | string | `"Gas level 3100 above threshold 2500"` |
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
  "climate_module": {
    "info":      { "name": "Smart Climate", "owner": "Student 2", "type": "climate", "firmware": "1.0.0" },
    "sensors":   { "temperature": 27.4, "humidity": 51 },
    "actuators": { "fan": "OFF", "led": "ON" },
    "commands":  { "fan": "OFF", "led": "ON" },
    "settings":  { "autoMode": true, "tempThreshold": 35 },
    "status":    { "lastSeen": 1795000000000, "rssi": -61, "ip": "192.168.1.23" }
  }
}
```

---

## 6. Registered modules

Each student fills in one row, and the backend team adds the matching keys to this file.

| moduleId | Owner | Sensors (key: type, unit) | Actuators / commands (key: values) | Settings (key: type) |
|---|---|---|---|---|
| `climate_module` *(example)* | — | `temperature`: number °C, `humidity`: number % | `fan`: ON/OFF, `led`: ON/OFF | `autoMode`: bool, `tempThreshold`: number |
| | | | | |
| | | | | |
| | | | | |
| | | | | |
