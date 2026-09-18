"""Host-owned Aincrad design pins and bounded proposal declarations; no model calls.

This verifies provenance and structure, not the truth of a model's design rationale.
Semantic compatibility still requires the concrete candidate review and behavior tests.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCUMENTS = ('docs/design/aincrad-world-charter.md', 'docs/design/action-capability-standard.md')
PROTECTED = DOCUMENTS + ('tools/world_design_contract.py', 'tools/gm_runner.py',
                         'tools/gm_autonomy.py', 'tools/validate_gm_autonomy.py')
INVARIANTS = ('setting', 'capabilities', 'agency', 'knowledge', 'continuity', 'execution')
BASES = ('setting_adaptation', 'original_extension', 'engine_maintenance')
INSTRUCTIONS = """
AINCRAD DESIGN CONTRACT:
Read docs/design/aincrad-world-charter.md and docs/design/action-capability-standard.md.
Use the original SAO Aincrad setting. Hundred-floor progression, sword/equipment and
crafting systems are references, not permission to claim unimplemented mechanics.
Do not import D&D spellcasting/classes, ALO flight or GGO gunplay as ordinary Aincrad
abilities. Our persistent original villagers and developer GMs are project extensions.
Preserve setting, capabilities, agency, knowledge, continuity and execution invariants.
New behavior uses the common versioned capability boundary and real resources/consent.
NPCs choose goals; Godot A* navigation, RVO avoidance and real collision move bodies.
Never replace blocked travel with model steering, teleportation or fabricated arrival.
No change and no adoption are valid. Report setting uncertainties for concrete review.
A scope under a pinned design_contract must include design_review with contract_sha256,
setting_basis (setting_adaptation/original_extension/engine_maintenance), a 20..2000
character rationale, and preserves listing all six invariant IDs above. This declaration
is not release approval. A concrete setting violation blocks release; original-GM feedback
must check actual outcomes and preserve failed/unused behavior as evidence.
"""


def reference(root: Path = ROOT) -> dict:
    documents = {}
    for rel in DOCUMENTS:
        path = root / rel
        if not path.is_file() or path.stat().st_size > 100_000:
            raise ValueError(f'design document missing or exceeds 100 KB: {rel}')
        documents[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    digest = hashlib.sha256(json.dumps(documents, sort_keys=True).encode()).hexdigest()
    return {'schema_version': 1, 'id': 'aincrad-v1', 'sha256': digest, 'documents': documents}


def required(policy: dict) -> bool:
    return policy.get('mode') == 'production' or 'design_contract' in policy


def policy_errors(policy: dict, root: Path = ROOT) -> list[str]:
    if not required(policy):
        return []
    try:
        expected = reference(root)
    except (OSError, ValueError) as error:
        return [str(error)]
    if policy.get('design_contract') != expected:
        return ['design_contract must pin the current Aincrad charter and capability standard']
    return []


def scope_errors(scope: dict, policy: dict) -> list[str]:
    if not required(policy):
        return []
    errors = policy_errors(policy)
    review = scope.get('design_review')
    if not isinstance(review, dict):
        return errors + ['scope.design_review is required for the pinned Aincrad contract']
    contract = policy.get('design_contract')
    digest = contract.get('sha256') if isinstance(contract, dict) else None
    if not digest or review.get('contract_sha256') != digest:
        errors.append('scope.design_review must cite the pinned contract_sha256')
    if review.get('setting_basis') not in BASES:
        errors.append('scope.design_review must classify its setting_basis')
    rationale = review.get('rationale')
    if not isinstance(rationale, str) or not 20 <= len(rationale.strip()) <= 2000:
        errors.append('scope.design_review.rationale must explain compatibility in 20..2000 characters')
    preserves = review.get('preserves')
    if (not isinstance(preserves, list) or not all(isinstance(v, str) for v in preserves)
            or sorted(preserves) != sorted(INVARIANTS)):
        errors.append('scope.design_review.preserves must acknowledge each invariant exactly once')
    return errors


def normalized_review(scope: dict) -> dict:
    review = scope['design_review']
    return {key: review[key] for key in ('contract_sha256', 'setting_basis', 'rationale', 'preserves')}
