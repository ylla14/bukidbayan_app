# Crop Calendar Adapter (Local)

This folder contains a minimal in-repo adapter endpoint for crop calendar data
normalized to BukidBayan's canonical crop list.

## Why this exists

There is no direct Philippines-ready API that can be consumed as-is. This
adapter gives us a controllable endpoint that can later be swapped to a hosted
service while preserving app API contract.

Data basis: GEOGLAM/JRC crop calendar open data (CC BY 4.0), normalized for
Philippines farmer-facing crops.

## Run locally

From the repo root:

```powershell
dart run tools/crop_calendar_adapter/bin/server.dart
```

Optional port override:

```powershell
$env:ADAPTER_PORT="8090"
dart run tools/crop_calendar_adapter/bin/server.dart
```

## Endpoints

- `GET /health`
- `GET /v1/crop-calendar?country=PHL&region=philippines&month=1`

## Connect Flutter to adapter

Use the adapter URL as `CROP_CALENDAR_API_URL`:

```powershell
flutter run --dart-define=CROP_CALENDAR_API_URL=http://127.0.0.1:8088/v1/crop-calendar
```

## Next step for production

Replace `data/phl_crop_calendar.json` with a refresh pipeline that ingests
upstream GEOGLAM/JRC files and emits the same response schema.
