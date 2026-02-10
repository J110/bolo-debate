# Adding New Categories to the Topic Generation System

This guide explains how to add a new category to the Bolo Debate topic generation system.

## Prerequisites

Before adding a new category, ensure:
1. The category exists in the database (`Category` table)
2. You have a list of evergreen/generic debate topics for this category

## Step-by-Step Process

### Step 1: Add Category to Database

If the category doesn't exist yet, add it via Prisma or direct SQL:

```typescript
await prisma.category.create({
  data: {
    name: 'NewCategory',
    icon: '🆕', // Choose appropriate emoji
    description: 'Description of the category'
  }
});
```

### Step 2: Add Generic Topics to JSON

Edit `backend/src/data/generic-topics.json` and add topics for the new category:

```json
{
  "id": "newcategory-001",
  "category": "NewCategory",  // Must match exactly the category name in database
  "title": "English debate question here?",
  "titleHindi": "हिंदी में प्रश्न?",
  "sideA": "Side A Label",
  "sideB": "Side B Label",
  "sideAHindi": "पक्ष A",
  "sideBHindi": "पक्ष B",
  "tags": ["evergreen", "relevant-tag"]
}
```

**Guidelines for generic topics:**
- Add at least 15-20 topics per category for good rotation
- Topics should be evergreen (not time-sensitive)
- Include Hindi translations for all text
- Use clear, debatable positions for sides
- Topics should have valid arguments on both sides

### Step 3: Add Category Keywords for Trending Classification

Edit `backend/src/services/trending.ts` and add keywords for the new category:

```typescript
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  // ... existing categories ...
  NewCategory: ['keyword1', 'keyword2', 'keyword3', ...],
};
```

These keywords help classify trending news into the correct category.

### Step 4: Update International Topic Classification (Optional)

If international news should be classified into this category, edit `backend/src/services/international.ts`:

```typescript
function classifyCategory(headline: string, defaultCategory: string): string {
  const lower = headline.toLowerCase();
  
  // Add new category classification
  if (/keyword1|keyword2|keyword3/i.test(lower)) {
    return 'NewCategory';
  }
  
  // ... existing classifications ...
}
```

### Step 5: Restart Services

After making changes:

1. Rebuild the backend: `npm run build`
2. Restart the server
3. The scheduler will automatically:
   - Load new generic topics into the queue
   - Ensure category coverage (1 live + 1 upcoming)
   - Apply ratio enforcement

## Automatic Features

Once the category is added, the system automatically handles:

- **Category Coverage**: `ensureMinimumRoomsPerCategory()` guarantees at least 1 live and 1 upcoming room
- **Topic Rotation**: Generic topics rotate to prevent duplicates for 3 months
- **Ratio Enforcement**: 50:50 Hindi/English and local/generic ratios are maintained
- **Duplicate Prevention**: The `UsedTopic` table tracks all topics to prevent repeats

## Verification

After adding a new category, verify it's working:

1. Check the API endpoint: `GET /api/rooms/stats/topics`
2. Look for the category in `categoryCoverage` array
3. Verify `covered: true` for the new category

```bash
curl https://your-api-url/api/rooms/stats/topics | jq '.data.categoryCoverage'
```

## Example: Adding "Health" Category

```json
// In generic-topics.json, add topics like:
{
  "id": "health-001",
  "category": "Health",
  "title": "Should vaccines be mandatory for all citizens?",
  "titleHindi": "क्या सभी नागरिकों के लिए टीके अनिवार्य होने चाहिए?",
  "sideA": "Yes, Mandatory",
  "sideB": "No, Personal Choice",
  "sideAHindi": "हां, अनिवार्य",
  "sideBHindi": "नहीं, व्यक्तिगत पसंद",
  "tags": ["health", "policy", "evergreen"]
},
{
  "id": "health-002",
  "category": "Health",
  "title": "Is mental health as important as physical health?",
  "titleHindi": "क्या मानसिक स्वास्थ्य शारीरिक स्वास्थ्य जितना महत्वपूर्ण है?",
  "sideA": "Equally Important",
  "sideB": "Physical Health First",
  "sideAHindi": "समान रूप से महत्वपूर्ण",
  "sideBHindi": "पहले शारीरिक स्वास्थ्य",
  "tags": ["mental-health", "wellness", "evergreen"]
}
```

```typescript
// In trending.ts, add:
Health: ['health', 'medical', 'hospital', 'doctor', 'disease', 'medicine', 
         'vaccine', 'treatment', 'healthcare', 'wellness', 'mental health',
         'WHO', 'AIIMS', 'pandemic', 'virus'],
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Category not showing rooms | Verify category name matches exactly in JSON and database |
| Topics not rotating | Check `UsedTopic` table, run `cleanupExpiredDuplicates()` |
| Wrong language ratio | System self-corrects via `ratio-enforcer.ts` over time |
| No trending topics | Add more keywords to `CATEGORY_KEYWORDS` |

## Files to Modify

| File | Purpose |
|------|---------|
| `src/data/generic-topics.json` | Add evergreen debate topics |
| `src/services/trending.ts` | Add classification keywords |
| `src/services/international.ts` | (Optional) Add international classification |
| Database `Category` table | Create the category entry |
