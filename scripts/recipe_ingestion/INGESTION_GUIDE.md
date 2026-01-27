# Recipe Ingestion Guide

## 📊 Current Status

**Today (2026-01-26):**
- ✅ 479 recipes added
- ✅ 6 out of 30 API calls used (20% of daily limit)
- ✅ 24 more calls available today
- 📍 Current offset: 500 (resumes from here if you run again)

**Database:**
- Total recipes: 479
- All recipes have complete schema including fiber, sugar, sodium

---

## 🔄 How Duplicate Prevention Works

Your system has **3 layers of duplicate prevention**:

### Layer 1: Daily State Tracking
- File: `daily_state.json`
- Tracks: date, offset, requests made, recipes added
- Resets automatically at midnight
- Prevents re-processing same batches on same day

### Layer 2: Pre-Flight Check
```javascript
// Line 248: Loads ALL existing recipe IDs before fetching
const existingSnapshot = await db.collection('recipes').select().get();
const existingIds = new Set(existingSnapshot.docs.map(doc => doc.id));
```

### Layer 3: Real-Time Filtering
```javascript
// Line 278: Checks each recipe before adding
if (!existingIds.has(transformed.id)) {
  existingIds.add(transformed.id);
  newRecipes.push(transformed);
}
```

**Result:** You can safely run the script multiple times. It will:
- ✅ Skip recipes already in Firestore
- ✅ Only add new ones
- ✅ Log: "X new recipes (Y duplicates skipped)"

---

## 🚀 Adding More Recipes

### Option 1: Manual Run (Current Setup)

**Run anytime to add more recipes:**
```bash
cd scripts/recipe_ingestion
export SPOONACULAR_API_KEY="your-key"
npm run daily
```

**What happens:**
- Checks today's state (6 requests already made)
- Has 24 more requests available (24 × 100 = ~2,400 more recipes possible today)
- Fetches new recipes, skips duplicates automatically
- Updates state file after each batch

**Today's remaining capacity:**
```
Requests used: 6/30
Recipes added: 479
Can still add: ~2,400 recipes today (24 requests × 100 recipes)
```

### Option 2: Automatic Scheduling (Recommended)

**The script is NOT currently scheduled.** You need to set it up.

#### Option A: macOS Cron Job (Simple)

1. Edit crontab:
```bash
crontab -e
```

2. Add this line (runs daily at 2 AM):
```bash
0 2 * * * cd /Users/tanne/Documents/GitHub/AI-Nutrition-Assistant/scripts/recipe_ingestion && /usr/local/bin/node daily_fetch.js >> daily.log 2>&1
```

3. Set API key in environment:
```bash
# Add to ~/.zshrc or ~/.bash_profile
export SPOONACULAR_API_KEY="37bbb81a8d4b4ab2a95513dfeabb229c"
```

**Pros:**
- Free, built into macOS
- Runs automatically every day
- Logs output to `daily.log`

**Cons:**
- Mac must be on and awake at 2 AM
- No monitoring/alerts if it fails

#### Option B: Cloud Scheduler (Production)

Set up a Cloud Function that runs on schedule:

1. Create scheduled function in `functions/src/index.ts`:
```typescript
export const scheduledRecipeIngestion = onSchedule(
  {
    schedule: "0 2 * * *", // 2 AM daily
    timeZone: "America/Los_Angeles",
    secrets: [spoonacularApiKey],
  },
  async (event) => {
    // Call daily_fetch logic here
  }
);
```

2. Deploy:
```bash
firebase deploy --only functions:scheduledRecipeIngestion
```

**Pros:**
- Runs reliably in cloud (no need for Mac to be on)
- Automatic retries if fails
- Monitoring via Firebase Console
- Can send email alerts on errors

**Cons:**
- Slightly more complex setup
- Uses Cloud Functions quota (generous free tier)

#### Option C: GitHub Actions (Free, Cloud-Based)

Create `.github/workflows/daily-recipes.yml`:
```yaml
name: Daily Recipe Ingestion

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
  workflow_dispatch:  # Allow manual trigger

jobs:
  ingest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          cd scripts/recipe_ingestion
          npm install

      - name: Run daily fetch
        env:
          SPOONACULAR_API_KEY: ${{ secrets.SPOONACULAR_API_KEY }}
        run: |
          cd scripts/recipe_ingestion
          npm run daily
```

**Pros:**
- Free (GitHub Actions)
- Runs in cloud automatically
- Can trigger manually from GitHub
- Logs visible in GitHub

**Cons:**
- Needs Firebase service account credentials
- Slightly more setup

---

## 💰 Should You Upgrade Spoonacular API?

### Current Tier: Free
- **Cost:** $0/month
- **Points:** 150/day
- **Your usage:** ~4.6 points per call
- **Capacity:** ~30 calls/day = 3,000 recipes/day
- **Monthly capacity:** ~90,000 recipes/month

### Your Current Database Growth
```
Current: 479 recipes
Daily capacity: 3,000 recipes
Time to 10,000 recipes: ~3 days
Time to 50,000 recipes: ~17 days
```

### API Tier Comparison

