# Publish on GitHub

The repository is intended to be public at `iamnajib71/windows-ad-lab`. Publishing source before live verification must retain the README's incomplete status. Release v1.0.0 should be published only once the evidence register, five worked ticket outcomes, real demo and live acceptance gates are complete. A draft release is not a finished lab.

```powershell
git config user.name 'Nazmul Hassan'
git config user.email 'iam.najib@yahoo.com'
git status --short
git check-ignore .env AGENTS.md CLAUDE.md .lab/iso/server-2022-eval.iso
# Review git diff --cached and confirm no secrets, CLIXML, VHDX or raw recordings.
git add .github .gitignore .env.example LICENSE PSScriptAnalyzerSettings.psd1 README.md acceptance config data docs evidence scripts src tests
git diff --cached --check
git commit -m 'Build Windows AD lab automation and support runbooks'
gh repo create iamnajib71/windows-ad-lab --public --source . --remote origin
git push -u origin main
gh repo edit iamnajib71/windows-ad-lab --description 'Windows Server AD lab: PowerShell identity tasks, Group Policy, RSAT and support troubleshooting.' --add-topic active-directory --add-topic group-policy --add-topic windows-server --add-topic powershell --add-topic homelab --add-topic it-support --add-topic sysadmin
gh run list --repo iamnajib71/windows-ad-lab --limit 5
```

After real evidence and demo are reviewed/committed, confirm the latest main commit's CI is green. Record repo, exact CI run and release URLs. Prepare release notes in a file and use `--notes-file`; do not construct multiline release notes in shell strings.

```powershell
gh release create v1.0.0 --repo iamnajib71/windows-ad-lab --target main --title 'Windows AD Lab v1.0.0' --notes-file docs/release-notes-v1.0.0.md
```

Do not execute that release command until the stated completion gates are satisfied. No Co-Authored-By or attribution trailers are added. `.env.example` contains paths only; actual `.env`, AGENTS.md and CLAUDE.md remain ignored.
