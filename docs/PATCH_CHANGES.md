# Patch Changes Summary

## Latest Updates (Current Version)

### Key Features
All patches are now **generated from actual source modifications** using `git diff` to ensure:
- Correct whitespace and line endings
- Proper hunk headers and context
- Clean application without corruption

### Patch Files

#### patches/gui.cpp.patch
**Purpose:** Fix button touchability, enable physical button support, and **prevent input blocking during servicemanager deadlock**

**Changes:**
1. **Immediate input initialization and processing**
   - `ev_init()` is now called **at the very beginning**, before any splash operations
   - `PageManager::Update()` is called **immediately after ev_init()** to process queued events
   - This ensures input is ready and processing **before** any potentially blocking operations

2. **Continuous input processing to prevent deadlock blocking**
   - Input events are processed **between every major operation**:
     - After `ev_init()` (before loading splash)
     - After `LoadPackage()` (before selecting splash)
     - After `SelectPackage()` (before the main loop)
     - Continuously in the 3-second interactive loop
   - **Critical:** This prevents servicemanager deadlock from blocking input
   - Power button will work even if splash loading hangs

3. **Interactive splash screen loop (3 seconds)**
   - Calls `PageManager::Update()` to process **all input events**:
     - Touch events for on-screen buttons
     - Physical button presses (power, volume up/down)
     - System timers and events
   - Calls `PageManager::Render()` to update the display
   - Calls `flip()` to present frames to screen
   - Calls `blankTimer.checkForTimeout()` to handle screen blank/unblank
   - Runs at 10 FPS (100ms per frame) for 30 frames = 3 seconds

4. **Physical button support**
   - Power button can toggle screen on/off during splash
   - Volume buttons work if mapped in UI
   - All hardware keyboard events are processed
   - **Guaranteed to work even during servicemanager deadlock**

**Result:** 
- Input is accepted from the **very beginning** before any blocking operations
- Buttons are fully clickable
- Physical buttons work immediately
- **Power button events are never blocked** by servicemanager deadlock
- Users can always control screen state, preventing frozen appearance

#### patches/splash.xml.patch
**Purpose:** Create debug splash screen with interactive controls and console display

**Changes:**
1. **Replaced original splash screen** with debug interface
2. **Console display** with **white background (#FFFFFF)** and **green text (#00FF00)**
   - Shows real-time log output from recovery operations
   - Positioned in lower-right corner (540x960, 520x940 pixels)
   - Uses `Roboto-Regular.ttf` font at 18pt for readability
   - Direct color values ensure proper rendering during early boot

3. **Two interactive buttons** in upper section:
   - **"Stop SM"** button (left): Stops servicemanager and related services
   - **"Start SM"** button (right): Starts servicemanager
   - Orange buttons (#FF6600) with white text
   - Fully clickable and responsive

4. **Visual layout:**
   - Black background
   - Orange divider lines
   - OrangeFox logo in lower-left corner
   - Console in lower-right corner

**Result:** Clear, readable console with white background and green text. Fully interactive buttons for servicemanager control.

### Documentation Organization

All documentation except `README.md` has been moved to the `docs/` folder:
- `docs/SPLASH_FIXES.md` - Detailed technical explanation of fixes
- `docs/PATCH_CHANGES.md` - This file, summary of all patch changes

**Layout (screen divided into upper and lower halves):**

1. **Interactive Buttons (Upper Half)**
   
   **Button 1: "Stop SM" (Upper Left)**
   - Orange button (450x100 pixels) at position (80, 200)
   - Displays "Stop SM" text label in white 28pt font
   - Fully clickable and visible in upper half of screen
   - On click executes:
     ```
     stop servicemanager
     stop hwservicemanager
     stop vndservicemanager
     stop keystore2
     echo "Stopped servicemanager and related services" >> /tmp/recovery.log
     ```

   **Button 2: "Start SM" (Upper Right)**
   - Orange button (450x100 pixels) at position (550, 200)
   - Displays "Start SM" text label in white 28pt font
   - Fully clickable and visible in upper half of screen
   - On click executes:
     ```
     start servicemanager
     echo "Started servicemanager" >> /tmp/recovery.log
     ```

2. **Console Display (Lower Half - 1040x940 pixels)**
   - Black background with green monospace text
   - Shows real-time log output from recovery operations
   - Positioned at lower half of screen starting at y=960
   - Uses Roboto-Regular font at 18pt for optimal readability
   - Fills the entire lower half of the 1920px screen
   - **Console Colors:** Uses direct color values (`#00FF00` for green foreground, `#000000` for black background) to ensure text is visible

## Purpose

This debug interface allows developers to:
- Monitor recovery boot process in real-time during the first 3 seconds
- See what's happening during crypto operations
- Manually stop servicemanager if it causes deadlocks (via clickable buttons)
- Restart servicemanager when needed (via clickable buttons)
- Debug timing and service-related issues

## Technical Details

### Why were these patches needed?

**Problem 1: Buttons not clickable**
- Original code sequence: Load splash → Render once → Release splash → Initialize touch input
- Result: By the time touch input was ready, the splash was already gone
- Solution: Initialize touch input FIRST, then keep splash loaded with update loop

**Problem 2: Console all black**
- Console widget uses variable references for colors (`%console_fg_color%`)
- Variables weren't being properly resolved during early boot
- Solution: Use direct hex color values instead (`#00FF00`, `#000000`)

## Build Integration

The patch is automatically applied during the build process via `patches/apply-patches.sh`.

## Testing

To test the patch:
1. Build OrangeFox Recovery with this device tree
2. Flash to device
3. Boot into recovery
4. You should see the debug splash screen with log output and buttons
5. Test clicking the buttons to verify servicemanager control works

## Notes

- The patch uses `stop servicemanager` and `start servicemanager` commands (not `setprop ctl.stop/start`)
- Log output is visible in real-time on the screen
- Button actions are also logged to `/tmp/recovery.log` for debugging