| Tier | Cost | Points/Day | Recipes/Day | Recipes/Month | Cost per 10k Recipes |
|------|------|-----------|-------------|---------------|----------------------|
| **Free** | $0 | 150 | 3,000 | 90,000 | $0 |
| **Starter** | $50/mo | 1,500 | 30,000 | 900,000 | $0.167 |
| **Basic** | $100/mo | 5,000 | 100,000 | 3,000,000 | $0.033 |
| **Professional** | $200/mo | 15,000 | 300,000 | 9,000,000 | $0.022 |

### 💡 Recommendation: **Stay on Free Tier**

**Reasons:**

1. **Your needs are covered:**
   - You have 479 recipes now
   - Can add 2,400+ more TODAY
   - Can reach 10,000+ recipes in a few days
   - 3,000 recipes/day is plenty for most apps

2. **Cost vs benefit:**
   - $50/month = $600/year for faster ingestion
   - But free tier already gives you 90k recipes/month
   - Your app likely doesn't need millions of recipes

3. **Diminishing returns:**
   - 479 recipes already provides good variety
   - More important: recipe quality and user experience
   - Better to spend $50/month on Google Cloud credits for RAG search

4. **Smart strategy:**
   ```
   Week 1: Run daily script → 21,000 recipes
   Week 2: Stop daily runs, monitor user feedback
   Week 3: Add more recipes only if needed
   ```

### When to Consider Upgrading

Upgrade to **Starter ($50/mo)** if:
- ❌ You need 100,000+ recipes quickly (within a week)
- ❌ You're expanding to multiple cuisine databases
- ❌ You're doing heavy recipe analysis/processing
- ❌ You're building a commercial recipe aggregator

**For your nutrition assistant app:** Free tier is perfect ✅

---

## 📋 Recommended Action Plan

### Week 1: Build Your Database
```bash
# Day 1: (Already done - 479 recipes)
npm run count  # Check current status

# Day 2-5: Run daily to build up database
npm run daily  # Each day adds ~3,000 recipes

# Target: 10,000-15,000 recipes by end of week
```

### Week 2: Monitor & Optimize
```bash
# Check statistics
npm run count

# Test search quality
# - Does RAG return good results?
# - Are users finding recipes they like?
# - Is cuisine variety sufficient?
```

### Week 3: Decide on Automation
**Option A: Manual (if recipe count is sufficient)**
- Run `npm run daily` occasionally to refresh
- Only when you want new recipes

**Option B: Cron Job (if you want continuous growth)**
- Set up cron to run at 2 AM daily
- Let it build to 50,000+ recipes over time
- Low maintenance

**Option C: Cloud Scheduler (for production app)**
- Most reliable
- No dependency on your local machine
- Better for published apps

---

## 🛠️ Quick Commands

### Check Current Status
```bash
npm run count              # Database statistics
cat daily_state.json       # Today's ingestion progress
```

### Add More Recipes Today
```bash
# You can still add ~2,400 more recipes today!
npm run daily
```

### Reset Daily Limit (if needed)
```bash
# Edit daily_state.json to reset date
# Or just wait until tomorrow for automatic reset
```

### Test Ingestion (without using quota)
```bash
# Check if script works without making API calls
npm test  # Uses 5 recipes, ~1 API point
```

---

## 📈 Growth Projections

### Conservative (Run weekly)
```
Month 1: 12,000 recipes (4 runs)
Month 2: 24,000 recipes
Month 3: 36,000 recipes
Year 1: 150,000 recipes
```

### Aggressive (Run daily)
```
Month 1: 90,000 recipes (30 days × 3,000)
Month 2: 180,000 recipes
Month 3: 270,000 recipes
```

**Reality check:** Most recipe apps use 10,000-50,000 recipes. Quality > Quantity.

---

## ⚠️ Important Notes

### API Key Security
Your API key is visible in the verification summary. Consider:
```bash
# Rotate your key in Spoonacular dashboard
# Then update in environment variable
export SPOONACULAR_API_KEY="new-key"
```

### Rate Limiting
- Built-in: 1 second delay between requests (line 296)
- Prevents API throttling
- Stays within Spoonacular terms of service

### Error Handling
- Quota exceeded: Script stops gracefully, logs warning
- API errors: Skips failed batches, continues with next
- No network: Logs error, can retry later

### State Management
- Daily state resets at midnight UTC
- Safe to run multiple times per day
- Picks up where it left off

---

## 🎯 Final Recommendation

**For your nutrition assistant app:**

1. ✅ **Stay on free tier** - plenty of capacity
2. ✅ **Run `npm run daily` manually** - 2-3 times this week to build up database
3. ✅ **Target 10,000-15,000 recipes** - sufficient variety for users
4. ⏸️ **Pause daily runs** - after reaching target, only run occasionally
5. 💰 **Save $50/month** - invest in Google Cloud credits for better RAG performance

**Run this now to add more recipes:**
```bash
cd scripts/recipe_ingestion
npm run daily
# Will add up to 2,400 more recipes today (24 API calls remaining)
```

**Then check stats:**
```bash
npm run count
```

You're in great shape! The free tier gives you everything you need. 🎉

