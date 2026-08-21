#ifndef _BS_OVERLAY_FILE_SYSTEM_H_
#define _BS_OVERLAY_FILE_SYSTEM_H_

#include "common.h"
#include "file_system.h"

// OverlayFileSystem implements GameMaker's two-area sandboxed file system on top of plain stdio.
// It holds two base paths:
// * bundlePath: read-only "File Bundle" area, where Included Files and the data.win live.
// * savePath: read/write "Save Area", the only place writes are allowed.
//
// Read operations check savePath first and fall back to bundlePath.
// Writes always target savePath. delete only acts on savePath (it will not touch a same-named file in the bundle).
//
// https://manual.gamemaker.io/lts/en/Additional_Information/The_File_System.htm
typedef struct {
    FileSystem base;
    char* bundlePath; // includes trailing '/'
    char* savePath; // includes trailing '/'
    char* workingDirectoryOverride; // includes trailing '/', or nullptr. Set by FS_set_working_directory.
} OverlayFileSystem;

OverlayFileSystem* OverlayFileSystem_create(const char* bundlePath, const char* savePath);
void OverlayFileSystem_destroy(OverlayFileSystem* fs);

// Hot-swaps the save area (FS_set_gm_save_area). Creates the directory tree if missing. Trailing '/' optional.
void OverlayFileSystem_setSavePath(OverlayFileSystem* fs, const char* path);

// Sets the working_directory override (FS_set_working_directory). Creates the directory tree if missing.
void OverlayFileSystem_setWorkingDirectory(OverlayFileSystem* fs, const char* path);

#endif /* _BS_OVERLAY_FILE_SYSTEM_H_ */
