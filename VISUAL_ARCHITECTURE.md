# Draft Feature - Visual Architecture Guide

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BukidBayan App                              │
└─────────────────────────────────────────────────────────────────────┘
                                ▲
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
    ┌─────────┐          ┌──────────────┐        ┌──────────┐
    │Dashboard│          │Crowdfunding  │        │Profile   │
    │ Screen  │          │  Screen      │        │ Screen   │
    └─────────┘          └──────────────┘        └──────────┘
                                ▲
                    ┌───────────┴───────────┐
                    ▼                       ▼
           ┌──────────────────┐    ┌─────────────────┐
           │  My Drafts       │    │ Live Campaigns  │
           │  Section         │    │ (Public Feed)   │
           ├──────────────────┤    ├─────────────────┤
           │ • Draft 1        │    │ • Campaign 1    │
           │ • Draft 2        │    │ • Campaign 2    │
           │ • Draft 3        │    │ • Campaign 3    │
           └──────────────────┘    └─────────────────┘
                    │ (tap)
                    ▼
           ┌──────────────────────────┐
           │ CampaignCreationScreen   │
           │ (with existingDraft)     │
           └──────────────────────────┘
                    │
                    ▼
           ┌──────────────────────────┐
           │ CampaignWizardScreen     │
           │ (8-step flow)            │
           ├──────────────────────────┤
           │ ┌────────────────────────┐│
           │ │ Step 1-7              ││
           │ │ [Save Draft] [Next]   ││
           │ │ (validates per-step)  ││
           │ └────────────────────────┘│
           │ ┌────────────────────────┐│
           │ │ Step 8 (Final)         ││
           │ │ [Save Draft] [Publish] ││
           │ │ (validates all)        ││
           │ └────────────────────────┘│
           └──────────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
    [Save Draft]           [Publish]
        │                       │
        ▼                       ▼
    CrowdfundingService.  CrowdfundingService.
    saveDraft()           publishCampaign()
        │                       │
        │                   [Validate]
        │                       │
        ▼                       ▼
    Campaign                Campaign
    status='draft'          status='live'
    lastEditedAt=now        publishedAt=now
        │                       │
        ▼                       ▼
    SharedPreferences      SharedPreferences
    (campaigns_v1)         (campaigns_v1)
        │                       │
        ▼                       ▼
    My Drafts List         Public Feed
    (filtered:            (filtered:
     status=='draft')       status!='draft')
```

---

## Data Flow Diagram

### Create New Campaign

```
User Action: Tap "Create"
     │
     ▼
CrowdfundingScreen
     │
     ├─ Navigate to CampaignCreationScreen()
     │
     ▼
CampaignCreationScreen
     │
     ├─ Check existingDraft (null)
     │
     ▼
CampaignWizardScreen
     │
     ├─ Create empty Campaign
     │   - id: 'draft_' + timestamp
     │   - status: 'draft'
     │   - all fields: empty/default
     │
     ├─ Display Step 1
     │
     └─ Wait for user action
         │
         ├─ [Save Draft] ──┐
         │                 │
         ├─ [Next] ────────┤─────────────────┐
         │                 │                 │
         └─ [Close] ───────┤─────────────────┤─────┐
                           │                 │     │
                           ▼                 ▼     │
                    saveDraft()      validateStep()│
                           │                 │     │
                           ▼                 ▼     │
                    Collect form       If valid:   │
                    Update _draft      Move next   │
                           │           Step++ ─┐   │
                           ▼           │       │   │
                    Save to Prefs      ▼       │   │
                    lastEditedAt=now   Display │   │
                           │           next    │   │
                           ▼           step    │   │
                    Show "Saved" ◄─────┘       │   │
                           │                   │   │
                           └───────────────────┴───┴─→ My Drafts
                                                     (refresh)
```

### Resume and Edit Draft

```
User Action: Tap draft in "My Drafts"
     │
     ▼
CrowdfundingScreen
     │
     ├─ Navigate to CampaignCreationScreen(existingDraft: draft)
     │
     ▼
CampaignCreationScreen
     │
     ├─ Check existingDraft (not null!)
     │
     ▼
CampaignWizardScreen
     │
     ├─ Initialize with draft data
     │   - Load _draft = existingDraft
     │   - Populate all controllers from _draft
     │   - Display current step
     │
     └─ Display wizard with pre-filled data
         │
         ├─ [Save Draft] ──────────────────┐
         │                                 │
         ├─ [Next] ────────────────────────┤─────┐
         │                                 │     │
         └─ [Close] ────────────────────┐  │     │
                                        │  │     │
                                        ▼  ▼     │
                                  Update _draft  │
                                    from form    │
                                        │        │
                                        ▼        │
                                  saveDraft()    │
                                        │        │
                                        ▼        │
                                  lastEditedAt   │
                                    =now         │
                                        │        │
                                        ▼        │
                           Return to My Drafts ◄─┘
                           (refresh list)
```

### Publish Campaign

```
User Action: Step 8, [Publish]
     │
     ▼
CampaignWizardScreen
     │
     ├─ _publishCampaign()
     │
     ▼
