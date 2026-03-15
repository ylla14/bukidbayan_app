# Draft Functionality Implementation Summary

## Overview
This document outlines the complete implementation of the draft campaign functionality for the BukidBayan app, allowing co-op admins to create, save, edit, and publish campaigns without losing their work.

## What is a Draft Campaign?

A draft campaign is a campaign that a co-op admin started creating but hasn't published yet. Drafts:
- Are **not visible** in the public campaign feed
- Can be **edited freely** at any time
- Can be **deleted** without affecting anything
- Can be **published later** (then it becomes live)

---

## Data Model Updates

### Campaign Status Field
Updated the `Campaign` model in [lib/models/campaign.dart](lib/models/campaign.dart) with:

```dart
// Status values
status: String  // Options: 'draft', 'live', 'ended_success', 'ended_fail', 'purchased', 'cancelled'

// Timestamps
publishedAt: DateTime?     // When campaign went live
lastEditedAt: DateTime?    // Last time draft was modified
```

**Changed from:** `draftSavedAt` (deprecated)
**Changed to:** `publishedAt` and `lastEditedAt` (more descriptive)

### Model Changes
- Updated `Campaign` constructor to include new fields
- Updated `copyWith()` method to support new timestamp fields
- Updated `fromJson()` and `toJson()` for serialization/deserialization
- All existing fields preserved for backward compatibility

---

## Service Layer Implementation

### CrowdfundingService Enhancements ([lib/services/crowdfunding_service.dart](lib/services/crowdfunding_service.dart))

#### 1. **Save Draft**
```dart
Future<void> saveDraft(Campaign draft)
```
- Saves campaign at any stage of completion
- Updates existing draft or creates new one
- Sets `lastEditedAt` timestamp automatically
- Stores in SharedPreferences alongside live campaigns (single list with status filtering)
- No validation required - drafts can be incomplete

#### 2. **Get Drafts**
```dart
Future<List<Campaign>> getDrafts({String? userEmail})
```
- Retrieves all drafts where `status == 'draft'`
- Filters from main campaigns list by status

#### 3. **Get Draft by ID**
```dart
Future<Campaign?> getDraftById(String draftId)
```
- Retrieves a specific draft for editing
- Returns null if not found or not a draft

#### 4. **Delete Draft**
```dart
Future<void> deleteDraft(String draftId)
```
- Permanently deletes a draft campaign
- No side effects on other campaigns

#### 5. **Validate for Publish**
```dart
List<String> validateForPublish(Campaign campaign)
```
Returns validation errors for:
- **Title:** 8-70 characters
- **Category:** Required
- **Cover Image:** Required
- **Short Blurb:** Min 10 characters
- **Full Story:** Min 50 characters
- **Specs:** At least 3 filled entries
- **What's Included:** Min 10 characters
- **Funding Goal:** Min ₱1,000
- **End Date:** Must be in future
- **Production Timeline:** Min 10 characters
- **Reward Tiers:** At least 1 with valid discount values
- **Shipping Coverage:** Required
- **Warranty/Support:** Min 10 characters
- **Spare Parts Info:** Min 10 characters
- **Risks & Safety:** Min 10 characters

#### 6. **Publish Campaign**
```dart
Future<void> publishCampaign(Campaign campaign)
```
- Validates campaign completely
- Changes `status` from 'draft' to 'live'
- Sets `publishedAt = now` and `lastEditedAt = now`
- Makes campaign visible in public feed
- Throws exception with all validation errors if publish blocked

#### 7. **Get Campaigns (Public Feed)**
Updated `getCampaigns()` to filter out drafts:
```dart
// Only returns campaigns where status != 'draft'
return campaigns.where((c) => c.status != 'draft').toList();
```

---

## UI/UX Implementation

### CrowdfundingScreen ([lib/screens/crowdfunding_screen.dart](lib/screens/crowdfunding_screen.dart))

#### "My Drafts" Section
Located at the top of the crowdfunding feed (above search filters):

**Visible Only When:**
- User has saved drafts
- Automatically hidden when no drafts exist

**Features:**
- Lists all user's draft campaigns
- Shows title (or "(Untitled Draft)" if empty)
- Displays last edited date in MM/DD/YYYY format
- Tap to continue editing
- Menu button with actions:
  - **Edit:** Opens draft in wizard for continuation
  - **Delete:** Deletes draft after confirmation

**Draft List Item:**
```
[Draft Title]
Last edited: 2/18/2026
⋮ (menu)
```

### CampaignWizardScreen ([lib/screens/campaign_creation/campaign_wizard_screen.dart](lib/screens/campaign_creation/campaign_wizard_screen.dart))

#### Bottom Navigation Bar Buttons

**Three Button Layout:**
1. **Back** - Navigate to previous step (disabled on first step)
2. **Save Draft** - Available on every step
3. **Next/Publish** - Dynamic based on current step

