# OrangeFox Recovery Patches

This directory contains patches for OrangeFox Recovery to replace the splash screen with a debug interface for controlling servicemanager.

## Patches

### splash.xml.patch

Replaces the OrangeFox splash screen with a debug interface that includes:

**Element Layering (bottom to top):**

1. **OrangeFox Logo (Background Layer)**
   - Horizontally centered (x=540) on 1080px screen
   - Positioned near bottom at y=1550
   - Scaled to 1.2x for visibility
   - Maintains aspect ratio
   - Renders behind console and buttons

2. **Console Display (Middle Layer)**
   - Fills most of the screen (1040x1460 pixels)
   - Shows real-time log output with green text on black background
   - Uses Roboto-Regular font at 18pt for readability
   - Positioned at top of screen with 20px padding
   - Renders on top of logo

3. **Buttons (Top Layer - Interactive)**
   - **Button 1: Stop SM (Stop ServiceManager)**
     - Orange button (450x100 pixels) at bottom left (x=80, y=1700)
     - Displays "Stop SM" text label in white (28pt font)
     - On click, executes:
       - `stop servicemanager`
       - `stop hwservicemanager`
       - `stop vndservicemanager`
       - `stop keystore2`
       - Logs the action to /tmp/recovery.log
   
   - **Button 2: Start SM (Start ServiceManager)**
     - Orange button (450x100 pixels) at bottom right (x=550, y=1700)
     - Displays "Start SM" text label in white (28pt font)
     - On click, executes:
       - `start servicemanager`
       - Logs the action to /tmp/recovery.log

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
