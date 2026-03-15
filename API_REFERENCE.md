# Draft Feature - API Reference

## CrowdfundingService Methods

### saveDraft(Campaign draft)

**Purpose:** Save a campaign draft at any stage of completion

**Signature:**
```dart
Future<void> saveDraft(Campaign draft)
```

**Parameters:**
- `draft` (Campaign) - The campaign to save as draft

**Returns:**
- `Future<void>` - Completes when saved

**Behavior:**
- Saves campaign with `status: 'draft'`
- Updates `lastEditedAt` to current time
- Creates new draft if ID doesn't exist
- Updates existing draft if ID exists
- No validation - accepts incomplete data
- Stores in SharedPreferences under 'campaigns_v1' key

**Example:**
```dart
final campaign = Campaign(
  id: 'draft_123456789',
  title: 'My Campaign',
  // ... other fields
  status: 'draft',
);

await CrowdfundingService().saveDraft(campaign);
// Draft saved successfully
```

**Error Handling:**
```dart
try {
  await service.saveDraft(campaign);
} catch (e) {
  print('Failed to save draft: $e');
}
```

---

### getDrafts({String? userEmail})

**Purpose:** Retrieve all draft campaigns

**Signature:**
```dart
Future<List<Campaign>> getDrafts({String? userEmail})
```

**Parameters:**
- `userEmail` (String?) - Optional email filter (for future use)

**Returns:**
- `Future<List<Campaign>>` - All campaigns where `status == 'draft'`

**Behavior:**
- Returns empty list if no drafts exist
- Automatically filters by status
- Loads from SharedPreferences
- Sorted by creation order (order preserved from storage)

**Example:**
```dart
final drafts = await CrowdfundingService().getDrafts();
for (final draft in drafts) {
  print('Draft: ${draft.title} (Last edited: ${draft.lastEditedAt})');
}
```

**Edge Cases:**
```dart
// No drafts exist
final drafts = await service.getDrafts();
if (drafts.isEmpty) {
  print('No drafts found');
}

// Large number of drafts
final drafts = await service.getDrafts();
if (drafts.length > 20) {
  // Consider pagination in future
}
```

---

### getDraftById(String draftId)

**Purpose:** Retrieve a specific draft by ID

**Signature:**
```dart
Future<Campaign?> getDraftById(String draftId)
```

**Parameters:**
- `draftId` (String) - The unique draft ID

**Returns:**
- `Future<Campaign?>` - The draft if found and is draft status, null otherwise

**Behavior:**
- Returns null if not found
- Returns null if found but status is not 'draft'
- Loads from SharedPreferences

**Example:**
```dart
final draft = await CrowdfundingService().getDraftById('draft_123456789');
if (draft != null) {
  print('Found draft: ${draft.title}');
} else {
  print('Draft not found');
}
```

**Typical Usage:**
```dart
// In CampaignCreationScreen
final draft = await service.getDraftById(draftId);
if (draft != null) {
  // Load draft into wizard
  setState(() => _screenToShow = CampaignWizardScreen(existingDraft: draft));
}
```

---

### deleteDraft(String draftId)

**Purpose:** Permanently delete a draft

**Signature:**
```dart
Future<void> deleteDraft(String draftId)
```

**Parameters:**
- `draftId` (String) - The ID of draft to delete

**Returns:**
- `Future<void>` - Completes when deleted

**Behavior:**
- Removes draft from campaigns list
- No validation or confirmation
- Silently succeeds if draft doesn't exist
- Saves updated list to SharedPreferences

**Example:**
```dart
// Delete with confirmation
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete Draft?'),
    content: const Text('This cannot be undone.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () async {
          await CrowdfundingService().deleteDraft(draftId);
          Navigator.pop(context);
          // Refresh UI
        },
        child: const Text('Delete', style: TextStyle(color: Colors.red)),
      ),
    ],
  ),
);
```

---

### validateForPublish(Campaign campaign)

