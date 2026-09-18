"""Versioned original character dossiers. Loading never installs them into old saves."""
from copy import deepcopy
import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "game" / "data"
CONTRACT = json.loads((DATA / "character_profile_contract.json").read_text(encoding="utf-8"))


def validate_profile(profile, resident_id):
    """Validate the decision-facing contract; retain extensible, dormant JSON verbatim."""
    if not isinstance(profile, dict) or type(profile.get("schema_version")) is not int or profile["schema_version"] != 1:
        raise ValueError("unsupported_character_profile")
    if profile.get("resident_id") != resident_id or profile.get("provenance") != "original_project_genesis":
        raise ValueError("invalid_character_profile_identity")
    for key in ("core", "facets", "sections", "extensions"):
        if not isinstance(profile.get(key), dict):
            raise ValueError("invalid_character_profile_" + key)
    for key in CONTRACT["core_fields"]:
        value = profile["core"].get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > CONTRACT["core_text_limit"]:
            raise ValueError("invalid_character_profile_core")
    for key in CONTRACT["facet_contexts"]:
        value = profile["facets"].get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > CONTRACT["facet_text_limit"]:
            raise ValueError("invalid_character_profile_facet")
    for key in CONTRACT["required_sections"]:
        if not isinstance(profile["sections"].get(key), dict) or not profile["sections"][key]:
            raise ValueError("invalid_character_profile_section")
    if len(json.dumps(profile, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")) > CONTRACT["max_profile_bytes"]:
        raise ValueError("character_profile_storage_limit")
    return profile


def catalogue():
    data = json.loads((DATA / "character_dossiers.json").read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise ValueError("unsupported_character_catalogue")
    for resident_id, profile in data["profiles"].items():
        validate_profile(profile, resident_id)
    return data["profiles"]


def profile_for_new_resident(resident_id):
    """Explicit genesis only. A missing original profile is an error, never a generic clone."""
    return deepcopy(catalogue()[resident_id])
