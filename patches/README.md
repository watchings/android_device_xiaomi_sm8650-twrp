# OrangeFox Recovery Patches

This directory contains patches for OrangeFox Recovery to replace the splash screen with a debug interface for controlling servicemanager.

## Patches

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

## How It Works

The patch modifies `gui/theme/portrait_hdpi/splash.xml` to:
- Replace the graphical splash screen with a console displaying log output
- Add two interactive buttons for manually controlling servicemanager
- Provide real-time visibility into recovery operations
- Allow debugging of servicemanager-related issues

## Application

Patches are applied automatically during the build process via the `apply-patches.sh` script.

## Purpose

This debug interface helps diagnose and work around servicemanager deadlock issues that can occur during crypto operations on encrypted devices. By showing log output and providing manual control over servicemanager, developers can:
- See what's happening during boot and crypto operations
- Manually stop servicemanager if it's causing deadlocks
- Restart servicemanager when needed
- Debug timing-related issues
