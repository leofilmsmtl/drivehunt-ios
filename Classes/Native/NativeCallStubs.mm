// ═══════════════════════════════════════════════════════════════
// NativeCallStubs — C function stubs for Unity DllImport calls
// ═══════════════════════════════════════════════════════════════
//
// Compiled into UnityFramework so IL2CPP (libGameAssembly.a)
// can find the symbols via [DllImport("__Internal")].
//
// Posts NSNotifications so the main app (Swift) can observe them.
// NSNotificationCenter works across framework boundaries.
//
// ═══════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>

extern "C" {

void registerNativeDelegate(id delegate) {
    // No-op — we use NSNotificationCenter instead of delegate.
}

void _onUnityReady() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onUnityReady"}];
    });
}

void _onAuthBridged() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onAuthBridged"}];
    });
}

void _onGPSLocked() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onGPSLocked"}];
    });
}

void _onHexHistoryLoaded(const char* count) {
    NSString* c = count ? [NSString stringWithUTF8String:count] : @"0";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onHexHistoryLoaded", @"arg": c}];
    });
}

void _onTilesLoaded() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onTilesLoaded"}];
    });
}

void _onZonesLoaded(const char* count) {
    NSString* c = count ? [NSString stringWithUTF8String:count] : @"0";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onZonesLoaded", @"arg": c}];
    });
}

void _onHexTexturesReady() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onHexTexturesReady"}];
    });
}

void _onBootComplete() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onBootComplete"}];
    });
}

void _setPlayerId(const char* playerId) {
    NSString* p = playerId ? [NSString stringWithUTF8String:playerId] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"setPlayerId", @"arg": p}];
    });
}

void _onInventoryUpdate(const char* jsonString) {
    NSString* j = jsonString ? [NSString stringWithUTF8String:jsonString] : @"{}";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"onInventoryUpdate", @"arg": j}];
    });
}

// Capture callbacks
void _setClaimable(const char* hexId, bool isSteal, const char* ownerName) {
    NSString* hex = hexId ? [NSString stringWithUTF8String:hexId] : @"";
    NSString* owner = ownerName ? [NSString stringWithUTF8String:ownerName] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil
            userInfo:@{@"signal": @"setClaimable", @"hexId": hex, @"isSteal": @(isSteal), @"ownerName": owner}];
    });
}

void _clearClaimable() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil userInfo:@{@"signal": @"clearClaimable"}];
    });
}

void _setHexStats(int owned, int total) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil
            userInfo:@{@"signal": @"setHexStats", @"owned": @(owned), @"total": @(total)}];
    });
}

void _onClaimResult(bool success, bool wasSteal, const char* message) {
    NSString* msg = message ? [NSString stringWithUTF8String:message] : @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"UnityBootCallback" object:nil
            userInfo:@{@"signal": @"onClaimResult", @"success": @(success), @"wasSteal": @(wasSteal), @"message": msg}];
    });
}

// ═══════════════════════════════════════════════════════════════
// TEMPORARY: Old IL2CPP build references _NativeOn* names.
// These forward to the real _on* functions above.
// Remove after next Unity rebuild.
// ═══════════════════════════════════════════════════════════════
void _NativeOnUnityReady() { _onUnityReady(); }
void _NativeOnAuthBridged() { _onAuthBridged(); }
void _NativeOnGPSLocked() { _onGPSLocked(); }
void _NativeOnHexHistoryLoaded(const char* c) { _onHexHistoryLoaded(c); }
void _NativeOnTilesLoaded() { _onTilesLoaded(); }
void _NativeOnZonesLoaded(const char* c) { _onZonesLoaded(c); }
void _NativeOnBootComplete() { _onBootComplete(); }

} // extern "C"
