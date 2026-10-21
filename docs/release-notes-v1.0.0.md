# Windows AD Lab v1.0.0 - draft notes

Release gate: **not met yet**. Do not publish these draft notes as a completed-lab release.

Implemented source: Hyper-V provisioning and private setup media on H:, guest-native evaluation setup, AD/DNS/DHCP setup, OU/group design, identity lifecycle scripts, department shares, policy configuration, RSAT, recovery scripts, PSScriptAnalyzer CI and domain-independent Pester tests. The old host-side image/boot-repair path is retired.

Verified so far: the real Server evaluation domain controller, nine server acceptance checks, fictional identity operations, shared virtual printer creation and Recycle Bin object restore. Results are linked in the evidence register.

Outstanding verification: client domain/GPO acceptance, five executed tickets with evidence, RSAT screenshots, System State backup, 30-90 second onboarding/policy demo and green CI for the final evidence commit.

Replace this draft with observed results and links once every gate is complete. Disclose evaluation licensing, small lab scale and documented limits.
