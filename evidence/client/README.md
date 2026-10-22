# Actual CLIENT01 setup evidence

Captured on 22 October 2026 from CLIENT01's real Hyper-V framebuffer at 1024 × 768. The screenshot contains the Windows 11 installer inside the guest; host desktop content is excluded. Pixels have not been edited.

![Windows 11 Setup inside CLIENT01](setup.png)

The screenshot records installation in progress. [First-boot inventory](client-first-boot.json) subsequently verified Windows 11 Enterprise Evaluation, build 26300, on CLIENT01 at 13:45 Australia/Sydney. It was still a workgroup member at that point. [Post-join inventory and native join log](post-join-inventory.txt) now show membership in `corp.lab`; a [selected real guest check](secure-channel.txt) records a healthy secure channel and the `CORP\Administrator` session at 14:12. These administrator checks do not establish fictional staff user policy, mapped drives or printer deployment. Evaluation activation, RSAT and effective staff Group Policy still need verification.

[SHA256 manifest](sha256.csv) hashes the published PNG bytes.
