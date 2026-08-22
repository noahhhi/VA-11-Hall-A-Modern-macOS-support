#include "steam_bridge.h"

#include "log.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifdef __APPLE__
#include <dlfcn.h>
#include <limits.h>
#include <mach-o/dyld.h>

typedef int32_t (*SteamAPIInitFlatFn)(char* errorMessage);
typedef void (*SteamAPIShutdownFn)(void);
typedef void (*SteamAPIRunCallbacksFn)(void);
typedef void* (*SteamAPIGetInterfaceFn)(void);
typedef const char* (*SteamAPIGetPersonaNameFn)(void* friends);
typedef bool (*SteamAPIGetAchievementFn)(void* userStats, const char* name, bool* achieved);
typedef bool (*SteamAPISetAchievementFn)(void* userStats, const char* name);
typedef bool (*SteamAPIStoreStatsFn)(void* userStats);

typedef struct SteamBridgeState {
    void* library;
    void* userStats;
    void* friends;
    bool initialized;
    bool statsReady;
    SteamAPIShutdownFn shutdown;
    SteamAPIRunCallbacksFn runCallbacks;
    SteamAPIGetPersonaNameFn getPersonaName;
    SteamAPIGetAchievementFn getAchievement;
    SteamAPISetAchievementFn setAchievement;
    SteamAPIStoreStatsFn storeStats;
} SteamBridgeState;

static SteamBridgeState steam;

static bool loadSymbol(void* library, const char* name, void* output, size_t outputSize) {
    void* symbol = dlsym(library, name);
    if (symbol == NULL || outputSize != sizeof(symbol)) return false;
    memcpy(output, &symbol, sizeof(symbol));
    return true;
}

static bool executableSiblingPath(char* output, size_t outputSize, const char* filename) {
    uint32_t executablePathSize = PATH_MAX;
    char executablePath[PATH_MAX];
    if (_NSGetExecutablePath(executablePath, &executablePathSize) != 0) return false;

    char* slash = strrchr(executablePath, '/');
    if (slash == NULL) return false;
    *slash = '\0';
    int written = snprintf(output, outputSize, "%s/%s", executablePath, filename);
    return written > 0 && (size_t)written < outputSize;
}
#endif

bool SteamBridge_init(void) {
#ifdef __APPLE__
    if (steam.initialized) return true;

    char libraryPath[PATH_MAX];
    if (!executableSiblingPath(libraryPath, sizeof(libraryPath), "libsteam_api.dylib")) {
        logWarn("Steamworks: could not resolve libsteam_api.dylib path\n");
        return false;
    }

    steam.library = dlopen(libraryPath, RTLD_NOW | RTLD_LOCAL);
    if (steam.library == NULL) {
        logWarn("Steamworks: unavailable (%s)\n", dlerror());
        return false;
    }

    SteamAPIInitFlatFn initFlat = NULL;
    SteamAPIGetInterfaceFn getUserStats = NULL;
    SteamAPIGetInterfaceFn getFriends = NULL;
    bool loaded =
        loadSymbol(steam.library, "SteamAPI_InitFlat", &initFlat, sizeof(initFlat)) &&
        loadSymbol(steam.library, "SteamAPI_Shutdown", &steam.shutdown, sizeof(steam.shutdown)) &&
        loadSymbol(steam.library, "SteamAPI_RunCallbacks", &steam.runCallbacks, sizeof(steam.runCallbacks)) &&
        loadSymbol(steam.library, "SteamAPI_SteamUserStats_v013", &getUserStats, sizeof(getUserStats)) &&
        loadSymbol(steam.library, "SteamAPI_ISteamUserStats_GetAchievement", &steam.getAchievement, sizeof(steam.getAchievement)) &&
        loadSymbol(steam.library, "SteamAPI_ISteamUserStats_SetAchievement", &steam.setAchievement, sizeof(steam.setAchievement)) &&
        loadSymbol(steam.library, "SteamAPI_ISteamUserStats_StoreStats", &steam.storeStats, sizeof(steam.storeStats));

    if (!loaded) {
        logWarn("Steamworks: installed library is missing a required public API symbol\n");
        dlclose(steam.library);
        memset(&steam, 0, sizeof(steam));
        return false;
    }

    char errorMessage[1024] = {0};
    if (initFlat(errorMessage) != 0) {
        logWarn("Steamworks: initialization failed%s%s\n",
            errorMessage[0] ? ": " : "", errorMessage);
        dlclose(steam.library);
        memset(&steam, 0, sizeof(steam));
        return false;
    }

    steam.userStats = getUserStats();
    if (steam.userStats == NULL) {
        logWarn("Steamworks: user stats interface is unavailable\n");
        steam.shutdown();
        dlclose(steam.library);
        memset(&steam, 0, sizeof(steam));
        return false;
    }

    // RequestCurrentStats was removed from the current ISteamUserStats v013
    // flat ABI. Steam now loads the current user's stats before game startup;
    // a valid v013 interface is therefore the readiness boundary.
    steam.statsReady = true;
    steam.initialized = true;

    if (loadSymbol(steam.library, "SteamAPI_SteamFriends_v018", &getFriends, sizeof(getFriends)) &&
        loadSymbol(steam.library, "SteamAPI_ISteamFriends_GetPersonaName", &steam.getPersonaName, sizeof(steam.getPersonaName))) {
        steam.friends = getFriends();
    }

    logInfo("Steamworks: initialized with user stats support\n");
    return true;
#else
    return false;
#endif
}

void SteamBridge_runCallbacks(void) {
#ifdef __APPLE__
    if (steam.initialized) steam.runCallbacks();
#endif
}

void SteamBridge_shutdown(void) {
#ifdef __APPLE__
    if (!steam.initialized) return;
    steam.shutdown();
    dlclose(steam.library);
    memset(&steam, 0, sizeof(steam));
    logInfo("Steamworks: shut down\n");
#endif
}

bool SteamBridge_isInitialized(void) {
#ifdef __APPLE__
    return steam.initialized;
#else
    return false;
#endif
}

bool SteamBridge_areStatsReady(void) {
#ifdef __APPLE__
    return steam.initialized && steam.statsReady;
#else
    return false;
#endif
}

const char* SteamBridge_getPersonaName(void) {
#ifdef __APPLE__
    if (steam.initialized && steam.friends != NULL && steam.getPersonaName != NULL) {
        const char* name = steam.getPersonaName(steam.friends);
        return name != NULL ? name : "";
    }
#endif
    return "";
}

bool SteamBridge_getAchievement(const char* achievementName, bool* achieved) {
#ifdef __APPLE__
    if (!SteamBridge_areStatsReady() || achievementName == NULL || achieved == NULL) return false;
    return steam.getAchievement(steam.userStats, achievementName, achieved);
#else
    (void)achievementName;
    (void)achieved;
    return false;
#endif
}

bool SteamBridge_setAchievement(const char* achievementName) {
#ifdef __APPLE__
    if (!SteamBridge_areStatsReady() || achievementName == NULL || achievementName[0] == '\0') return false;
    if (!steam.setAchievement(steam.userStats, achievementName)) return false;
    // Valve requires StoreStats after SetAchievement for persistence and the
    // in-game achievement notification.
    return steam.storeStats(steam.userStats);
#else
    (void)achievementName;
    return false;
#endif
}