**Purpose:** Validate a campaign before publishing

**Signature:**
```dart
List<String> validateForPublish(Campaign campaign)
```

**Parameters:**
- `campaign` (Campaign) - The campaign to validate

**Returns:**
- `List<String>` - List of error messages (empty if valid)

**Behavior:**
- Checks all required fields
- Returns detailed error messages
- Does not modify campaign
- Can be called without side effects

**Validation Rules:**
```
Title: 8-70 characters ✓
Category: Not empty ✓
Cover image: Not empty ✓
Short blurb: Min 10 characters ✓
Full story: Min 50 characters ✓
Equipment specs: Min 3 filled ✓
What's included: Min 10 characters ✓
Funding goal: >= ₱1,000 ✓
End date: In future ✓
Production timeline: Min 10 characters ✓
Reward tiers: Min 1 with valid discount ✓
Shipping coverage: Not empty ✓
Shipping cost handling: Not empty ✓
Warranty/support: Min 10 characters ✓
Spare parts: Min 10 characters ✓
Risks & safety: Min 10 characters ✓
```

**Example:**
```dart
final errors = service.validateForPublish(campaign);
if (errors.isNotEmpty) {
  print('Validation failed:');
  for (final error in errors) {
    print('  • $error');
  }
  return;
}
print('Campaign is valid!');
```

**Typical Usage in UI:**
```dart
// In CampaignWizardScreen._publishCampaign()
final errors = service.validateForPublish(_draft);
if (errors.isNotEmpty) {
  showErrorSnackbar(
    context: context,
    title: 'Cannot Publish',
    message: 'Please complete all required fields:\n${errors.join('\n')}',
  );
  return;
}
```

**Edge Cases:**
```dart
// All errors
final campaign = Campaign(/* empty/invalid fields */);
final errors = service.validateForPublish(campaign);
// errors might contain 15+ items

// Single error
final campaign = Campaign(/* mostly valid, but no rewards */);
final errors = service.validateForPublish(campaign);
// errors = ['At least one reward tier is required']

// No errors
final campaign = Campaign(/* all valid */);
final errors = service.validateForPublish(campaign);
// errors = [] (empty list)
```

---

### publishCampaign(Campaign campaign)

**Purpose:** Publish a campaign from draft to live

**Signature:**
```dart
Future<void> publishCampaign(Campaign campaign)
```

**Parameters:**
- `campaign` (Campaign) - The campaign to publish

**Returns:**
- `Future<void>` - Completes when published successfully

**Throws:**
- `Exception` - With validation error messages if campaign is invalid

**Behavior:**
- Validates campaign completely
- Changes status from 'draft' to 'live'
- Sets `publishedAt` to current time
- Sets `lastEditedAt` to current time
- Updates campaign in SharedPreferences
- Campaign becomes visible in public feed

**Example:**
```dart
try {
  await service.publishCampaign(campaign);
  print('Campaign published!');
  // Show success message
  showConfirmSnackbar(
    context: context,
    title: 'Published!',
    message: 'Campaign is now live.',
  );
} catch (e) {
  print('Publish failed: $e');
  showErrorSnackbar(
    context: context,
    title: 'Error',
    message: e.toString(),
  );
}
```

**Typical Usage:**
```dart
// In CampaignWizardScreen._publishCampaign()
setState(() => _isLoading = true);
try {
  _updateDraftFromCurrentStep();
  await CrowdfundingService().publishCampaign(_draft);
  if (mounted) {
    showConfirmSnackbar(context: context, title: 'Published!', message: '...');
    Navigator.pop(context, true);
  }
} catch (e) {
  if (mounted) {
    showErrorSnackbar(context: context, title: 'Error', message: '$e');
  }
} finally {
  if (mounted) setState(() => _isLoading = false);
}
```

---

### getCampaigns()

**Purpose:** Get all live (published) campaigns for public feed

**Signature:**
```dart
Future<List<Campaign>> getCampaigns()
```

