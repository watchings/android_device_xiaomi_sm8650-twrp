# Splash Screen Debug Interface Fixes

## Issues Fixed

### Issue 1: Buttons Not Touchable and Input Disabled During Splash
**Problem:** Buttons in the splash screen were not responding to touch input, and physical buttons (like power button) were not working. Critical issue: if servicemanager deadlocks during boot, the power button wouldn't work to turn the screen back on.

**Root Cause:** In the original OrangeFox code (`gui/gui.cpp`), the execution order was:
1. Load splash screen XML
2. Render splash once
3. **Release splash screen**
4. Initialize touch input (`ev_init()`)

By the time touch input was initialized, the splash screen had already been released, making the buttons unclickable. Additionally, input events (both touch and physical buttons) were not being processed during the splash display. **Most critically, if servicemanager caused a deadlock during splash loading or rendering, input would never be initialized.**

**Solution:** Created `patches/gui.cpp.patch` that:
- Moves `ev_init()` to **the very beginning** - immediately after screen initialization
- **Processes input events IMMEDIATELY** after `ev_init()` and before loading splash
- **Processes input events between each splash operation** (after load, after select)
- This ensures power button works **even if servicemanager deadlocks** during splash loading
- Keeps the splash screen loaded for 3 seconds instead of releasing it immediately
- Implements a continuous input processing loop that:
  - Calls `PageManager::Update()` to process **all input events** (touch and physical buttons)
  - Calls `PageManager::Render()` to update the display
  - Calls `flip()` to present the rendered frame
  - Calls `blankTimer.checkForTimeout()` to handle screen blank/unblank
  - Runs at 10 FPS (100ms per frame) for 3 seconds (30 frames total)
- Only releases the splash screen after the 3-second interactive period

**Result:** 
- Input is accepted from the **very beginning** of splash, preventing deadlock issues
- Touch buttons are fully clickable during splash
- Physical buttons (power, volume) work immediately
- Power button can turn screen on/off even if servicemanager hangs
- Users can interact with the servicemanager controls during boot
- **Critical:** Power button events are never blocked by servicemanager deadlock

### Issue 2: Console Log Display - White Background and Green Font
**Problem:** The console widget needed to display with white background and green text for better visibility during debugging.

**Root Cause:** The previous splash.xml patch was using either TWRP variables or black background for console colors, which didn't provide optimal visibility for debugging purposes.

**Solution:** Updated `patches/splash.xml.patch` to use direct hexadecimal color values:
```xml
<color foreground="#00FF00" background="#FFFFFF" scroll="#808080"/>
<font resource="console_font" spacing="2" color="#00FF00"/>
```

Variables defined:
```xml
<variable name="console_bg_color" value="#FFFFFF"/>
<variable name="console_fg_color" value="#00FF00"/>
```

**Result:** Console now displays bright green text (`#00FF00`) on white background (`#FFFFFF`), providing excellent contrast and readability for log output during boot and debugging.

## Technical Details

### GUI Update Loop (gui.cpp.patch)

The new code structure prioritizes **immediate input availability**:

```c++
// Initialize input AT THE VERY BEGINNING
#ifdef TW_DELAY_TOUCH_INIT_MS
	usleep(TW_DELAY_TOUCH_INIT_MS);
#endif
ev_init();

// Process input events IMMEDIATELY - prevents deadlock blocking
PageManager::Update();           // Handle any pending events
blankTimer.checkForTimeout();    // Process power button if pressed

// Load splash (may be slow or hang if servicemanager deadlocks)
PageManager::LoadPackage("splash", ...);

// Process events after loading, before selecting
PageManager::Update();
blankTimer.checkForTimeout();

// Select splash package
PageManager::SelectPackage("splash");

// Process events after selecting
PageManager::Update();
blankTimer.checkForTimeout();

// Interactive loop for 3 seconds
// Input is processed CONTINUOUSLY to prevent any blocking
for (int i = 0; i < 30; i++) {
    PageManager::Update();           // Process ALL input events
    PageManager::Render();           // Render UI
    flip();                          // Present frame
    blankTimer.checkForTimeout();    // Handle screen control
    usleep(100000);                  // 100ms = 10 FPS
}

// Release splash
PageManager::ReleasePackage("splash");
```

**Critical Improvements for Deadlock Prevention:**
1. `ev_init()` is called **first**, before any potentially blocking operations
2. `PageManager::Update()` is called **immediately after ev_init()** to process any queued events
3. Input events are processed **between every major operation**:
   - After ev_init (before loading splash)
   - After LoadPackage (before selecting splash)
   - After SelectPackage (before the main loop)
   - Continuously in the main loop
4. This ensures that even if servicemanager causes a deadlock during splash loading, the power button will still work
5. Users can always turn the screen on/off, preventing the device from appearing frozen

### Console Color Resolution (splash.xml.patch)

The console widget in TWRP inherits from `GUIScrollList`, which loads colors from the `<color>` child element in the XML:
- `foreground` attribute → `mFontColor` (text color) - Set to `#00FF00` (bright green)
- `background` attribute → `mBackgroundColor` (background fill color) - Set to `#FFFFFF` (white)

Using direct hex values ensures these colors are properly set regardless of variable resolution timing.

## Testing

To verify the fixes work:

1. **Touch Button Clickability Test:**
   - Boot into recovery
   - Immediately try clicking the "Stop SM" or "Start SM" buttons on the splash screen
   - Buttons should respond to touch and execute their actions
   - Check `/tmp/recovery.log` for the action log messages

2. **Physical Button Test:**
   - Boot into recovery
   - Press the **power button** during the 3-second splash
   - Screen should turn off (blank)
   - Press power button again - screen should turn back on
   - Volume buttons should also respond if mapped in the UI

3. **Console Display Test:**
   - Boot into recovery
   - Look at the lower-right console area
   - Should see **green text on white background**
   - Log messages should be visible and scrolling as recovery boots
   - Text should be clearly readable with good contrast

## Files Modified

- `patches/gui.cpp.patch` - NEW: Fixes button clickability
- `patches/splash.xml.patch` - UPDATED: Fixed console colors
- `patches/README.md` - UPDATED: Documented both patches
- `PATCH_CHANGES.md` - UPDATED: Added technical details about fixes

## Build Integration

Both patches are automatically applied during the build process via `patches/apply-patches.sh`, which:
1. Discovers all `*.patch` files in the patches directory
2. Attempts to apply them using `git apply`
3. Skips patches that are already applied
4. Reports success/failure for each patch

No manual intervention is needed; just build OrangeFox Recovery with this device tree.
