# Recipe App — Plan (personal use only)

Name: **ChefSecrets**

## What it does

1. **Stores your recipes**: title, photo, ingredients, steps, servings.
2. **Shows macros on the list**: every recipe card shows calories, protein, carbs and fat per serving, so you can compare without tapping in.
3. **Filters by what you have**: tick off what's in your kitchen, and the list shows what you can make.

"Macros" here means the big three nutrients (protein, carbs, fat) plus calories.

## How it's built

Same setup as LiftBlue, so nothing new to learn:

| Piece | Choice | Plain meaning |
|---|---|---|
| UI | SwiftUI | Apple's way of drawing screens in code |
| Storage | SwiftData | Saves recipes on the phone itself, so no account or server |
| Backup / sync | iCloud (optional, phase 3) | Copies your data to your own iCloud so a new phone gets it |
| Look | LiftBlue blue palette + bold type | Same colors as your gym app |

Because it's just for you, there's **no App Store, no login and no server**. You install it on your phone from Xcode.

- **Free Apple ID**: the app stops opening after 7 days, and you plug in and press Run again to reinstall it. Your data stays.
- **Paid developer account ($99/yr)**: it lasts a year, and you can use TestFlight.

## Screens

**1. Recipe list (home)**
Each card shows a photo thumbnail, the name, and a macro strip, e.g. `520 kcal · 42P · 48C · 16F`.
- Sort by: highest protein, lowest calories, protein per 100 kcal, newest.
- Search bar for recipe names.
- Filter chip: **"What I have"** (see screen 3).

**2. Recipe detail**
Ingredients with amounts, numbered steps, macros per serving, and a servings stepper that scales the amounts.

**3. Pantry ("What I have")**
A checklist of every ingredient used across your recipes. Tick what you have, and the list then sorts into:
- **Can make now**: you have everything.
- **Missing 1–2**: shows what's missing, e.g. "need: feta".
- Everything else is hidden.

**Staples** (salt, pepper, oil, water) get a "staple" flag and are always counted as "have", so they never block a match.

**4. Add / edit recipe**
A form for the title, servings, ingredients, steps, macros and a photo from your camera roll. You'll mostly start from **Paste recipe** (below) rather than typing.

## Getting recipes in

Your recipes come from three places: **Claude, ChatGPT, and TikTok**.

**Claude / ChatGPT → "Paste recipe" button**
The app comes with a short **ChefSecrets prompt** you can copy. Add it to the end of any recipe request ("high-protein pasta, ~500 kcal") and the AI replies in a fixed format:

```
TITLE: Chicken Pesto Pasta
SERVINGS: 2
MACROS PER SERVING: 540 kcal | 45 P | 52 C | 15 F
INGREDIENTS:
- 200 g | chicken breast
- 150 g | penne
...
STEPS:
1. Boil the pasta...
```

Copy the reply, tap **Paste recipe**, and every field fills in. You check it and save. A fixed format means the app never has to guess what's a title and what's an ingredient. If a reply doesn't follow the format, the app falls back to Apple's built-in on-device AI (no account or cost needed, works on iPhone 15 Pro and newer) to sort the text into fields.

**TikTok → share button**
TikTok doesn't let apps read the video itself, so:
1. In TikTok, tap **Share → ChefSecrets**. The app saves the link to the recipe, so you can rewatch it.
2. Paste the recipe from the caption, or ask ChatGPT/Claude "turn this into a recipe" with the ChefSecrets prompt, then paste the result.

The recipe detail screen gets a **"Watch on TikTok"** button when a link is saved.

**Macros are per serving.** AI replies already give per-serving numbers, so that's what the app stores.

## Two design problems to settle up front

**A. Where do the macro numbers come from?**

| Option | How | Effort |
|---|---|---|
| 1. Type them in (v1) | You enter kcal/P/C/F per serving, copied from MyFitnessPal, a label, etc. | Easy, and works today |
| 2. Auto-calculate (later) | Each ingredient looks up its nutrition in the free USDA food database, and the app adds them up | Harder, because "1 cup spinach" has to be turned into grams |

Recommendation: start with option 1. Add option 2 only if typing them gets annoying.

**B. Making ingredient matching work**
If one recipe says "chicken breast" and another says "Chicken breasts", the filter breaks. Fix: ingredients are saved **once** in a master list. When you add a recipe, you pick from that list (or add a new one) instead of free-typing. Amounts ("200 g") are stored separately from the ingredient itself.

## Data model (what gets saved)

```
Recipe:      title, photo, servings, steps, kcal, protein, carbs, fat (per serving), source (Claude/ChatGPT/TikTok/me), sourceLink, dateAdded
Ingredient:  name, isStaple, inPantry (yes/no)
RecipeLine:  recipe → ingredient, amount ("200 g"), note ("diced")
```

`RecipeLine` connects a recipe to an ingredient and stores the amount. The pantry filter only needs `Ingredient.inPantry`.

## Build phases

| Phase | Delivers | Done when |
|---|---|---|
| **1. Core** | Data model, add/edit recipe, **Paste recipe** + ChefSecrets prompt, list with macro strip, detail screen | You can paste 3 real AI recipes and see macros on the list |
| **2. Pantry filter** | Pantry checklist, staples, "can make / missing 1–2" sections | Ticking ingredients changes the list correctly |
| **3. Polish** | TikTok share button, sorting, search, serving scaler, photos, iCloud backup | You use it for a week without it annoying you |
| **4. Nice-to-haves** | On-device AI fallback for messy pastes; USDA auto-macros; "add to LiftBlue" daily protein | Pick only what you actually miss |

## Your decisions (before phase 1)

- [x] App name → ChefSecrets
- [x] Macros → per serving
- [x] Sources → Claude, ChatGPT, TikTok
- [x] Missing filter → up to 2 by default, adjustable 0–5, with ingredient swaps
- [x] Install → free Apple ID, reinstall from Xcode every 7 days
- [x] GitHub sync → public repo github.com/mrrcactus/chefsecrets
- [ ] List 5 recipes you'd add first. They'll be the test data.

## GitHub sync (built)

Idea: a GitHub repo with a `recipes/` folder. Each recipe is one `.txt` file in the ChefSecrets format. Claude (or you) can add a file and push it, and the app pulls new and changed files when you tap **Sync**.

- **Manual add still works.** Recipes added on the phone stay on the phone. The app remembers which recipes came from GitHub (`githubPath`, already in the data model) so a sync updates them instead of duplicating them.
- **One-way sync:** GitHub → phone. Writing back to GitHub from the phone would need a token with write access stored on the phone, which isn't worth it for v1.
- **Public repo**, so the app needs no token. It syncs quietly on launch and when you pull down on the list.
- **Optional GitHub Action:** an automatic check that runs on every push and flags any recipe file that's missing a title, macros or ingredients.
- **Gotcha:** if you edit a GitHub recipe on the phone and the file changes later on GitHub, the next sync overwrites your phone edit.