**Returns:**
- `Future<List<Campaign>>` - All campaigns where `status != 'draft'`

**Behavior:**
- Automatically filters out drafts
- Returns only live, ended, and other published campaigns
- Initializes with seed data if empty
- Loads from SharedPreferences

**Example:**
```dart
final campaigns = await service.getCampaigns();
print('${campaigns.length} live campaigns');

// This will NOT include drafts
for (final campaign in campaigns) {
  assert(campaign.status != 'draft');
}
```

**Note:**
This method replaces the old behavior that returned all campaigns. Drafts are now automatically excluded from the public feed.

---

## Campaign Model

### New Fields

**status** (String)
```dart
status: String  // Values: 'draft', 'live', 'ended_success', 'ended_fail', 'purchased', 'cancelled'
```

**publishedAt** (DateTime?)
```dart
publishedAt: DateTime?  // Set when campaign goes live, null for drafts
```

**lastEditedAt** (DateTime?)
```dart
lastEditedAt: DateTime?  // Updated each time draft is saved, null for new campaigns
```

### Constructor Usage

**New Campaign (Draft):**
```dart
final campaign = Campaign(
  id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
  title: '',
  creatorName: user.displayName ?? 'Anonymous',
  shortBlurb: '',
  description: '',
  // ... other required fields
  status: 'draft',  // Explicitly set to draft
  publishedAt: null,
  lastEditedAt: null,
);
```

**Existing Campaign (Live):**
```dart
final campaign = Campaign(
  // ... all fields
  status: 'live',
  publishedAt: DateTime.now(),
  lastEditedAt: DateTime.now(),
);
```

### copyWith() Usage

**Update timestamps only:**
```dart
final updated = campaign.copyWith(
  lastEditedAt: DateTime.now(),
  publishedAt: DateTime.now(),  // When publishing
  status: 'live',
);
```

**Keep existing timestamps:**
```dart
final updated = campaign.copyWith(
  title: 'New Title',
  // Other fields will use existing values
  // Timestamps remain unchanged
);
```

---

## UI Integration

### In CrowdfundingScreen

**Load drafts:**
```dart
late Future<List<Campaign>> _draftsFuture;

@override
void initState() {
  super.initState();
  _draftsFuture = service.getDrafts();
}
```

**Display drafts:**
```dart
FutureBuilder<List<Campaign>>(
  future: _draftsFuture,
  builder: (context, snapshot) {
    final drafts = snapshot.data ?? [];
    if (drafts.isEmpty) return SizedBox.shrink();
    
    return Column(
      children: [
        Text('My Drafts'),
        ...drafts.map((draft) => DraftItem(draft: draft)),
      ],
    );
  },
)
```

**Edit draft:**
```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CampaignCreationScreen(existingDraft: draft),
    ),
  ).then((_) => _refresh());
}
```

### In CampaignWizardScreen

**Save draft:**
```dart
Future<void> _saveDraft() async {
  _updateDraftFromCurrentStep();
  try {
    await CrowdfundingService().saveDraft(_draft);
    showConfirmSnackbar(
      context: context,
      title: 'Draft Saved',
      message: 'Your campaign draft has been saved.',
    );
  } catch (e) {
    showErrorSnackbar(context: context, title: 'Error', message: '$e');
  }
}
```

**Publish campaign:**
```dart
Future<void> _publishCampaign() async {
  _updateDraftFromCurrentStep();
  final service = CrowdfundingService();
  final errors = service.validateForPublish(_draft);
  
  if (errors.isNotEmpty) {
    showErrorSnackbar(
      context: context,
      title: 'Cannot Publish',
      message: 'Please complete all required fields:\n${errors.join('\n')}',
    );
    return;
  }

  try {
    await service.publishCampaign(_draft);
    showConfirmSnackbar(
      context: context,
      title: 'Campaign Published!',
      message: 'Supporters can now pledge.',
    );
    Navigator.pop(context, true);
  } catch (e) {
    showErrorSnackbar(context: context, title: 'Error', message: '$e');
  }
}
```

