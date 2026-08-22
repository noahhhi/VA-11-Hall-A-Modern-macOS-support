#ifndef _BS_STEAM_BRIDGE_H_
#define _BS_STEAM_BRIDGE_H_

#include <stdbool.h>

// Minimal bridge to Valve's public Steamworks flat C API. The Steamworks
// runtime is loaded from beside the executable so non-Steam builds continue to
// run without linking against or redistributing the SDK.
bool SteamBridge_init(void);
void SteamBridge_runCallbacks(void);
void SteamBridge_shutdown(void);

bool SteamBridge_isInitialized(void);
bool SteamBridge_areStatsReady(void);
const char* SteamBridge_getPersonaName(void);
bool SteamBridge_getAchievement(const char* achievementName, bool* achieved);
bool SteamBridge_setAchievement(const char* achievementName);

#endif
