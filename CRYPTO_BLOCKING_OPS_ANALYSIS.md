# TW_INCLUDE_CRYPTO Blocking Operations - Analysis and Patches

## Date: 2026-06-02

## Problem Statement

When `TW_INCLUDE_CRYPTO := true` is enabled in BoardConfig.mk, the OrangeFox Recovery source code introduces several blocking operations that can cause the recovery to hang or become unresponsive. These operations include:

1. Database copy operations
2. Retry loops with sleep delays
3. User decryption attempts
4. File existence checks with delays

## Source Code Analysis

Analysis of the OrangeFox Recovery source code in `$RUNNER_TEMP/recovery` revealed the following blocking operations:

### 1. twrp.cpp (Line 252)

**Function:** `android::keystore::copySqliteDb()`

**Issue:** 
- Copies SQLite keystore database
- Can block for extended period depending on database size and I/O performance
- Called during recovery startup before decrypt page loads

**Impact:** Delays recovery boot

**Status:** ✅ Already patched (commented out in existing twrp.cpp.patch)

### 2. partition.cpp (Lines 837-839)

**Blocking Code:**
```cpp
int retry_count = 3;
while (!android::keystore::Decrypt_DE() && --retry_count)
    usleep(2000);
```

**Issue:**
- Retries `Decrypt_DE()` operation 3 times
- Each retry waits 2000 microseconds (2ms)
- Total potential blocking time: up to 6ms
- `Decrypt_DE()` itself may block internally

**Impact:** Small delay during data partition setup

### 3. partition.cpp (Line 846)

**Blocking Code:**
```cpp
int pwd_type = android::keystore::Get_Password_Type(0, filename);
```

**Issue:**
- Queries keystore for password type
- Can block if keystore service is not responsive
- May involve IPC with keystore daemon

**Impact:** Potential hang if keystore unavailable

### 4. partitionmanager.cpp (Line 2279)

**Blocking Code:**
```cpp
user.type = android::keystore::Get_Password_Type(userId, filename);
```

**Issue:**
- Same as #3 but called for each user during user parsing
- Multiple users = multiple blocking calls
- Compounds the blocking issue

**Impact:** Cumulative delays for multi-user systems

### 5. partitionmanager.cpp (Lines 2367-2368)

**Blocking Code:**
```cpp
int retry_count = 10;
while (!TWFunc::Path_Exists("/data/system/users/gatekeeper.password.key") && --retry_count)
    usleep(2000);
```

**Issue:**
- Waits for gatekeeper file to appear
- Retries 10 times with 2ms delay each
- Total potential blocking time: up to 20ms
- File may never appear if data partition has issues

**Impact:** 20ms delay minimum during decrypt attempt

### 6. partitionmanager.cpp (Lines 2370, 2382-2383)

**Blocking Code:**
```cpp
if (android::keystore::Decrypt_User(user_id, Password)) {
    // ...
    if (android::keystore::Decrypt_User(tmp_user_id, Password) ||
        (Password != "!" && android::keystore::Decrypt_User(tmp_user_id, "!"))) {
        // ...
    }
}
```

**Issue:**
- `Decrypt_User()` performs actual decryption
- Can block for several seconds per user
- Multiple calls for user 0 and all other users
- Involves cryptographic operations and keystore IPC

**Impact:** Major blocking - several seconds per user, can cause apparent hang

## Solution: TW_SKIP_CRYPTO_BLOCKING_OPS Flag

### Implementation Strategy

Rather than removing crypto functionality entirely, we introduce a compile-time flag `TW_SKIP_CRYPTO_BLOCKING_OPS` that:

1. **Preserves crypto support** - Keeps `TW_INCLUDE_CRYPTO := true`
2. **Skips blocking operations** - Bypasses retry loops, waits, and blocking calls
3. **Uses safe defaults** - Returns default values instead of querying
4. **Maintains compatibility** - Code still compiles and runs with crypto enabled

### Patches Created

#### 1. BoardConfig.mk

**Change:** Added new flag
```makefile
# Skip blocking crypto operations to prevent hangs
TW_SKIP_CRYPTO_BLOCKING_OPS := true
```

**Effect:** Enables all blocking operation skips in source code