CrowdfundingService.validateForPublish()
     │
     ├─ Check all 16+ validation rules
     │
     ├─ If errors found:
     │   └─ Return List<String> with errors
     │
     └─ If no errors:
        └─ Return empty List<String>
           │
           ▼
   if (errors.isNotEmpty) {
       ├─ Show error snackbar
       └─ Return (block publish)
   }
           │
           ▼
CrowdfundingService.publishCampaign()
     │
     ├─ Find campaign in list
     │
     ▼
Campaign.copyWith(
    status: 'live',
    publishedAt: DateTime.now(),
    lastEditedAt: DateTime.now(),
)
     │
     ▼
Save updated campaign to SharedPreferences
     │
     ▼
Show "Campaign Published!" snackbar
     │
     ▼
Navigator.pop(context)
     │
     ▼
Return to CrowdfundingScreen
     │
     ├─ Refresh both futures:
     │   - _future (live campaigns)
     │   - _draftsFuture (drafts)
     │
     ▼
Campaign now appears in:
├─ Public feed (status == 'live')
└─ NOT in My Drafts (status != 'draft')
```

---

## State Management Flow

### Campaign States During Wizard

```
Initial State:
├─ New Draft
│  └─ id: 'draft_123456789'
│     status: 'draft'
│     title: ''
│     category: 'Irrigation'
│     ... all empty fields

Step 1-3: Editing
├─ User fills "Title", "Category", "Cover"
│  └─ _draft updated when user types
│     _titleController.text = 'My Campaign'
│     _selectedCategory = 'Crop Care'
│     ...

Step 3: Save Draft Pressed
├─ _updateDraftFromCurrentStep()
│  └─ Create new Campaign with updated values
│     _draft = Campaign(
│       id: _draft.id,
│       title: _titleController.text,
│       category: _selectedCategory,
│       lastEditedAt: DateTime.now(),
│       ...
│     )
│
├─ saveDraft(_draft)
│  └─ Save to SharedPreferences
│
└─ Show "Draft Saved" notification

Step 3: Next Pressed
├─ validateCurrentStep()
│  └─ Check if current step fields valid
│     if (invalid) return without moving
│
├─ If valid: _currentStep++
│  └─ Show Step 4

Step 8: Publish Pressed
├─ validateForPublish(_draft)
│  └─ Check ALL fields
│     if (invalid) show errors and return
│
├─ publishCampaign(_draft)
│  └─ Update status: 'draft' → 'live'
│     Set publishedAt
│     Set lastEditedAt
│     Save to Prefs
│
└─ Return to CrowdfundingScreen
   ├─ Refresh _future
   └─ Refresh _draftsFuture
      └─ Draft no longer in "My Drafts"
         Campaign now in public feed
```

---

## Storage Model

```
SharedPreferences ('campaigns_v1')
│
└─ List<Campaign>
   │
   ├─ Campaign {
   │   id: 'draft_111',
   │   status: 'draft',          ◄─── Differentiator
   │   title: 'Partial Campaign',
   │   category: 'Irrigation',
   │   ... other fields (may be empty)
   │   publishedAt: null,        ◄─── null for drafts
   │   lastEditedAt: 2/18/2026
   │ }
   │
   ├─ Campaign {
   │   id: 'c_222',
   │   status: 'live',           ◄─── Differentiator
   │   title: 'Published Campaign',
   │   ... all fields filled
   │   publishedAt: 2/18/2026,   ◄─── set when published
   │   lastEditedAt: 2/18/2026
   │ }
   │
   └─ Campaign {
       id: 'c_333',
       status: 'draft',          ◄─── Another draft
       ... other fields
     }

Query: Get drafts
       WHERE status == 'draft'
       RETURNS: [draft_111, draft_333]

Query: Get live campaigns
       WHERE status != 'draft'
       RETURNS: [c_222]
