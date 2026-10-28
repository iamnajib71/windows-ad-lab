# Publish on GitHub

The public repository is `iamnajib71/windows-ad-lab`. The source was published during implementation with its status explicitly marked. The completion update includes five worked ticket outcomes, a real 59.62-second demo, 10 server checks, 6 standard-user client checks and 27 offline tests. Release v1.0.0 follows the final commit's green CI. The commands below document initial creation and publishing; do not recreate the existing repository.

```powershell
git config user.name 'Nazmul Hassan'
git config user.email 'iam.najib@yahoo.com'
git status --short
git check-ignore .env .lab/iso/server-2022-eval.iso
# Review git diff --cached and confirm no secrets, CLIXML, VHDX or raw recordings.
git add .github .gitattributes .gitignore .env.example LICENSE PSScriptAnalyzerSettings.psd1 README.md acceptance config data docs evidence scripts src tests
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

Do not execute that release command until the stated completion gates are satisfied. No Co-Authored-By or attribution trailers are added. `.env.example` contains paths only; actual `.env` and local tool configuration files remain ignored.
