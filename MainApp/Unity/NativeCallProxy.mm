// ═══════════════════════════════════════════════════════════════
// NativeCallProxy — Bootstrap helper
// ═══════════════════════════════════════════════════════════════
//
// Boot callbacks are handled via NSNotificationCenter in
// Classes/Native/NativeCallStubs.mm → UnityBridge.swift observer.
// This file only provides the ensureNativeDelegate bootstrap.
//
// ═══════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>

// Forward declaration of Swift @_cdecl function
extern "C" void ensureNativeDelegate(void);

// Auto-register the Swift delegate shortly after app launch
__attribute__((constructor))
static void autoRegisterNativeDelegate() {
    dispatch_async(dispatch_get_main_queue(), ^{
        ensureNativeDelegate();
    });
}