```

---

## Component Interaction Diagram

```
┌───────────────────────────────────────────────────────────┐
│              CrowdfundingScreen                           │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │  Header                                             │ │
│  │  [Crowdfund]              [Create Campaign] ───┐   │ │
│  └─────────────────────────────────────────────────┼───┘ │
│                                                    │      │
│  ┌─────────────────────────────────────────────────┼───┐  │
│  │  My Drafts Section (FutureBuilder)             │   │  │
│  │  ┌────────────────────────────────────────────┐│   │  │
│  │  │ Draft 1                          [⋮]      ││   │  │
│  │  │ Last edited: 2/18/2026    Edit / Delete   ││   │  │
│  │  │ (tap to edit) ─────────────────┐          ││   │  │
│  │  └────────────────────────────────┼──────────┘│   │  │
│  │  ┌────────────────────────────────┼──────────┐│   │  │
│  │  │ Draft 2                        │ [⋮]     ││   │  │
│  │  │ Last edited: 2/17/2026         │          ││   │  │
│  │  └────────────────────────────────┼──────────┘│   │  │
│  └────────────────────────────────────┼──────────┘   │  │
│                                       │             │  │
│  [Search Box]                         │             │  │
│  [Category Filter] [Sort Filter]      │             │  │
│                                       │             │  │
│  ┌─────────────────────────────────┐  │             │  │
│  │ Live Campaigns (FutureBuilder)  │  │             │  │
│  │ (filtered: status != 'draft')    │  │             │  │
│  │                                 │  │             │  │
│  │ ┌──────────────────────────────┐│  │             │  │
│  │ │ Campaign 1                   ││  │             │  │
│  │ │ Category: Irrigation         ││  │             │  │
│  │ │ 5 days left                  ││  │             │  │
│  │ │ [Pledge Now]                 ││  │             │  │
│  │ └──────────────────────────────┘│  │             │  │
│  │ ┌──────────────────────────────┐│  │             │  │
│  │ │ Campaign 2                   ││  │             │  │
│  │ │ ...                          ││  │             │  │
│  │ └──────────────────────────────┘│  │             │  │
│  └─────────────────────────────────┘  │             │  │
│                                       │             │  │
│         ┌─────────────────────────────┴──────────────┴──┐
│         │                                              │
│         ▼                                              ▼
│    [Tap Draft]                               [Tap Create]
│         │                                              │
│         └──────────────┬───────────────────────────────┘
│                        │
│                        ▼
│              CampaignCreationScreen
│              (existingDraft: ? )
│                        │
│                        ▼
│              CampaignWizardScreen
│              (8 steps with draft state)
```

---

## Timestamp Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│                   Campaign Lifetime                             │
└─────────────────────────────────────────────────────────────────┘

User creates campaign
│
├─ createdAt = 2/18/2026 10:00 AM
├─ status = 'draft'
├─ publishedAt = null
└─ lastEditedAt = null

User fills step 1, saves draft
│
├─ createdAt = 2/18/2026 10:00 AM (unchanged)
├─ lastEditedAt = 2/18/2026 10:05 AM (updated)
└─ status = 'draft'

User returns later, fills more, saves
│
├─ createdAt = 2/18/2026 10:00 AM (unchanged)
├─ lastEditedAt = 2/18/2026 11:30 AM (updated)
└─ status = 'draft'

User completes all steps, publishes
│
├─ createdAt = 2/18/2026 10:00 AM (unchanged)
├─ publishedAt = 2/18/2026 11:32 AM (set now)
├─ lastEditedAt = 2/18/2026 11:32 AM (updated)
└─ status = 'live' (changed!)

Timeline:
 10:00 ─────── 10:05 ─────── 11:30 ─────── 11:32
  │              │              │              │
  └─ Created     ├─ Draft 1      ├─ Draft 2     └─ Published
     Updated       Saved          Saved           Goes Live!
```

---

## Error Handling Flow

```
publishCampaign() called
│
├─ validateForPublish(campaign)
│
├─ errors = [
│    'Title must be between 8 and 70 characters',
│    'Funding goal must be at least ₱1,000',
│    'At least one reward tier is required'
│  ]
│
├─ if (errors.isNotEmpty)
│  │
│  ├─ Throw Exception with error messages
│  │
│  └─ Caught in CampaignWizardScreen._publishCampaign()
│     │
│     ├─ Show AlertDialog with errors
│     │  ┌─────────────────────────────────────┐
│     │  │ Cannot Publish                      │
│     │  │                                     │
│     │  │ • Title must be between 8 and 70   │
│     │  │ • Funding goal must be at least    │
│     │  │ • At least one reward tier needed  │
│     │  │                                     │
│     │  │              [OK]                   │
│     │  └─────────────────────────────────────┘
│     │
│     └─ User taps OK, returns to wizard
│        Can fix issues and try again
│
└─ if (errors.isEmpty)
   │
   ├─ Continue with publish
   │
   ├─ Update campaign
   │
   ├─ Save to SharedPreferences
   │
   └─ Show success message
      ┌──────────────────────┐
      │ Campaign Published!  │
      │                      │
      │ Supporters can now   │
      │ pledge to help fund. │
      │                      │
      │      [Close]         │
      └──────────────────────┘
```

---

## Feature Comparison Matrix

```
┌─────────────────┬──────────────┬────────────────────────────────┐
│ Aspect          │ Draft        │ Live Campaign                  │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Visible         │ ✗ (My Drafts │ ✓ Public feed                  │
│ to others       │  only)       │                                │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Can edit        │ ✓ Freely     │ ⚠️ Limited (clarifications)    │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Can delete      │ ✓ Anytime    │ ✗ No (locked)                  │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Must be         │ ✗ No         │ ✓ Yes (16 validations)         │
│ complete        │              │                                │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Can receive     │ ✗ No         │ ✓ Yes                          │
│ pledges         │              │                                │
├─────────────────┼──────────────┼────────────────────────────────┤
│ Timestamps      │              │                                │
│ - createdAt     │ Set          │ Same as draft                   │
│ - publishedAt   │ null         │ Set to publish time            │
│ - lastEditedAt  │ Updated on   │ Updated when edited            │
│                 │ save         │ (if allowed)                   │
└─────────────────┴──────────────┴────────────────────────────────┘
```

---

This visual guide helps understand the draft feature's architecture, data flow, and user interaction patterns.
