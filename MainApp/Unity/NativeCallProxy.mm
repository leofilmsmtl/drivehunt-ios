// ═══════════════════════════════════════════════════════════════
// NativeCallProxy — Direct C functions for Unity C# → Swift boot callbacks
// Replaces the delegate pattern which caused app freezes.
// Unity C# calls these via [DllImport("__Internal")]
// ═══════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

// Forward declarations of Swift @_cdecl functions
extern "C" void ensureNativeDelegate(void);
extern "C" void nativeOnUnityReady(void);
extern "C" void nativeOnAuthBridged(void);
extern "C" void nativeOnGPSLocked(void);
extern "C" void nativeOnHexHistoryLoaded(const char* count);
extern "C" void nativeOnTilesLoaded(void);
extern "C" void nativeOnZonesLoaded(const char* count);
extern "C" void nativeOnBootComplete(void);
extern "C" void nativeSetPlayerId(const char* playerId);
extern "C" void nativeOnInventoryUpdate(const char* jsonString);

// Auto-register the Swift delegate shortly after app launch
__attribute__((constructor))
static void autoRegisterNativeDelegate() {
    dispatch_async(dispatch_get_main_queue(), ^{
        ensureNativeDelegate();
    });
}

// ═══════════════════════════════════════════════════════════════
// C entry points called by Unity C# via [DllImport("__Internal")]
// Each dispatches to main queue then calls Swift
// ═══════════════════════════════════════════════════════════════

extern "C" {

void _NativeOnUnityReady() {
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnUnityReady(); });
}

void _NativeOnAuthBridged() {
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnAuthBridged(); });
}

void _NativeOnGPSLocked() {
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnGPSLocked(); });
}

void _NativeOnHexHistoryLoaded(const char* count) {
    NSString* str = count ? [NSString stringWithUTF8String:count] : @"0";
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnHexHistoryLoaded([str UTF8String]); });
}

void _NativeOnTilesLoaded() {
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnTilesLoaded(); });
}

void _NativeOnZonesLoaded(const char* count) {
    NSString* str = count ? [NSString stringWithUTF8String:count] : @"0";
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnZonesLoaded([str UTF8String]); });
}

void _NativeOnBootComplete() {
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnBootComplete(); });
}

void _NativeSetPlayerId(const char* playerId) {
    NSString* str = playerId ? [NSString stringWithUTF8String:playerId] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{ nativeSetPlayerId([str UTF8String]); });
}

void _NativeOnInventoryUpdate(const char* jsonString) {
    NSString* str = jsonString ? [NSString stringWithUTF8String:jsonString] : @"{}";
    dispatch_async(dispatch_get_main_queue(), ^{ nativeOnInventoryUpdate([str UTF8String]); });
}

} // extern "C"
