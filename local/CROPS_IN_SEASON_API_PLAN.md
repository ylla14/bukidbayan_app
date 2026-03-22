# Crops In Season Accuracy + API Source-of-Truth Plan

Date: 2026-03-21
Owner: Codex planning pass (no implementation yet)

## Goal
Update the dashboard "Crops in Season" feature so it reflects real farming usage more accurately (using the provided crop calendar), and make the crop dataset API-driven instead of hardcoded.

## Feasibility (Short Answer)
Yes, this is possible.
- The app already has an API hook for crop data via `CROP_CALENDAR_API_URL` in `lib/services/crop_calendar_service.dart`.
- We need to expand the API schema + parsing + UI usage so it supports planting/harvesting windows and your exact crop set.

## Current State (What exists today)
1. Dashboard crop cards are rendered by `lib/components/dashboard/crops_in_season_section.dart`.
2. Data source is `CropCalendarService` in `lib/services/crop_calendar_service.dart`.
3. If API is empty/unavailable, service falls back to hardcoded SEA seed data (Rice/Corn/Tomato/Eggplant/etc.) in `_fallbackSeaCalendar()`.
4. Current model only stores:
   - `name`
   - `seasons`
   - `regions`
   - `imageUrl`
5. Planting phase, harvesting phase, and agronomic notes are not modeled.
6. The dashboard calendar feature (`lib/services/dashboard_calendar_service.dart`) also consumes crop-season data for seasonal suggestions, so changes here can affect both home crop cards and smart calendar hints.
7. No dedicated tests currently cover:
   - `CropsInSeasonSection` behavior
   - API parsing in `CropCalendarService`

## Target Dataset To Support
From your specification:
- Wet Season: Rice (Wet Season)
- Dry Season: Rice (Dry Season), Tomato, Watermelon, Squash
- Year-Round: White Corn, Pechay, Upo (Bottle Gourd), Eggplant, Banana
- Each crop includes:
  - planting phase/month window
  - harvesting phase/month window or day-offset window
  - notes

## Proposed Architecture
### Recommended Option A (Primary): External REST API as source-of-truth
1. Keep `CROP_CALENDAR_API_URL`.
2. Expand API response schema to include agronomic fields.
3. Parse and normalize server payload in `CropCalendarService`.
4. Keep minimal local fallback only for outage resiliency.

Suggested response schema (example):
```json
[
  {
    "name": "Rice (Wet Season)",
    "regions": ["philippines"],
    "seasons": ["Wet Season"],
    "plantingMonths": [6,7],
    "harvestMonths": [10,11],
    "notes": "Main Crop. Rain-fed or irrigated.",
    "imageUrl": "https://..."
  }
]
```

### Option B (Fallback strategy if backend API is delayed): Firestore config document
- Store crop calendar in Firestore (`app_config/crop_calendar`) and fetch client-side.
- Requires Firestore rules update for `app_config` reads.
- Faster to ship but less clean than a true API and harder to version externally.

## Functional Changes Planned (No code yet)
1. Upgrade crop model to include phase windows and notes.
2. Update API parser to accept/validate these new fields.
3. Replace current fallback list with your crop set (only as outage fallback).
4. Update `CropsInSeasonSection` filtering logic:
   - current month can show phase-aware labels (Planting/Harvesting/Year-round)
   - keep Wet/Dry/Year Round chips
5. Keep compatibility with `DashboardCalendarService` seasonal suggestions.
6. Add tests for parsing + filtering + month/season behavior.

## Phase Plan
### Phase 1: Contract + Taxonomy Alignment
- Define canonical crop names and aliases (important for `Squash` vs `Squash/Upo`, `Upo` vs `Bottle Gourd`, etc.).
- Lock API contract for required/optional fields.
- Decide how day-based windows (e.g., 30-45 days) are represented in UI text.

### Phase 2: Service Layer Upgrade
- Extend `CropSeasonItem` (or introduce a richer DTO/model).
- Implement robust parsing/validation/defaulting in `CropCalendarService`.
- Keep graceful fallback when API fails.

### Phase 3: UI Update (Dashboard Home)
- Update `CropsInSeasonSection` card content and filters to use new fields.
- Preserve current look/flow unless we intentionally change UX.

### Phase 4: Calendar Integration Check
- Ensure `DashboardCalendarService` still receives season-compatible outputs.
- Confirm seasonal planning suggestions remain correct.

### Phase 5: Tests + Verification
- Add unit tests for API parsing and season/phase filtering.
- Add widget tests for "Crops in Season" month/category rendering.
- Regression test smart calendar seasonal text.

## Files To Analyze / Modify / Reference
### Core files to modify (planned)
1. `lib/services/crop_calendar_service.dart`
2. `lib/components/dashboard/crops_in_season_section.dart`
3. `lib/services/dashboard_calendar_service.dart` (only if model/shape changes require adaptation)

### Supporting files likely to modify
1. `lib/models/dashboard_calendar.dart` (if richer crop context is propagated)
2. `test/dashboard_calendar_service_test.dart` (update/add seasonal assertions)
3. `test/dashboard_calendar_section_test.dart` (regression if seasonal text behavior changes)
4. New tests (planned):
   - `test/crop_calendar_service_test.dart`
   - `test/crops_in_season_section_test.dart`

### Files to reference (context dependencies)
1. `lib/screens/dashboard/home_screen.dart` (section composition)
2. `lib/models/crop_preference.dart` (onboarding crop taxonomy alignment)
3. `lib/services/firestore_service.dart` (`getCropPreferences` if we later personalize by user crops)
4. `firestore.rules` (if Option B / Firestore source-of-truth is used)
5. `lib/main.dart` (if any seeding/config bootstrap is introduced)
6. `pubspec.yaml` (already has `http`; confirm no new dependency needed)

## Risks / Decisions Needing Confirmation Before Implementation
1. Source-of-truth choice:
   - A: REST API (recommended)
   - B: Firestore config doc (faster fallback)
2. Name normalization policy:
   - keep user-facing names exactly as provided
   - or map aliases into canonical internal keys
3. Scope for first release:
   - only dashboard crops section
   - or include smart calendar seasonal text updates at same time
4. Should we personalize "Crops in Season" by user onboarding crop preferences in addition to regional seasonality?

## Acceptance Criteria (Implementation Ready)
1. Dashboard crop list for Philippines reflects the provided crop schedule accurately by month/season.
2. Crop data comes from API (not hardcoded primary path).
3. App remains resilient if API fails (fallback path works).
4. Seasonal suggestions in dashboard calendar remain correct.
5. New/updated tests cover parsing and filtering logic.

## Suggested Execution Order (when you approve implementation)
1. Finalize API schema + naming map
2. Update service model/parsing
3. Update crops section UI/filter behavior
4. Add/adjust calendar compatibility logic
5. Add tests + run `flutter test`