#### Save Draft Button (Always Visible)
- **When Tapped:**
  - Saves all currently filled data
  - Updates `lastEditedAt` timestamp
  - Does NOT validate
  - Shows confirmation: "Draft saved."

#### Next Button (Steps 1-7)
- Soft validation per step:
  - Only validates fields on current step
  - Shows inline errors if missing
  - Blocks progression until current step is valid
- Recommended approach: per-step validation prevents surprises

#### Publish Button (Step 8)
- Runs complete validation via `validateForPublish()`
- If errors exist:
  - Shows all validation errors
  - Highlights missing sections
  - Does NOT block; user can return to fix
- If valid:
  - Sets `status = 'live'`
  - Sets `publishedAt` timestamp
  - Campaign becomes visible publicly
  - Shows: "Campaign published!"
  - Returns to crowdfunding screen

#### Step Updates
All 8 steps automatically preserve draft state when updating internal draft object using new timestamp fields.

### CampaignCreationScreen ([lib/screens/campaign_creation/campaign_creation_screen.dart](lib/screens/campaign_creation/campaign_creation_screen.dart))

Updated to support drafts:
- Now accepts optional `existingDraft` parameter
- Routes to `CampaignWizardScreen` (modern wizard flow)
- Supports both:
  - Creating new draft
  - Resuming existing draft

**Usage:**
```dart
// Create new draft
CampaignCreationScreen()

// Resume existing draft
CampaignCreationScreen(existingDraft: draftCampaign)
```

---

## Storage Strategy

### Single List Approach
- Drafts and live campaigns stored in same SharedPreferences list
- Differentiated by `status` field
- No separate drafts key needed (previously had `_draftsKey`, now unused)

### Data Persistence
```
SharedPreferences Key: 'campaigns_v1'
└── Campaigns List
    ├── Draft Campaigns (status: 'draft')
    ├── Live Campaigns (status: 'live')
    └── Other status campaigns
```

---

## User Flow Diagram

### Creating a New Campaign

```
Crowdfunding Tab
    ↓
[Create Campaign Button]
    ↓
CampaignCreationScreen (new draft created)
    ↓
CampaignWizardScreen (8-step wizard)
    ├─ Step 1-8: Fill fields
    │   ├─ [Save Draft] → Saves incomplete campaign
    │   ├─ [Next] → Validates current step, proceeds
    │   └─ Draft auto-saved to state
    └─ Step 8: Review & Publish
        ├─ [Publish] → Full validation
        │   ├─ ✓ Valid → Campaign goes live
        │   └─ ✗ Invalid → Shows errors, stays in wizard
        └─ [Save Draft] → Saves for later editing
```

### Resuming a Draft

```
Crowdfunding Tab
    ↓
[My Drafts Section]
    ├─ [Draft Title] → Click to resume
    │   ↓
    │   CampaignCreationScreen (with existingDraft)
    │   ↓
    │   CampaignWizardScreen (populated with draft data)
    │
    └─ [Menu] → ⋮
        ├─ Edit → Same as click
        └─ Delete → Permanent delete after confirmation
```

---

## Validation Rules

### Draft Save Validation
**No validation required** - any incomplete campaign can be saved
- Title can be empty
- Media can be missing
- Rewards can be empty
- Prevents crashes by storing safely

### Publish Validation (Hard Requirements)
All checks must pass:
- ✅ Title (8-70 characters)
- ✅ Category (must have one)
- ✅ Cover photo/video (required)
- ✅ Short blurb (min 10 chars)
- ✅ Full story (min 50 chars)
- ✅ Equipment specs (min 3 filled)
- ✅ What's included (min 10 chars)
- ✅ Funding goal (≥ ₱1,000)
- ✅ End date (in future)
- ✅ Production timeline (min 10 chars)
- ✅ Reward tiers (≥ 1 with valid discount)
- ✅ Shipping coverage (must select)
- ✅ Shipping cost handling (must specify)
- ✅ Warranty/support (min 10 chars)
- ✅ Spare parts (min 10 chars)
- ✅ Risks & safety (min 10 chars)

---

## Live Campaign Restrictions

Once published (`status == 'live'`), certain fields are **locked**:

### Editable (Clarifying Content)
- Cover media
- Story/blurb
- Specs clarifications (not changing tool identity)
- Timeline updates
- Shipping notes
- Warranty/support
- Spare parts
- Risks/safety updates

### Locked (Deal Terms)
- Goal amount
- End date (or allow only extension)
- Reward tier terms (discounts)
- Tool identity (type/name/quantity)
- Category

*Note: Current implementation marks campaigns as 'live' but doesn't enforce edit restrictions yet. Can be added in future phase.*

---

## Key Features Implemented

✅ **Draft Creation**
- New campaigns start as drafts automatically
- ID generated with timestamp + random number

