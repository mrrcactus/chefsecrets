"""Checks every recipes/*.txt file is in the ChefSecrets format the app can read.

Run locally with: python3 .github/scripts/check_recipes.py
"""
import re
import sys
from pathlib import Path

SOURCES = {"claude", "chatgpt", "tiktok", "me"}
CATEGORIES = {"breakfast", "meal", "meals", "dessert", "desserts", "other"}


def check(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    problems = []

    def field(name):
        m = re.search(rf"^{name}\s*:\s*(.+)$", text, re.M | re.I)
        return m.group(1).strip() if m else None

    if not field("TITLE"):
        problems.append("missing 'TITLE: ...'")
    servings = field("SERVINGS")
    if not servings or not re.match(r"\d+", servings):
        problems.append("missing 'SERVINGS: <number>'")
    category = field("CATEGORY")
    if not category:
        problems.append("missing 'CATEGORY: Breakfast | Meal | Dessert | Other'")
    elif category.lower() not in CATEGORIES:
        problems.append(f"CATEGORY must be Breakfast, Meal, Dessert or Other (got '{category}')")
    source = field("FROM")
    if source and source.lower() not in SOURCES:
        problems.append(f"FROM must be one of Claude, ChatGPT, TikTok, Me (got '{source}')")

    macros = field("MACROS PER SERVING")
    if not macros:
        problems.append("missing 'MACROS PER SERVING: <kcal> kcal | <P> P | <C> C | <F> F'")
    else:
        for unit in ("kcal", "P", "C", "F"):
            if not re.search(rf"\d+(?:\.\d+)?\s*{unit}\b", macros, re.I if unit == "kcal" else 0):
                problems.append(f"macros line has no number for {unit}")

    sections = re.split(r"^(INGREDIENTS|STEPS)\s*:?\s*$", text, flags=re.M | re.I)
    parts = {sections[i].upper(): sections[i + 1] for i in range(1, len(sections) - 1, 2)}
    ingredients = re.findall(r"^\s*-\s*\S", parts.get("INGREDIENTS", ""), re.M)
    steps = re.findall(r"^\s*\d+[.)]\s*\S", parts.get("STEPS", ""), re.M)
    if not ingredients:
        problems.append("no ingredients (lines like '- 200 g | chicken breast') under INGREDIENTS:")
    if not steps:
        problems.append("no steps (lines like '1. ...') under STEPS:")
    return problems


def main() -> int:
    files = sorted(Path("recipes").glob("*.txt"))
    failed = 0
    for path in files:
        problems = check(path)
        if problems:
            failed += 1
            for p in problems:
                print(f"::error file={path}::{p}")
                print(f"  {path}: {p}")
        else:
            print(f"ok  {path}")
    print(f"\n{len(files) - failed}/{len(files)} recipe files OK")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
