# Preserved project source variants — September 24, 2026

The user requested upload of all project code after pausing development. The active game and tools remain in their normal repository paths. This directory preserves historical source variants and unfinished drafts found in local project branches and worktrees; it does not activate them or claim that their features work.

The [manifest](manifest.json) identifies every reviewed source record by original path and origin. Of 142 records, 116 already have equivalent content in published Git history and 26 require exact-byte snapshots (615,958 bytes). Each `remote_git_blob` can be read from a full clone with `git cat-file blob <object-id>`. For a snapshot record, open its linked file and use its original `path` to understand the intended location. The SHA-256 and size describe the original local bytes; CRLF-to-LF equivalents are explicitly marked where relevant. Do not blindly overlay these historical variants onto the current game.

The contact-memory proposal and its acceptance fixture are unfinished: the production API is absent. Old code revisions, candidate probes, the historical navigation-report typo, and machine-specific launchers are preserved as source evidence only. The six launchers may reference older checkouts or need local settings. Nothing in this source archive has been executed for this upload.

Project branches, registered project worktrees and project entry launchers were inspected. Unrelated local applications, ephemeral tool-test repositories, private world saves and original billing ledgers, credentials, raw session logs, generated caches and process output are outside this source upload. Existing authorized restart-world checkpoints remain under `worlds/`. The previously untracked LocalJev service source is separately preserved under [integrations/localjev](../../../../integrations/localjev/README.md).

## Newly preserved versions

| Original path | Origin | Exact source snapshot |
| --- | --- | --- |
| `game/core/town_trade.gd` | unpublished_git_source | [Source](files/d1dfea21951007d4e8cff70d1b443a24be75326c3c963ab06bd10f03709ed764.gd) |
| `tools/run_town_model_validation.py` | unpublished_git_source | [Source](files/38130ce21e1f4d2417942956234811a7611498a2d875e3aa2a875b021d27d57c.py) |
| `tools/test_town_model_validation_budget.py` | unpublished_git_source | [Source](files/efbdbfbb1b316cf1515133beed52052b2263bc1e54d8ad7fbfeccdfb3810c53f.py) |
| `game/agents/BudgetGatewayProvider.cs` | unpublished_git_source | [Source](files/aae7398fb1aa28876893764bf38093342adc72e1624841aed623d1dbffa8045a.cs) |
| `game/agents/town_turns.gd` | unpublished_git_source | [Source](files/53a9593645ff245e3514b7de1f67ccf53d54cb8ff3ad2af7c9d3b7fde99f357c.gd) |
| `tools/test_town_model_validation_budget.py` | unpublished_git_source | [Source](files/42f684e3584f6f28cf2a5aed0aa4023a4898ecedd1f538b63d1b55abe6504688.py) |
| `tools/run_town_model_validation.py` | unpublished_git_source | [Source](files/d8f4afbe81d9385787843be5261df680ec788d3b445cab487c9ccf9646c2c94b.py) |
| `tools/test_town_model_validation_budget.py` | unpublished_git_source | [Source](files/a25c3a62078cb27e5a113330335efdae2d1f966c149fe314520a1a670ba2881b.py) |
| `tools/run_town_model_validation.py` | unpublished_git_source | [Source](files/052a93dd209d9ccf27efafe4cd214875898b135d25fc1219176431fe9acfb40b.py) |
| `tools/test_town_model_validation_budget.py` | unpublished_git_source | [Source](files/50738ed6e21a00e9798e61f1465ebb91fbca93eecc281301966518d850ec7df6.py) |
| `game/agents/BudgetGatewayProvider.cs` | unpublished_git_source | [Source](files/a43978c57fd3b2b0842e348c19080a2299a8a19e7eb91a3a4f02512cdf5ed3f5.cs) |
| `tools/test_town_model_validation_budget.py` | unpublished_git_source | [Source](files/63ffda76b43acf827d406310eb624413be72af5a3c26dbb99bdd39c0f3a5d4c9.py) |
| `game/agents/town_turns.gd` | worktree-05 | [Source](files/4b832cadceb804f4e8e317c44fa3efe5bb1c774c7a298844fedf029a550aff0f.gd) |
| `game/agents/town_turns.gd` | worktree-06 | [Source](files/6de5f1b392b86604cb3029825ffea47719efb58066543360075374da25174df4.gd) |
| `game/tests/private_baker_provider_probe.gd` | worktree-14 | [Source](files/41ccade5bdbabee03a259b7b2ef2fb622ac2040709544ba69afcd487d46a1468.gd) |
| `docs/design/resident-contact-memory-v1.md` | worktree-22 | [Source](files/b9138172dfdc6fa3c55b71259479139aebe94922dd41b3d2104ec03f9170de0b.md) |
| `game/tests/town_contact_memory_acceptance.gd` | worktree-22 | [Source](files/43a8320afd8617dd1ae97fd9a5a26888fcdb7a25cd26e846dd1ecace077b448f.gd) |
| `game/tests/town_need_transition_wake_acceptance.gd` | worktree-23 | [Source](files/d2253d3bc030fde5411012405837fd232a79968dfbd0e8e46bf57bb37df04757.gd) |
| `docs/validation/navigation-mvp-formal-resident-2026-09-20.md` | worktree-26 | [Source](files/ef4fc3af8caf230e19f7cb17cad7f1d41ac603a2bf646a53a14a436c1468b298.md) |
| `game/tests/town_contract_affordance_acceptance.gd` | worktree-31 | [Source](files/6027661145d784911a681717bf6026b9097fc34fcc384c365a5fa7bd0dc18365.gd) |
| `OpenLatestWorld.cmd` | entry-launchers | [Source](files/0c624d19f4fdbb74423045e5cba85878320d028c9fb8316acbaf09f38adc4bb7.cmd) |
| `OpenLivingWorld.cmd` | entry-launchers | [Source](files/7281dad5b9c6f6bb5d03e04625dfade07163249a984ad8a78640c24e888219e1.cmd) |
| `StartLivingAI.cmd` | entry-launchers | [Source](files/aaaba5f86b82d032b280be073dc59c477e02e7177a9c43d4f71ea2b72eef3aa1.cmd) |
| `PullJevModel.cmd` | entry-launchers | [Source](files/7f2111f2282314ca4f5309d167760c17a2cc8eb2cb9a27e17cd0b1ab70d0e29f.cmd) |
| `StartLocalJev.cmd` | entry-launchers | [Source](files/89e6780dc7c7c1ff245f8c5f7926b9298abf8d8e89b75443ea2fc283697f0382.cmd) |
| `StartOllama.cmd` | entry-launchers | [Source](files/d44ecf8a582d69fd822e1503d36269fb0d5c8cea194feb7b738ed194f4a0f8ae.cmd) |