---

## Common Patterns

### Pattern 1: Create and Save Draft

```dart
// 1. Create empty draft
Campaign draft = Campaign(
  id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
  title: '',
  // ... other required empty fields
  status: 'draft',
);

// 2. User fills in data in UI
draft = Campaign(
  id: draft.id,
  title: titleController.text,
  // ... other filled fields
  status: 'draft',
);

// 3. Save draft
await service.saveDraft(draft);
```

### Pattern 2: Resume and Edit Draft

```dart
// 1. Get existing draft
final draft = await service.getDraftById(draftId);
if (draft == null) return;

// 2. Load into UI
titleController.text = draft.title;
// ... populate other fields

// 3. User makes changes
// ... updates to controllers

// 4. Save changes
final updated = draft.copyWith(
  title: titleController.text,
  // ... other updated fields
);
await service.saveDraft(updated);
```

### Pattern 3: Validate Then Publish

```dart
// 1. Get validation errors
final errors = service.validateForPublish(draft);

// 2. Show errors if any
if (errors.isNotEmpty) {
  for (final error in errors) print('• $error');
  return;
}

// 3. Publish
await service.publishCampaign(draft);

// 4. Draft now has:
// - status: 'live'
// - publishedAt: DateTime.now()
// - lastEditedAt: DateTime.now()
```

### Pattern 4: Handle Publish Errors

```dart
try {
  await service.publishCampaign(campaign);
  print('Success!');
} on Exception catch (e) {
  // Get error message
  final message = e.toString().replaceFirst('Exception: ', '');
  
  // Parse as validation errors
  final errors = message.split(', ');
  for (final error in errors) {
    print('✗ $error');
  }
  
  // Show to user
  showErrorSnackbar(
    context: context,
    title: 'Cannot Publish',
    message: message,
  );
}
```

---

## Best Practices

✅ **DO:**
- Always wrap service calls in try-catch
- Show loading indicator while saving/publishing
- Save draft before navigation
- Validate before showing error to user
- Use meaningful error messages
- Keep draft ID consistent throughout editing session

❌ **DON'T:**
- Call validateForPublish() during Save Draft
- Show all validation errors at once (group related errors)
- Trust draft data without verifying status
- Allow publish without validation
- Forget to update UI after service calls
- Store campaign IDs in static variables (use route parameters)

---

## Error Messages (Examples)

When validation fails, users see these messages:

```
✗ Title must be between 8 and 70 characters
✗ Category is required
✗ Cover image/video is required
✗ Short blurb must be at least 10 characters
✗ Full story must be at least 50 characters
✗ At least 3 equipment specs are required
✗ What's included must be at least 10 characters
✗ Funding goal must be at least ₱1,000
✗ End date must be in the future
✗ Production timeline must be at least 10 characters
✗ At least one reward tier is required
✗ Shipping coverage is required
✗ Shipping cost handling is required
✗ Warranty/support must be at least 10 characters
✗ Spare parts info must be at least 10 characters
✗ Risks & safety must be at least 10 characters
```

---

## Status Values

| Status | Meaning | Public? | Editable? | Notes |
|--------|---------|---------|-----------|-------|
| `draft` | Work in progress | ✗ No | ✓ Yes | Not visible to backers |
| `live` | Published, accepting pledges | ✓ Yes | ⚠️ Limited | Can clarify, not change terms |
| `ended_success` | Reached goal | ✓ Yes | ✗ No | Show results |
| `ended_fail` | Did not reach goal | ✓ Yes | ✗ No | Show results |
| `purchased` | Already purchased | ✓ Yes | ✗ No | Completed transaction |
| `cancelled` | Admin cancelled | ✗ No | ✗ No | Archived |

---

This API reference provides all the information needed to use the draft functionality in the BukidBayan app.
