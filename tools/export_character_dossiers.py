"""Render the entire public, fictional dossier catalogue for human review. No world access."""
import argparse
import json
from pathlib import Path
from character_profiles import catalogue, CONTRACT


def render():
    profiles = catalogue()
    lines = ["# Original resident dossiers", "", "Generated from `game/data/character_dossiers.json`. All ten residents are original project characters. These are authored genesis profiles, not records of simulated events or a reconstruction of seq450.", "",
             "Core and selected situational facets reach the resident's decision input. The 21 detailed sections remain stored, including dormant traits, visual concepts, unknown ability slots and future relationship/evidence structures. Unknown is not zero. Nothing here grants a skill, object, friend, medical ability or completed experience.", "",
             "Regenerate: `python tools/export_character_dossiers.py --output docs/design/resident-dossiers.md`.", "", "| Resident | Temperament | Aspiration |", "| --- | --- | --- |"]
    for profile in profiles.values():
        name = profile["sections"]["identity"]["display_name"]
        lines.append(f"| [{name}](#{name.lower()}) | {profile['core']['temperament']} | {profile['core']['long_term_goal']} |")
    for profile in profiles.values():
        name = profile["sections"]["identity"]["display_name"]
        lines += ["", f"## {name}", "", f"Stable identity: `{profile['resident_id']}`. Original authored age: {profile['sections']['identity']['authored_age_years']}. Pronouns: {profile['sections']['identity']['pronouns']}.", "", "### Decision core", ""]
        for key in CONTRACT["core_fields"]:
            lines.append(f"- **{key.replace('_', ' ').capitalize()}:** {profile['core'][key]}")
        lines += ["", "### Situational facets", ""]
        for key, value in profile["facets"].items():
            lines.append(f"- **{key.capitalize()}:** {value}")
        for section, content in profile["sections"].items():
            lines += ["", f"### {section.replace('_', ' ').capitalize()}", "", "```json", json.dumps(content, ensure_ascii=False, indent=2), "```"]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(), encoding="utf-8", newline="\n")
    print(json.dumps({"output": str(args.output), "residents": 10, "sections_per_resident": 21}))
