# Architecture

## Layers

- **App** — entry point, LiDAR gate, dependency wiring (`AppDependencies`)
- **Features** — `Scan` screen and `ScanHistoryViewModel` (snapshots in developer sheet)
- **Domain** — value types, quality/guidance evaluators, use cases (`FinishScan`, `LoadScanHistory`)
- **Data** — AR session, metrics, persistence, logging
- **DesignSystem** — theme and reusable UI components

Navigation uses `NavigationStack` in the app entry. View models do not own navigation state.

## Project structure

```
RoomScanner/
├── App/
├── DesignSystem/
├── Domain/
│   ├── Evaluators/
│   ├── Models/
│   └── UseCases/
├── Data/
│   ├── Logging/
│   └── Services/
├── Features/
│   ├── Scan/
│   └── History/
└── Resources/

RoomScannerTests/
```

## Debugging

Logs use `os.Logger` with subsystem `com.vil4max.roomscanner`:

| Category | What it logs |
|----------|----------------|
| `ARSession` | Session lifecycle, configuration, tracking changes, anchor adds, interruptions |
| `Metrics` | Throttled scan metrics every 2 seconds while recording |
| `Capture` | Scan UI lifecycle, placement, start/finish, persistence |

Filter in Console.app: `subsystem:com.vil4max.roomscanner`

## Third-party assets

`CosmonautSuit_en.reality` — [Apple AR Quick Look sample](https://developer.apple.com/augmented-reality/quick-look/models/cosmonaut/CosmonautSuit_en.reality). Subject to Apple's sample content terms.
