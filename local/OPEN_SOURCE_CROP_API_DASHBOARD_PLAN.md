# Open-Source Crop API + Dashboard Calendar Integration Plan (No Implementation Yet)

Date: 2026-03-21
Status: Planning only

## Objective
Move BukidBayan crop-season logic away from local hardcoded lists toward an open-data-backed API flow, and ensure both:
1) Home "Crops in Season" cards
2) Dashboard Smart Calendar seasonal suggestions/events
are driven from the same source of truth.

## Key Clarification
There is no reliable plug-and-play Philippines-specific public crop-calendar API that can be consumed directly today.
So the practical approach is:
- Use open-source/open-license crop calendar datasets as upstream source.
- Build a thin API adapter layer we control.
- Point the app to that adapter endpoint via `CROP_CALENDAR_API_URL`.

## Open Data Source Candidates (for adapter input)
### Primary candidate (recommended)
1. GEOGLAM/JRC Crop Calendars (open dataset, CC BY 4.0)
- Record: https://gkhub.earthobservations.org/records/9qpxr-52p90
- Provides links to national/subnational crop-calendar files (`crop_calendar_gaul0.zip`, `crop_calendar_gaul1.zip`).
- Includes planting/growing/harvesting windows in dekads.

### Secondary candidate (reference/validation)
2. JRC data catalog dataset page
- https://data.jrc.ec.europa.eu/dataset/jrc-10112-10003

3. World Bank catalog mirror/derivative metadata (for API service patterns and validation)
- https://datacatalog.worldbank.org/search/dataset/0066842/crop-calendar-for-africa

## Proposed Architecture
### A. Data Adapter API (new backend component)
Build a small service that:
1. Fetches latest open dataset files on schedule/manual trigger.
2. Parses CSV/dekad windows to month windows.
3. Filters to Philippines + crops we support in-app.
4. Publishes a normalized JSON endpoint consumed by Flutter.

Suggested normalized endpoint:
- `GET /v1/crop-calendar?country=PHL&region=philippines&month=1`

Suggested response shape:
```json
[
  {
    "name": "Rice (Wet Season)",
    "canonicalKey": "rice_wet",
    "regions": ["philippines"],
    "seasons": ["Wet Season"],
    "plantingMonths": [6,7],
    "harvestingMonths": [10,11],
    "plantingPhase": "June-July",
    "harvestingPhase": "October-November",
    "notes": "...",
    "source": {
      "provider": "GEOGLAM/JRC",
      "version": "2025-01-02",
      "license": "CC-BY-4.0"
    }
  }
]
```

### B. Flutter App Integration
- Keep app API entrypoint via `--dart-define=CROP_CALENDAR_API_URL=...`.
- `CropCalendarService` remains client boundary.
- Both Home crop cards and Dashboard Calendar use the same service output.

## How To Connect With Dashboard Calendar (Important)
Current dashboard calendar uses only season buckets (`Wet/Dry/Year Round`) and derives `seasonalCrops` as names.
To make it truly aligned with open-data timing, we should upgrade dashboard context to be month-aware.

### Planned model/service upgrades
1. Extend dashboard context model to carry month-level crop availability map.
- Add `cropsByMonth` map keyed by month number (`1..12`) with crop names.
- Keep `cropsBySeason` for backward compatibility.

2. In `DashboardCalendarService`:
- Build `cropsByMonth` from `CropSeasonItem.plantingMonths` + `harvestingMonths` + year-round rules.
- For each day in calendar rendering, derive crop context by day.month first; fall back to season only if missing.
- Update season/event subtitles and suggestions to use month-accurate crop list.

3. In `DashboardCalendarSection` UI:
- No major layout rewrite needed.
- Optionally enhance selected-day panel to show month-specific crop context label.

## Data Mapping Rules (Normalization)
Because dataset crop names and app names differ, define a canonical mapping table in adapter:
1. Rice (wet-season cycle) -> `rice_wet`
2. Rice (dry-season cycle) -> `rice_dry`
3. White corn -> `white_corn`
4. Squash -> `squash`
5. Upo / Bottle gourd -> `upo_bottle_gourd`
6. Pechay -> `pechay`
7. Eggplant -> `eggplant`
8. Tomato -> `tomato`
9. Watermelon -> `watermelon`
10. Banana -> `banana`

If upstream has different names, adapter translates to app canonical keys + display names.

## Implementation Phases (when approved)
### Phase 1: Adapter specification and source validation
- Finalize source files, update cadence, and parser assumptions.
- Document license attribution and required credits.

### Phase 2: Build adapter endpoint
- Implement ingestion + normalization + JSON API endpoint.
- Add endpoint-level tests for schema and month conversion.

### Phase 3: Flutter service wiring
- Point `CROP_CALENDAR_API_URL` to adapter.
- Keep app fallback as safety net only.

### Phase 4: Dashboard calendar month-aware integration
- Add `cropsByMonth` in models/service.
- Update calendar event/suggestion generation to use month-specific crops.

### Phase 5: Validation and regression tests
- Add tests for:
  - adapter payload parsing in app
  - crops-by-month mapping
  - dashboard calendar seasonal text correctness by month
  - home crops section + calendar consistency

## Files To Analyze / Modify / Add
### Existing Flutter files (analyze/modify)
1. `lib/services/crop_calendar_service.dart`
2. `lib/components/dashboard/crops_in_season_section.dart`
3. `lib/services/dashboard_calendar_service.dart`
4. `lib/models/dashboard_calendar.dart`
5. `lib/components/dashboard/dashboard_calendar_section.dart` (if display tweaks added)
6. `lib/screens/dashboard/home_screen.dart` (for dependency wiring if needed)
7. `test/dashboard_calendar_service_test.dart`
8. `test/dashboard_calendar_section_test.dart`
9. `test/crop_calendar_service_test.dart`
10. `test/crops_in_season_section_test.dart`

### New backend/adapter artifacts (planned)
1. `tools/crop_calendar_adapter/` (or dedicated backend repo)
2. Parser script for GEOGLAM/JRC CSV/ZIP ingestion
3. Normalization map file (`canonical_crop_map.json`)
4. API route implementation (`/v1/crop-calendar`)
5. Adapter tests + source metadata docs

## Deployment / Ops Plan (High-level)
1. Host adapter on lightweight endpoint (Cloud Run / Render / Railway / VPS).
2. Daily or weekly refresh job.
3. Publish health endpoint and last-refresh metadata.
4. Set Flutter runtime env:
- `--dart-define=CROP_CALENDAR_API_URL=https://<adapter>/v1/crop-calendar`

## Risks and Mitigations
1. Upstream schema changes
- Mitigation: strict adapter tests + validation + fallback dataset in app.

2. Name mismatch across sources
- Mitigation: canonical mapping table and alias handling.

3. Region granularity mismatch
- Mitigation: start with `country=PHL`; add subregional filtering later.

4. Calendar regression risk
- Mitigation: keep `cropsBySeason` compatibility while introducing `cropsByMonth`.

## Acceptance Criteria
1. App no longer relies on hardcoded list as primary source.
2. `CROP_CALENDAR_API_URL` points to adapter backed by open-source dataset.
3. Home crops and dashboard calendar reflect month-accurate crop context from same API payload.
4. Calendar suggestions use month/day-derived crop context (not only wet/dry buckets).
5. Automated tests pass for service, home crops, and dashboard calendar flows.

## Notes for next execution step
When implementation starts, first deliver a minimal adapter endpoint + one integration test in app, then connect dashboard calendar month mapping in a second PR-sized change to reduce risk.
