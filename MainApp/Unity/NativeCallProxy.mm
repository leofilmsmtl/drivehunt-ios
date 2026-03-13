// ═══════════════════════════════════════════════════════════════
// NativeCallProxy — Auto-registers Swift delegate at app launch
// ═══════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

extern "C" void ensureNativeDelegate(void);

// Auto-register the Swift delegate shortly after app launch
__attribute__((constructor))
static void autoRegisterNativeDelegate() {
    dispatch_async(dispatch_get_main_queue(), ^{
        ensureNativeDelegate();
    });
}
