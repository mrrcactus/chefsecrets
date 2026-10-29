# Recipes

Each `.txt` file here is one recipe. Pull down on the recipe list in ChefSecrets to sync.

- **Add a recipe:** create a new `.txt` file (e.g. `salmon-rice-bowl.txt`) in the format below, then commit and push.
- **Change a recipe:** edit the file and push. The phone updates on the next sync (and replaces any edits you made to it on the phone).
- **Remove a recipe:** delete the file and push. It disappears from the phone on the next sync.

A GitHub Action checks every file on push. A red ✗ on the commit means a file has a format problem, and the log says which line.

```
TITLE: Chicken Pesto Pasta
CATEGORY: Meal
FROM: ChatGPT
SERVINGS: 2
MACROS PER SERVING: 540 kcal | 45 P | 52 C | 15 F
LINK: https://www.tiktok.com/...        (optional)
INGREDIENTS:
- 250 g | chicken breast | swaps: turkey breast, firm tofu
- 2 tbsp | pesto
STEPS:
1. Boil the penne...
```

`CATEGORY` is Breakfast, Meal, Dessert or Other. `FROM` is one of Claude, ChatGPT, TikTok or Me. Macros are per serving. `| swaps: ...` is optional.
