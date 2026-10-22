# Windows AD Lab v1.0.0

A real Windows Server 2022 Evaluation domain controller and domain-joined Windows 11 Enterprise Evaluation client, managed through Group Policy on Hyper-V.

- PowerShell infrastructure and CSV identity workflows, including WhatIf, reset/must-change, unlock, group changes, leavers and stale reports.
- AD DS, DNS, DHCP, department OUs/groups, AGDLP shares, private homes and access-based enumeration.
- Applied user/computer GPO evidence, three RSAT consoles and five reproduced/repaired support faults.
- Same-GUID Recycle Bin restore and a completed System State backup.
- A 59.62-second actual onboarding/client-policy GIF, transcripts and SHA256 evidence manifests.
- A learning walkthrough explaining the build order, commands, troubleshooting decisions, start/stop procedures and repeatable practice.

Validation: 27 offline Pester tests and zero PSScriptAnalyzer findings; 10 live server checks and 6 actual standard-user client checks passed. GitHub Actions independently runs offline validation.

Limits: one DC/client, evaluation software, no production change management, physical printer, independent backup device, System State restore, complete patch/restart cycle or Entra ID/Intune. A historical transient printer preference error remains documented. Recorded-result review screenshots are clearly labelled and backed by actual raw outputs.
