/* PCL-iOS Runtime Configuration */
/* This file is used by the iOS app target (via xcodegen) */

#ifndef PCL_IOS_APP_CONFIG_H
#define PCL_IOS_APP_CONFIG_H

/* CurseForge API Key - override via GCC_PREPROCESSOR_DEFINITIONS at build time */
#ifndef CONFIG_CURSEFORGE_API_KEY
#define CONFIG_CURSEFORGE_API_KEY @""
#endif

/* API Endpoints */
#define PCL_CURSEFORGE_API_BASE @"https://api.curseforge.com"
#define PCL_CURSEFORGE_GAME_ID 432
#define PCL_MODRINTH_API_BASE @"https://api.modrinth.com/v2"

/* Minecraft Version Manifest URLs */
#define PCL_MC_MANIFEST_URL @"https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
#define PCL_MC_MANIFEST_BMCLAPI @"https://bmclapi2.bangbang93.com/mc/game/version_manifest.json"

/* Build Settings */
#define PCL_MINIMUM_IOS_VERSION @"14.0"
#define PCL_DEFAULT_GAME_WIDTH 1280
#define PCL_DEFAULT_GAME_HEIGHT 720

#endif /* PCL_IOS_APP_CONFIG_H */
