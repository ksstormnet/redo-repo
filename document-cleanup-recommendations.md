# Document Cleanup Recommendations

This document provides recommendations for cleaning up the documentation structure in the Restart-Critical project.

## Changes Already Made

1. **Created scripts-preparation directory**
   - Extracted `backup_critical_data.sh` script from `backup-recovery.md`
   - Added a README.md file explaining the purpose of the script

2. **Moved backup-recovery.md to plans directory**
   - This document contains valuable backup and recovery procedures that should be preserved

## Recommendations for Remaining Documents

The following documents in the parent directory are outdated or redundant and should be deleted:

1. **project-plan.md**
   - Outdated and less detailed than `migration-plan.md` in the plans directory
   - Recommendation: Delete this file

2. **pre-installation.md**
   - Contains scripts that have been replaced by the automated process
   - The valuable `backup_critical_data.sh` script has been extracted
   - Recommendation: Delete this file

3. **ubuntu-server-lvm-installation.md**
   - Manual approach to LVM setup that has been automated by the scripts in the `bare-to-lvm` directory
   - Recommendation: Delete this file

4. **kde-installation.md**
   - Manual approach to KDE installation that has been automated by the scripts in the `scripts` directory
   - Recommendation: Delete this file

## Recommended Document Structure

After these changes, the document structure would be:

```
/media/scott/Restart-Critical/
├── bare-to-lvm/               # LVM setup scripts
│   ├── 00-lvm-prepare.sh
│   ├── 01-lvm-setup.sh
│   ├── 02-lvm-logical-volumes.sh
│   ├── 03-lvm-mount-config.sh
│   ├── 04-lvm-post-install.sh
│   └── lvm-readme.md          # Main documentation for LVM setup
│
├── plans/                     # Planning documents
│   ├── consolidated-lvm-plan-revised.md
│   ├── migration-plan.md      # Main planning document
│   └── backup-recovery.md     # Moved from parent directory
│
├── scripts/                   # System installation scripts
│   ├── 00-initial-setup.sh
│   ├── ...
│   ├── 17-final-cleanup.sh
│   ├── config-management-functions.sh
│   └── master-installer-script.sh
│
└── scripts-preparation/       # New directory for preparation scripts
    ├── backup_critical_data.sh # Extracted from backup-recovery.md
    └── README.md              # Documentation for preparation scripts
```

## Conclusion

The current scripts in the `bare-to-lvm` and `scripts` directories faithfully and completely execute the plan contemplated in the documents in the `plans` directory. The documents in the parent directory are largely outdated or redundant and should be deleted as recommended above.

By consolidating the documentation and removing outdated files, you'll have a cleaner, more maintainable system setup plan that accurately reflects the current automated approach to system installation and configuration.
