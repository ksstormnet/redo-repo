# Script Migration Guide

This guide explains the process of migrating scripts from the old directory structure (`scripts/`) to the new organized structure with categorized directories (`01-lvm/`, `02-studio/`, `03-plasma/`, `04-apps/`, and `05-tweaks/`).

## Migration Strategy

### Overall Structure

The new structure organizes scripts into categorized directories:

1. **01-lvm/** - LVM (Logical Volume Manager) setup and configuration scripts
2. **02-studio/** - Audio studio, low-latency, and real-time audio configuration scripts
3. **03-plasma/** - KDE Plasma desktop environment installation and configuration
4. **04-apps/** - Application installation and configuration scripts
5. **05-tweaks/** - System optimizations and tweaks that don't fit into other categories

### Mapping Old Scripts to New Structure

The old structure organized scripts by installation phase rather than functionality:

- `scripts/00-core/` → Core system setup (maps to various categories)
- `scripts/10-desktop/` → Desktop environment setup (maps to `03-plasma/`)
- `scripts/20-development/` → Development tools (maps to `04-apps/`)
- `scripts/30-applications/` → Applications (maps to `04-apps/`)
- `scripts/40-optimization/` → System optimizations (maps to `02-studio/` and `05-tweaks/`)

## Migration Tools

We've created two tools to assist with the migration process:

### 1. migration-helper.sh

This script analyzes the old and new script structures to identify:

- Which old scripts need to be migrated
- Where they should be placed in the new structure
- If similar scripts already exist in the new structure
- What functionality might be missing in the new structure

Usage:

```bash
./migration-helper.sh
```

### 2. migrate-rt-audio.sh

This is an example script that demonstrates how to migrate a specific script (the real-time audio configuration). You can use this as a template for creating other migration scripts.

Usage:

```bash
./migrate-rt-audio.sh
```

## Best Practices for Migration

1. **Start with the Migration Helper**: Run `./migration-helper.sh` to get a clear picture of what needs to be migrated.

2. **Migrate One Script at a Time**: Focus on migrating one script at a time, ensuring quality and full functionality before moving to the next one.

3. **Use shellcheck**: After creating or modifying a script, run shellcheck to ensure it adheres to best practices:

   ```bash
   shellcheck -x <script-path>
   ```

4. **Update Script Headers**: Ensure all migrated scripts have updated headers with:

   - Proper script name and path
   - Description that reflects its functionality
   - shellcheck directive for source inclusions

   ```bash
   # shellcheck disable=SC1091,SC2154
   ```

5. **Maintain Common Script Structure**:

   - Header section with description
   - Library imports
   - Script name definition
   - Function definitions
   - Main function that calls other functions
   - Script execution section

6. **Use State Management**: Maintain the state management system to avoid duplicate executions:

   ```bash
   if check_state "${SCRIPT_NAME}_some_operation_completed"; then
       log_info "Operation already completed. Skipping..."
       return 0
   fi

   # ...operations...

   set_state "${SCRIPT_NAME}_some_operation_completed"
   ```

7. **Test Each Script**: After migration, test each script in isolation and as part of the whole system.

## Migration Workflow

1. Run the migration helper to identify which scripts need migration
2. Choose a script to migrate
3. Create a new script in the appropriate directory with the new naming convention
4. Adapt the content from the old script, ensuring it follows the best practices
5. Run shellcheck to verify script quality
6. Test the new script
7. Update the migration helper output to reflect the completed migration
8. Repeat for the next script

## Status Tracking

Keep track of migration progress:

| Old Script                                      | Status       | New Script                          | Notes                             |
| ----------------------------------------------- | ------------ | ----------------------------------- | --------------------------------- |
| `scripts/00-core/04-lowlatency-kernel.sh`       | ✅ Completed | `02-studio/00-lowlatency-kernel.sh` |                                   |
| `scripts/40-optimization/02-real-time-audio.sh` | ✅ Completed | `02-studio/02-realtime-config.sh`   | Example migration script provided |
| `scripts/20-development/00-web-development.sh`  | ✅ Completed | `04-apps/03-web-development.sh`     | Interactive migration completed   |
| ...                                             | Pending      |                                     |                                   |

## Final Steps

Once all scripts have been migrated:

1. Update the main installer script to use the new structure
2. Test the complete system
3. Create documentation about the new script structure
4. Archive the old scripts for reference
