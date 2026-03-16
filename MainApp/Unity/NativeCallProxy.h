#ifndef NativeCallProxy_h
#define NativeCallProxy_h

#import <Foundation/Foundation.h>

@protocol NativeCallsProtocol
@required
- (void)onUnityReady;
- (void)onAuthBridged;
- (void)onGPSLocked;
- (void)onHexHistoryLoaded:(NSString*)count;
- (void)onTilesLoaded;
- (void)onZonesLoaded:(NSString*)count;
- (void)onBootComplete;
- (void)onHexTexturesReady;
- (void)onTextureProgress:(NSString*)progress;
- (void)onAtlasProgress:(NSString*)progress;
- (void)onInventoryUpdate:(NSString*)jsonString;
- (void)setPlayerId:(NSString*)playerId;
@end

// Register the Swift delegate from native side
#ifdef __cplusplus
extern "C" {
#endif
void registerNativeDelegate(id<NativeCallsProtocol> delegate);
#ifdef __cplusplus
}
#endif

#endif /* NativeCallProxy_h */
