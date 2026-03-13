// ═══════════════════════════════════════════════════════════════
// NativeCallStubs — C function stubs for Unity DllImport calls
// ═══════════════════════════════════════════════════════════════
//
// These are compiled into UnityFramework so libGameAssembly.a
// can find the symbols. The actual Swift implementations are
// called via the delegate pattern in MainApp/Unity/NativeCallProxy.mm.
//
// When the NativeCallProxy delegate is registered (from Swift),
// these stubs forward to Swift. Before registration, they're no-ops.
//
// ═══════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>

// Forward declaration of the delegate protocol
@protocol NativeCallsProtocol <NSObject>
@required
- (void)onUnityReady;
- (void)onAuthBridged;
- (void)onGPSLocked;
- (void)onHexHistoryLoaded:(NSString*)count;
- (void)onTilesLoaded;
- (void)onZonesLoaded:(NSString*)count;
- (void)onBootComplete;
- (void)setPlayerId:(NSString*)playerId;
- (void)onInventoryUpdate:(NSString*)jsonString;
- (void)setClaimable:(NSString*)hexId isSteal:(BOOL)isSteal ownerName:(NSString*)ownerName;
- (void)clearClaimable;
- (void)setHexStats:(int)owned total:(int)total;
- (void)onClaimResult:(BOOL)success wasSteal:(BOOL)wasSteal message:(NSString*)message;
@end

// Shared delegate — set from MainApp side via registerNativeDelegate()
__attribute__((visibility("default")))
id<NativeCallsProtocol> _nativeCallDelegate = nil;

extern "C" {

void registerNativeDelegate(id<NativeCallsProtocol> delegate) {
    _nativeCallDelegate = delegate;
}

void _onUnityReady() {
    if (_nativeCallDelegate) [_nativeCallDelegate onUnityReady];
}

void _onAuthBridged() {
    if (_nativeCallDelegate) [_nativeCallDelegate onAuthBridged];
}

void _onGPSLocked() {
    if (_nativeCallDelegate) [_nativeCallDelegate onGPSLocked];
}

void _onHexHistoryLoaded(const char* count) {
    if (_nativeCallDelegate) {
        NSString *s = count ? [NSString stringWithUTF8String:count] : @"0";
        [_nativeCallDelegate onHexHistoryLoaded:s];
    }
}

void _onTilesLoaded() {
    if (_nativeCallDelegate) [_nativeCallDelegate onTilesLoaded];
}

void _onZonesLoaded(const char* count) {
    if (_nativeCallDelegate) {
        NSString *s = count ? [NSString stringWithUTF8String:count] : @"0";
        [_nativeCallDelegate onZonesLoaded:s];
    }
}

void _onBootComplete() {
    if (_nativeCallDelegate) [_nativeCallDelegate onBootComplete];
}

void _setPlayerId(const char* playerId) {
    if (_nativeCallDelegate) {
        NSString *s = playerId ? [NSString stringWithUTF8String:playerId] : @"";
        [_nativeCallDelegate setPlayerId:s];
    }
}

void _onInventoryUpdate(const char* jsonString) {
    if (_nativeCallDelegate) {
        NSString *s = jsonString ? [NSString stringWithUTF8String:jsonString] : @"{}";
        [_nativeCallDelegate onInventoryUpdate:s];
    }
}

void _setClaimable(const char* hexId, bool isSteal, const char* ownerName) {
    if (_nativeCallDelegate) {
        NSString *hex = hexId ? [NSString stringWithUTF8String:hexId] : @"";
        NSString *owner = ownerName ? [NSString stringWithUTF8String:ownerName] : @"";
        [_nativeCallDelegate setClaimable:hex isSteal:isSteal ownerName:owner];
    }
}

void _clearClaimable() {
    if (_nativeCallDelegate) [_nativeCallDelegate clearClaimable];
}

void _setHexStats(int owned, int total) {
    if (_nativeCallDelegate) [_nativeCallDelegate setHexStats:owned total:total];
}

void _onClaimResult(bool success, bool wasSteal, const char* message) {
    if (_nativeCallDelegate) {
        NSString *msg = message ? [NSString stringWithUTF8String:message] : @"";
        [_nativeCallDelegate onClaimResult:success wasSteal:wasSteal message:msg];
    }
}

} // extern "C"
