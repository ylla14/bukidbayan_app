# Draft Feature - Quick Reference Guide

## Key Points

### What Changed
- Campaign model now tracks `status` (draft/live/ended_success/etc)
- New timestamps: `publishedAt`, `lastEditedAt`
- All drafts stored with live campaigns, filtered by status

### For Users

#### Creating a Campaign
1. Tap "Create" button in Crowdfund tab
2. Walk through 8-step wizard
3. On ANY step, tap "Save Draft" to save progress
4. Tap "Next" to move to next step (validates current step only)
5. On step 8, tap "Publish" to go live (full validation)

#### My Drafts Section
- Shows at top of Crowdfund tab when you have drafts
- Tap a draft to resume editing
- Menu (⋮) offers Edit or Delete options
- Shows last edited date

#### Editing a Draft
1. Click draft from "My Drafts"
2. Make changes
3. Save Draft button preserves changes
4. Can switch between steps freely

#### Publishing
1. Complete all 8 steps
2. On final step, tap "Publish"
3. If errors appear, you'll see list of what's missing
4. Fix issues and try again
5. Once valid, campaign goes live

### For Developers

#### Main Classes
- `Campaign` model: status, publishedAt, lastEditedAt fields
- `CrowdfundingService`: saveDraft(), publishCampaign(), validateForPublish()
- `CampaignWizardScreen`: 8-step UI with Save Draft on every step

#### Key Methods

**Save a draft:**
```dart
await CrowdfundingService().saveDraft(campaign);
```

**Publish a campaign:**
```dart
try {
  await CrowdfundingService().publishCampaign(campaign);
} catch (e) {
  // Handle validation errors
}
```

**Get validation errors:**
```dart
final errors = CrowdfundingService().validateForPublish(campaign);
// Returns List<String> with error messages
```

**Get drafts:**
```dart
final drafts = await CrowdfundingService().getDrafts();
```

#### Status Values
- `'draft'` - Work in progress, not visible publicly
- `'live'` - Published, accepting backers
- `'ended_success'` - Reached goal
- `'ended_fail'` - Did not reach goal
- `'purchased'` - Already purchased
- `'cancelled'` - Admin cancelled

#### Important Fields
```dart
Campaign {
  status: String,           // 'draft' or 'live'
  publishedAt: DateTime?,   // When went live (null if draft)
  lastEditedAt: DateTime?,  // When draft last saved
}
```

### Validation Requirements

**To Publish:**
- Title: 8-70 chars
- Category: required
- Cover: required
- Blurb: min 10 chars
- Story: min 50 chars
- Specs: min 3
- Included: min 10 chars
- Goal: min ₱1,000
- End date: future
- Timeline: min 10 chars
- Rewards: min 1
- Shipping coverage: required
- Warranty: min 10 chars
- Spare parts: min 10 chars
- Risks: min 10 chars

### Important Behavior

✅ **Drafts:** No validation, can save anytime
✅ **Save Draft:** Doesn't require next step, updates lastEditedAt
✅ **Next Button:** Validates only current step fields
✅ **Publish Button:** Validates EVERYTHING
✅ **Public Feed:** Drafts hidden, only live campaigns shown
✅ **My Drafts:** Shows all user's incomplete campaigns

---

## Architecture

```
CrowdfundingScreen
├─ My Drafts Section (FutureBuilder → _draftsFuture)
│  ├─ Draft Item
│  │  ├─ onTap → CampaignCreationScreen(existingDraft)
│  │  ├─ Menu Edit → same
│  │  └─ Menu Delete → deleteDraft()
│  └─ Divider
└─ Live Campaigns Section (FutureBuilder → _future)

CampaignCreationScreen(existingDraft?)
└─ CampaignWizardScreen
   ├─ Step 1-8
   │  ├─ Back Button
   │  ├─ Save Draft Button (always)
   │  ├─ Next Button (if not last step)
   │  └─ Publish Button (if last step)
   └─ OnSaveDraft → service.saveDraft()
   └─ OnPublish → service.publishCampaign()
      └─ Validation: service.validateForPublish()
```

---

## Files to Know

| File | Purpose |
|------|---------|
| [lib/models/campaign.dart](lib/models/campaign.dart) | Campaign data model with status/timestamps |
| [lib/services/crowdfunding_service.dart](lib/services/crowdfunding_service.dart) | Draft CRUD + validation |
| [lib/screens/crowdfunding_screen.dart](lib/screens/crowdfunding_screen.dart) | My Drafts section UI |
| [lib/screens/campaign_creation/campaign_wizard_screen.dart](lib/screens/campaign_creation/campaign_wizard_screen.dart) | 8-step wizard with Save Draft |
| [lib/screens/campaign_creation/campaign_creation_screen.dart](lib/screens/campaign_creation/campaign_creation_screen.dart) | Entry point, routes to wizard |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Drafts not showing | Check `status == 'draft'` filter in getDrafts() |
| Draft loses data | Ensure SaveDraft is called before navigation |
| Publish always fails | Check all validation requirements above |
| Old campaigns missing | Verify migration - old campaigns default to draft status |
| Public feed shows drafts | Verify getCampaigns() filters where `status != 'draft'` |

---

## Testing Checklist

- [ ] Create new draft → Save → Appears in My Drafts
- [ ] Open draft → Edit → Save → lastEditedAt updates
- [ ] Delete draft → Confirm → Removed from My Drafts
- [ ] Publish invalid draft → Shows errors
- [ ] Publish valid draft → Goes live, hidden from My Drafts
- [ ] Public feed doesn't show any drafts
- [ ] Resume draft → All data preserved
- [ ] Soft validation blocks Next on invalid field