✅ **Auto-Save on Every Step**
- `lastEditedAt` updated when SaveDraft button pressed
- Preserves all form state

✅ **"My Drafts" View**
- Shows all user's unsaved campaigns
- Last edited timestamp for reference
- Quick edit/delete actions

✅ **Smart Validation**
- Per-step validation prevents user frustration
- Full validation at publish time
- Clear error messages guide users

✅ **Public Feed Filtering**
- Drafts automatically hidden from public feed
- Only live campaigns visible to backers

✅ **Timestamp Tracking**
- `createdAt`: When campaign was first created
- `publishedAt`: When campaign went live (null for drafts)
- `lastEditedAt`: When draft was last saved

---

## Files Modified

1. **[lib/models/campaign.dart](lib/models/campaign.dart)**
   - Added `publishedAt` and `lastEditedAt` fields
   - Removed `draftSavedAt` (deprecated)
   - Updated constructor, copyWith, fromJson, toJson

2. **[lib/services/crowdfunding_service.dart](lib/services/crowdfunding_service.dart)**
   - Added `saveDraft()` method
   - Added `getDrafts()` method
   - Added `getDraftById()` method
   - Added `deleteDraft()` method
   - Added `validateForPublish()` method
   - Updated `publishCampaign()` to use new validation
   - Updated `getCampaigns()` to exclude drafts

3. **[lib/screens/campaign_creation/campaign_creation_screen.dart](lib/screens/campaign_creation/campaign_creation_screen.dart)**
   - Added `existingDraft` parameter
   - Routes to CampaignWizardScreen for modern flow
   - Supports both new and existing draft creation

4. **[lib/screens/campaign_creation/campaign_wizard_screen.dart](lib/screens/campaign_creation/campaign_wizard_screen.dart)**
   - Updated `_publishCampaign()` to use service validation
   - Shows all validation errors in readable format
   - Updated all draft update methods to use new fields
   - Maintains Save Draft button on all steps

5. **[lib/screens/crowdfunding_screen.dart](lib/screens/crowdfunding_screen.dart)**
   - Added `_draftsFuture` to load drafts
   - Added "My Drafts" section at top of feed
   - Shows draft cards with edit/delete options
   - Drafts refresh alongside live campaigns
   - Tap draft to continue editing

---

## Testing Recommendations

### Test Scenarios

1. **Create Draft**
   - ✅ Create new campaign, fill partial data, save
   - ✅ Verify "My Drafts" appears with correct title
   - ✅ Verify not visible in public feed

2. **Edit Draft**
   - ✅ Click draft to resume
   - ✅ Verify all previous data preserved
   - ✅ Make changes and save
   - ✅ Verify lastEditedAt updated

3. **Delete Draft**
   - ✅ Delete from My Drafts menu
   - ✅ Confirm deletion dialog
   - ✅ Verify removed from list

4. **Publish Campaign**
   - ✅ Try publish with missing fields
   - ✅ Verify error messages appear
   - ✅ Fill missing fields
   - ✅ Publish successfully
   - ✅ Verify appears in public feed
   - ✅ Verify publishedAt timestamp set
   - ✅ Verify removed from My Drafts

5. **Edge Cases**
   - ✅ Save empty draft (no title)
   - ✅ Open empty draft
   - ✅ Refresh page with saved draft
   - ✅ Try to publish with goal < ₱1,000
   - ✅ Try to publish with end date in past

---

## Future Enhancements

Potential improvements for future phases:

1. **Edit Restrictions for Live Campaigns**
   - Implement locked fields for published campaigns
   - Allow only clarifying updates

2. **Draft Collaboration**
   - Support multiple admins editing same draft
   - Conflict resolution mechanism

3. **Draft History/Versions**
   - Track changes over time
   - Revert to previous versions

4. **Campaign Status Workflow**
   - ended_success, ended_fail states
   - Campaign lifecycle management
   - Status transition animations

5. **Analytics**
   - Track draft-to-publish conversion rate
   - Monitor why drafts don't get published

6. **Templates**
   - Save successful campaign as template
   - Quick-start new campaigns

---

## Backward Compatibility

✅ **Existing campaigns migrated automatically:**
- Old campaigns without new fields get defaults
- `publishedAt` = null (not yet published)
- `lastEditedAt` = null (will be set on next edit)
- `status` defaults to 'draft' (can set to 'live' for existing campaigns)

No database migration needed - SharedPreferences handles gracefully.

---

## Summary

The draft functionality is now fully implemented and ready for testing. Users can:

1. **Create campaigns gradually** without pressure to complete everything at once
2. **Save progress** without losing work
3. **Resume editing** anytime from "My Drafts"
4. **Get clear feedback** on what's needed before publishing
5. **Publish with confidence** knowing validation catches all issues

The implementation follows Flutter best practices and integrates seamlessly with the existing BukidBayan app architecture.
