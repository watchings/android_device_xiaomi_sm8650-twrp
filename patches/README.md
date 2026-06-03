# OrangeFox Recovery Patches

This directory contains patches for OrangeFox Recovery to replace the splash screen with a debug interface for controlling servicemanager.

## Patches

### gui.cpp.patch

Fixes button clickability during splash screen by:
- Moving `ev_init()` (touch input initialization) **before** loading the splash screen
- Keeping the splash screen loaded and interactive for 3 seconds (30 frames at 10 FPS)
- Calling `PageManager::Update()` and `PageManager::Render()` in a loop to process touch events and render updates

**Without this patch:** The original code loads the splash, renders it once, releases it, and only then initializes touch input. This makes buttons completely unresponsive.

**With this patch:** Touch input is initialized first, then the splash remains loaded and updates continuously for 3 seconds, allowing buttons to be clicked and console output to be displayed in real-time.

### splash.xml.patch

Replaces the OrangeFox splash screen with a debug interface that includes:

**Layout (screen divided into upper and lower halves):**

1. **Interactive Buttons (Upper Half - Top Layer)**
   - **Button 1: Stop SM (Stop ServiceManager)**
     - Orange button (450x100 pixels) at upper left (x=80, y=200)
     - Displays "Stop SM" text label in white (28pt font)
     - Clickable and fully visible
     - On click, executes:
       - `stop servicemanager`
       - `stop hwservicemanager`
       - `stop vndservicemanager`
       - `stop keystore2`
       - Logs the action to /tmp/recovery.log
   
   - **Button 2: Start SM (Start ServiceManager)**
     - Orange button (450x100 pixels) at upper right (x=550, y=200)
     - Displays "Start SM" text label in white (28pt font)
     - Clickable and fully visible
     - On click, executes:
       - `start servicemanager`
       - Logs the action to /tmp/recovery.log

2. **Console Display (Lower Half - 1040x940 pixels)**
   - Shows real-time log output with green text on black background
   - Uses Roboto-Regular font at 18pt for readability
   - Positioned at lower half of screen (y=960, height=940)
   - Fills the entire lower half of the screen
   - **Fixed:** Now uses direct color values (`#00FF00` for green foreground, `#000000` for black background) to ensure console text is visible

## How It Works

The patches work together to create a functional debug interface:

1. **gui.cpp.patch** ensures touch input is initialized before the splash loads, and keeps the splash interactive for 3 seconds with continuous updates
2. **splash.xml.patch** defines the visual layout with clickable buttons and a console widget with proper colors

The combined effect allows developers to:
- See real-time log output during the critical first 3 seconds of recovery boot
- Click buttons to manually control servicemanager if needed
- Debug servicemanager-related issues during crypto operations

## Application

Patches are applied automatically during the build process via the `apply-patches.sh` script.

## Purpose

This debug interface helps diagnose and work around servicemanager deadlock issues that can occur during crypto operations on encrypted devices. By showing log output and providing manual control over servicemanager, developers can:
- See what's happening during boot and crypto operations
- Manually stop servicemanager if it's causing deadlocks
- Restart servicemanager when needed
- Debug timing-related issues

## New Patches (Issue Fixes)

### Core Functionality Improvements

#### gui_input_fix.patch
**Problem**: Buttons (physical or touch screen) were not clickable during splash screen. Clicks made during splash were queued and only processed after the splash deadlock released.

**Solution**: 
- Initializes event input system (ev_init) and input_handler **before** loading splash screen
- Adds event processing loop during splash display with 100 iterations of 10ms each
- Processes input events (input_handler.processInput) during splash to make buttons immediately responsive
- Updates PageManager state to handle UI interactions

**Impact**: Buttons are now clickable immediately during splash screen display.

---

#### data_persist_config.patch
**Problem**: Fox stores and reads configs and passwords from /data/.fox or /sdcard/.fox only, which are inaccessible when data decryption fails.

**Solution**:
- Mounts /persist partition when data decryption fails
- Stores Fox settings and passwords in `/persist/Fox` instead of `/data/.fox`
- Falls back to `/data/recovery/Fox` if /persist mount fails
- Enables password and config management even when data partition is encrypted

**Impact**: Settings and passwords are now accessible from /persist when data is encrypted/not decrypted.

---

#### settings_password_restriction.patch
**Problem**: Password changes were restricted when data was not unlocked (tw_is_decrypted == 0), preventing users from managing passwords when data was encrypted.

**Solution**:
- Removes the conditional check for `tw_is_decrypted`
- Allows password changes regardless of encryption/decryption state
- Password will be stored in /persist when data is not decrypted (via data_persist_config.patch)

**Impact**: Users can now change passwords even when data is encrypted. Passwords are stored in /persist in this scenario.

---

## Issues Resolved

1. **Input Blocking During Splash**: Fixed buttons (physical or touch screen) not being clickable during splash screen. Previously, if buttons were clicked during splash, they would not respond but clicks were processed immediately after the splash deadlock released.

2. **Encrypted Data Configuration**: Fox now mounts /persist and stores/reads configs and passwords from `/persist/Fox` when data decryption fails, instead of being limited to /data/.fox or /sdcard/.fox. The restriction preventing password changes when data is not unlocked has been removed - passwords are now stored and read from /persist in this scenario.
