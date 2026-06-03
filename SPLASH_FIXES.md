# Splash Screen Debug Interface Fixes

## Issues Fixed

### Issue 1: Buttons Not Clickable During Splash
**Problem:** Buttons in the splash screen were not responding to touch input.

**Root Cause:** In the original OrangeFox code (`gui/gui.cpp`), the execution order was:
1. Load splash screen XML
2. Render splash once
3. **Release splash screen**
4. Initialize touch input (`ev_init()`)

By the time touch input was initialized, the splash screen had already been released, making the buttons unclickable.

**Solution:** Created `patches/gui.cpp.patch` that:
- Moves `ev_init()` **before** loading the splash screen
- Keeps the splash screen loaded for 3 seconds instead of releasing it immediately
- Implements an update loop that:
  - Calls `PageManager::Update()` to process touch events
  - Calls `PageManager::Render()` to update the display
  - Calls `flip()` to present the rendered frame
  - Runs at 10 FPS (100ms per frame) for 3 seconds (30 frames total)
- Only releases the splash screen after the 3-second interactive period

**Result:** Buttons are now fully clickable, and users can interact with the servicemanager controls during boot.

### Issue 2: Console Log Display Requirements
**Problem:** The console widget needed to display with white background and green text for better visibility.

**Root Cause:** The splash.xml patch was using TWRP variables for console colors:
```xml
<color foreground="%console_fg_color%" background="%console_bg_color%" />
```

During early boot (splash screen phase), the TWRP variable system may not be fully initialized or these specific variables may not be defined, resulting in default black values or failed color resolution.

**Solution:** Updated `patches/splash.xml.patch` to use direct hexadecimal color values:
```xml
<color foreground="#00FF00" background="#FFFFFF" scroll="#808080"/>
<font resource="console_font" spacing="2" color="#00FF00"/>
```

**Result:** Console now displays bright green text (`#00FF00`) on white background (`#FFFFFF`), making log output clearly visible.

## Technical Details

### GUI Update Loop (gui.cpp.patch)

The new code structure:
```c++
// Initialize input FIRST
ev_init();

// Load splash and keep it interactive
PageManager::LoadPackage("splash", ...);
PageManager::SelectPackage("splash");

// Interactive loop for 3 seconds
for (int i = 0; i < 30; i++) {
    PageManager::Update();    // Process events (touch, timers, etc.)
    PageManager::Render();    // Render UI elements
    flip();                   // Present frame to screen
    usleep(100000);          // 100ms = 10 FPS
}

// Now release the splash
PageManager::ReleasePackage("splash");
```

### Console Color Resolution (splash.xml.patch)

The console widget in TWRP inherits from `GUIScrollList`, which loads colors from the `<color>` child element in the XML:
- `foreground` attribute → `mFontColor` (text color) - Set to `#00FF00` (bright green)
- `background` attribute → `mBackgroundColor` (background fill color) - Set to `#FFFFFF` (white)

Using direct hex values ensures these colors are properly set regardless of variable resolution timing.

## Testing

To verify the fixes work:

1. **Button Clickability Test:**
   - Boot into recovery
   - Immediately try clicking the "Stop SM" or "Start SM" buttons
   - Buttons should respond to touch and execute their actions
   - Check `/tmp/recovery.log` for the action log messages

2. **Console Display Test:**
   - Boot into recovery
   - Look at the lower-right console area
   - Should see green text on black background
   - Log messages should be visible and scrolling as recovery boots

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
