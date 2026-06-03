# OrangeFox Action Builder
Compile your first custom recovery from OrangeFox Recovery using Github Action.

## Enhanced Features

This device tree includes **critical patches for OrangeFox Recovery** that provide:

- ✅ **Immediate input availability** - prevents input blocking during servicemanager deadlock
- ✅ **Interactive debug interface** - buttons for manual servicemanager control  
- ✅ **Real-time console display** - white background with green text for log output
- ✅ **Physical button support** - power button works from the very beginning of boot
- ✅ **Touchable on-screen buttons** - fully responsive during splash screen

### Documentation

Comprehensive documentation is available in the `docs/` folder:

- **[Implementation Summary](docs/IMPLEMENTATION_SUMMARY.md)** - Features, testing, and integration guide
- **[Splash Fixes](docs/SPLASH_FIXES.md)** - Technical details about input handling fixes
- **[Patch Changes](docs/PATCH_CHANGES.md)** - Patch history and modifications

## How to Use
1. Fork this repository.

2. Go to `Action` tab > `All workflows` > `OrangeFox - Build` > `Run workflow`, then fill all the required information:
 * MANIFEST_BRANCH (`12.1` and `11.0`)
 * DEVICE_TREE (Your device tree repository link.)
 * DEVICE_TREE_BRANCH (Your device tree repository branch.)
 * DEVICE_PATH (`device/vendor/codename`)
 * DEVICE_NAME (Your device codename)
 * BUILD_TARGET (`boot`, `recovery`, `vendorboot`)

## Note
* This action will now only support manifest 12.1 and 11.0, since all orangefox manifest below 11.0 are considered obsolete.
* Make sure your tree uses right variable (updated vars) from OrangeFox; [fox_11.0](https://gitlab.com/OrangeFox/vendor/recovery/-/blob/fox_11.0/orangefox_build_vars.txt) and [fox_12.1](https://gitlab.com/OrangeFox/vendor/recovery/-/blob/fox_12.1/orangefox_build_vars.txt), to avoid build errors.
* Patches in `patches/` directory are automatically applied during build via `apply-patches.sh`

## Supported Devices (SM8650)
- Peridot, Aurora, Ruyi, Houji, Shennong, Chenfeng, Zorn