#### 2. partition.cpp.patch

**Changes:**

**A. Skip Decrypt_DE retry loop (lines 837-839):**
```cpp
#ifdef TW_SKIP_CRYPTO_BLOCKING_OPS
    // Skip blocking Decrypt_DE operation to prevent hang
    LOGINFO("Skipping Decrypt_DE retry loop (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)\n");
    int retry_count = 0;  // Don't retry
#else
    int retry_count = 3;
    while (!android::keystore::Decrypt_DE() && --retry_count)
        usleep(2000);
#endif
```

**B. Skip Get_Password_Type (line 846):**
```cpp
#ifdef TW_SKIP_CRYPTO_BLOCKING_OPS
    // Skip blocking Get_Password_Type operation
    LOGINFO("Skipping Get_Password_Type (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)\n");
    int pwd_type = 0;  // Default password type
    (void)filename;  // Suppress unused warning
#else
    int pwd_type = android::keystore::Get_Password_Type(0, filename);
    if (pwd_type < 0) {
        LOGERR("This build does not have synthetic password decrypt support\n");
        pwd_type = 0;  // default password
    }
    PartitionManager.Parse_Users();
#endif
```

#### 3. partitionmanager.cpp.patch

**Changes:**

**A. Skip Get_Password_Type per user (line 2279):**
```cpp
#ifdef TW_SKIP_CRYPTO_BLOCKING_OPS
    // Skip blocking Get_Password_Type operation
    LOGINFO("Skipping Get_Password_Type for user %d (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)\n", userId);
    user.type = 0;  // Default password type
    (void)filename;  // Suppress unused warning
#else
    user.type = android::keystore::Get_Password_Type(userId, filename);
#endif
```

**B. Skip gatekeeper file wait (lines 2367-2368):**
```cpp
#ifdef TW_SKIP_CRYPTO_BLOCKING_OPS
    // Skip blocking wait for gatekeeper file
    LOGINFO("Skipping gatekeeper file wait (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)\n");
#else
    while (!TWFunc::Path_Exists("/data/system/users/gatekeeper.password.key") && --retry_count)
        usleep(2000);
#endif
```

**C. Skip all Decrypt_User operations (lines 2370-2408):**
```cpp
gui_msg(Msg("decrypting_user_fbe=Attempting to decrypt FBE for user {1}...")(user_id));
#ifndef TW_SKIP_CRYPTO_BLOCKING_OPS
    if (android::keystore::Decrypt_User(user_id, Password)) {
        // ... existing decrypt logic ...
    } else {
        gui_msg(Msg(msg::kError, "decrypt_user_fail_fbe=Failed to decrypt user {1}")(user_id));
        return -1;
#else
    // Skip all blocking Decrypt_User operations
    LOGINFO("Skipping Decrypt_User operations (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)\n");
#endif
    }
```

## Patch Application

The patches are automatically applied during the build process by the `patches/apply-patches.sh` script. The script:

1. Discovers all `*.patch` files in the patches directory
2. Attempts to apply each patch to the OrangeFox source
3. Reports success/failure/skip for each patch
4. Continues build even if some patches fail (device tree overrides provide fallback)

**Patch files:**
- `patches/twrp.cpp.patch` (existing - comments out copySqliteDb)
- `patches/partition.cpp.patch` (new - skips Decrypt_DE and Get_Password_Type)
- `patches/partitionmanager.cpp.patch` (new - skips all user decrypt operations)

## Impact Analysis

### With Patches Applied (TW_SKIP_CRYPTO_BLOCKING_OPS := true)

**Pros:**
✅ No blocking waits or retries during boot
✅ No delays from keystore IPC
✅ Recovery boots faster
✅ No hangs from unresponsive crypto services
✅ Crypto support still compiled in (for future use)

**Cons:**
❌ User decryption will not work (Decrypt_User calls skipped)
❌ Password type detection disabled (always defaults to type 0)
❌ Device-encrypted (DE) storage not decrypted automatically
❌ Multi-user decryption not supported

**Use Case:**
- Devices where crypto is causing boot hangs
- Development/testing environments
- Situations where decryption is not required
- Debugging recovery boot issues

### Without Patches (TW_SKIP_CRYPTO_BLOCKING_OPS not set)

