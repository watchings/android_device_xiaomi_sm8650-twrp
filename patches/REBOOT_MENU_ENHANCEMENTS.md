# Reboot Menu Enhancements

This document describes the patches that add new buttons to the OrangeFox reboot menu.

## Overview

These patches add two new buttons to the reboot menu:
1. **Open OrangeFox** - Returns to the OrangeFox main view WITHOUT rebooting the device
2. **Goto Fastbootd** - Launches fastbootd mode WITHOUT rebooting the device

## Modified Files

The following files are modified by these patches:

### 1. gui/objects.hpp.patch
Adds function declarations for the new action handlers:
- `int openfox(std::string arg)` - Handler for returning to OrangeFox main view
- `int gotofastbootd(std::string arg)` - Handler for launching fastbootd mode

### 2. gui/action.cpp.patch
Implements the action handlers and registers them:
- Registers `openfox` and `gotofastbootd` actions in the action map
- Implements `GUIAction::openfox()` - calls `gui_changePage("main")` to return to main view
- Implements `GUIAction::gotofastbootd()` - sets fastbootd property and calls `gui_changePage("fastboot")`

### 3. gui/theme/portrait_hdpi/pages/reboot.xml.patch
Adds the UI elements to the reboot menu:
- Adds "Open OrangeFox" listitem with mobile_wrench icon
- Adds "Goto Fastbootd" listitem with reboot_fastboot icon (shown only when fastboot mode is available)

## Technical Details

### Open OrangeFox Button
- **Function**: `openfox`
- **Action**: Navigates to the main OrangeFox page using `gui_changePage("main")`
- **Behavior**: Returns the user to the OrangeFox main menu without rebooting
- **Icon**: mobile_wrench

### Goto Fastbootd Button
- **Function**: `gotofastbootd`
- **Action**: Sets `ro.orangefox.fastbootd` property to "1" and navigates to fastboot page
- **Behavior**: Launches fastbootd mode without rebooting the device
- **Icon**: reboot_fastboot
- **Condition**: Only shown when `tw_fastboot_mode` is set to "1"

## Testing

All patches have been tested against `$RUNNER_TEMP/recovery` and apply cleanly:

```bash
cd $RUNNER_TEMP/recovery
git apply --check patches/gui/objects.hpp.patch        # ✓ OK
git apply --check patches/gui/action.cpp.patch         # ✓ OK
git apply --check patches/gui/theme/portrait_hdpi/pages/reboot.xml.patch  # ✓ OK
```

## Application

These patches are automatically applied by the `apply-patches.sh` script during the build process. The script discovers patches based on the file hierarchy and applies them in alphabetical order.

## File Hierarchy

```
patches/
├── gui/
│   ├── action.cpp.patch
│   ├── objects.hpp.patch
│   └── theme/
│       └── portrait_hdpi/
│           └── pages/
│               └── reboot.xml.patch
```

## Compatibility

These patches are compatible with:
- OrangeFox Recovery (fox_14.1 branch)
- TWRP-based recoveries using similar GUI framework

## Notes

- The "Goto Fastbootd" button only appears when fastboot mode is available (`tw_fastboot_mode=1`)
- Both buttons provide quick access to recovery features without the overhead of a full reboot
- The patches maintain consistency with existing OrangeFox UI patterns and code style
