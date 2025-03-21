#!/bin/bash

# Script to configure Audacity preferences for improved workflow
# This disables project save warnings and overwrite confirmations

set -e

CONFIG_DIR="${HOME}/.config/audacity"
PREFERENCES_FILE="${CONFIG_DIR}/audacity.cfg"

# Backup existing config if it exists
if [[ -f "${PREFERENCES_FILE}" ]]; then
    echo "Creating backup of existing Audacity configuration..."
    cp "${PREFERENCES_FILE}" "${PREFERENCES_FILE}.backup-$(date +%Y%m%d%H%M%S || true)"
fi

# Check if Audacity has been run at least once to create the config
if [[ ! -d "${CONFIG_DIR}" ]]; then
    echo "Audacity config directory not found. Please run Audacity at least once before running this script."
    exit 1
fi

# Create or modify Audacity config
echo "Configuring Audacity preferences..."

# Use sed to modify existing settings or add them if they don't exist
if grep -q "WarningDialogAutoSave=" "${PREFERENCES_FILE}"; then
    sed -i 's/WarningDialogAutoSave=.*/WarningDialogAutoSave=0/' "${PREFERENCES_FILE}"
else
    echo "WarningDialogAutoSave=0" >> "${PREFERENCES_FILE}"
fi

if grep -q "ConfirmOverwrite=" "${PREFERENCES_FILE}"; then
    sed -i 's/ConfirmOverwrite=.*/ConfirmOverwrite=0/' "${PREFERENCES_FILE}"
else
    echo "ConfirmOverwrite=0" >> "${PREFERENCES_FILE}"
fi

if grep -q "EmptyCanBeDirty=" "${PREFERENCES_FILE}"; then
    sed -i 's/EmptyCanBeDirty=.*/EmptyCanBeDirty=0/' "${PREFERENCES_FILE}"
else
    echo "EmptyCanBeDirty=0" >> "${PREFERENCES_FILE}"
fi

if grep -q "ExitAction=" "${PREFERENCES_FILE}"; then
    sed -i 's/ExitAction=.*/ExitAction=1/' "${PREFERENCES_FILE}"
else
    echo "ExitAction=1" >> "${PREFERENCES_FILE}"
fi

echo "Audacity configuration complete. Changes will take effect next time you start Audacity."
echo "A backup of your previous configuration was saved as ${PREFERENCES_FILE}.backup-*"