**Pros:**
✅ Full crypto functionality preserved
✅ User decryption works
✅ Password type detection functional
✅ Multi-user support intact

**Cons:**
❌ Potential blocking delays (6ms + 20ms + seconds per user)
❌ Risk of hangs if keystore unresponsive
❌ Slower boot time
❌ May cause splash screen hang on some devices

**Use Case:**
- Production builds where decryption is required
- Devices with stable crypto implementation
- When user data access is essential

## Comparison with Previous Fixes

| Issue | Previous Fix | This Fix |
|-------|--------------|----------|
| **logd crash loop** | Disable logd service | N/A (orthogonal issue) |
| **servicemanager deadlock** | Start/stop cycle | N/A (different component) |
| **copySqliteDb blocking** | Comment out call | ✅ Already handled |
| **Decrypt_DE retry** | None | ✅ Skip retry loop |
| **Get_Password_Type** | None | ✅ Skip, use default |
| **gatekeeper file wait** | None | ✅ Skip wait |
| **Decrypt_User blocking** | None | ✅ Skip all decrypt ops |

**Relationship to other fixes:**
- **Complementary** to logd fix (both prevent boot hangs)
- **Independent** of servicemanager fix (different systems)
- **Builds upon** existing twrp.cpp.patch (enhances it)

## Testing Instructions

### Build with Patches

```bash
# The flag is already set in BoardConfig.mk
# Just build normally
m recoveryimage
```

### Verify Patches Applied

Check build log for:
```
Applying partition.cpp... SUCCESS
Applying partitionmanager.cpp... SUCCESS
```

### Runtime Verification

After flashing recovery:

```bash
# Check for log messages indicating skips
adb shell dmesg | grep "Skipping"

# Expected output:
# "Skipping Decrypt_DE retry loop (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)"
# "Skipping Get_Password_Type (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)"
# "Skipping gatekeeper file wait (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)"
# "Skipping Decrypt_User operations (TW_SKIP_CRYPTO_BLOCKING_OPS enabled)"
```

### Disable Patches (if needed)

To revert to normal crypto behavior:

1. Edit `BoardConfig.mk`
2. Comment out or remove: `TW_SKIP_CRYPTO_BLOCKING_OPS := true`
3. Rebuild recovery

## Known Limitations

1. **No User Decryption**
   - Encrypted user data cannot be decrypted
   - Workaround: Boot to Android to decrypt, then reboot to recovery

2. **Default Password Types**
   - Always assumes default password type (type 0)
   - May not work with non-standard lock types

3. **No DE Storage Access**
   - Device-encrypted storage not automatically decrypted
   - May affect some recovery features that need DE data

4. **Multi-User Unsupported**
   - Only works for single-user or unencrypted scenarios
   - Multi-user encrypted devices won't decrypt properly

## Recommendations

### For Production Use

- **If decryption works:** Don't enable TW_SKIP_CRYPTO_BLOCKING_OPS
- **If boot hangs occur:** Enable the flag as temporary workaround
- **Long-term solution:** Fix underlying keystore/crypto issues

### For Development

- **Enable by default** to avoid boot issues
- **Disable only when testing crypto** specifically
- **Document any crypto-dependent features** that won't work

### For End Users

- **Flash with caution** if encrypted data access is needed
- **Backup data first** before testing
- **Use decryption-free features** (flash, backup, etc.)

## Files Modified

```
BoardConfig.mk                          - Added TW_SKIP_CRYPTO_BLOCKING_OPS flag
patches/partition.cpp.patch             - New patch to skip blocking ops
patches/partitionmanager.cpp.patch      - New patch to skip decrypt ops
CRYPTO_BLOCKING_OPS_ANALYSIS.md         - This documentation
```

## Related Documentation

- `LOGD_FIX_SUMMARY.md` - logd crash loop fix
- `SPLASH_SCREEN_FIX_README.md` - Complete splash screen fixes
- `ENHANCED_FIX_SUMMARY.md` - servicemanager deadlock fix

---

**Version:** 1.0  
**Date:** 2026-06-02  
**Status:** Ready for testing  
**Priority:** Medium (optional optimization)  
**Impact:** Reduces blocking delays but disables decryption
