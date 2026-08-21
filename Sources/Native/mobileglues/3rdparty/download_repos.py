#!/usr/bin/env python3
"""Download glslang and SPIRV-Cross source files from GitHub API."""

import json
import os
import sys
import time
import urllib.request
import urllib.error

GITHUB_API_BASE = "https://api.github.com/repos/KhronosGroup"
RAW_BASE = "https://raw.githubusercontent.com/KhronosGroup"

# Directories to download for glslang
GLSLANG_DIRS = ["glslang", "SPIRV", "OGLCompilersDLL", "StandAlone", "include", "External"]
GLSLANG_ROOT_FILES = ["CMakeLists.txt", "Android.mk", "BUILD.gn", "DEPS"]

# For SPIRV-Cross, we need specific files at root level
SPIRV_CROSS_ROOT_FILES = [
    "CMakeLists.txt",
    "Makefile",
    "main.cpp",
    "spirv_cross.cpp",
    "spirv_cross.h",
    "spirv_parser.cpp",
    "spirv_parser.h",
    "spirv_cross_parsed_ir.cpp",
    "spirv_cross_parsed_ir.h",
    "spirv_cfg.cpp",
    "spirv_cfg.h",
    "spirv_glsl.cpp",
    "spirv_glsl.h",
    "spirv_hlsl.cpp",
    "spirv_hlsl.h",
    "spirv_msl.cpp",
    "spirv_msl.h",
    "spirv_reflect.cpp",
    "spirv_reflect.h",
    "spirv_resources.cpp",
    "spirv_resources.h",
    "common.hpp",
    "spirv.hpp",
    "spirv_cross.hpp",
    "GLSL.std.450.h",
    "NonSemanticShaderDebugInfo100.h",
]

SPIRV_CROSS_DIRS = ["include", "cmake"]


def api_get(url):
    """Make a GitHub API request."""
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Python-Download-Script',
        'Accept': 'application/vnd.github.v3+json',
    })
    try:
        resp = urllib.request.urlopen(req, timeout=30)
        return json.loads(resp.read())
    except Exception as e:
        print(f"  API error: {e}")
        return None


def download_file(url, dest_path):
    """Download a file from raw.githubusercontent.com."""
    req = urllib.request.Request(url, headers={'User-Agent': 'Python-Download-Script'})
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        data = resp.read()
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)
        with open(dest_path, 'wb') as f:
            f.write(data)
        return True
    except Exception as e:
        print(f"  Download error: {e}")
        return False


def list_directory(repo, path):
    """List contents of a directory via GitHub API."""
    url = f"{GITHUB_API_BASE}/{repo}/contents/{path}?ref=main"
    return api_get(url)


def download_directory(repo, path, dest_dir, recursive=True):
    """Recursively download a directory."""
    items = list_directory(repo, path)
    if items is None:
        print(f"  Failed to list: {path}")
        return 0
    
    count = 0
    for item in items:
        if item['type'] == 'file':
            dest_path = os.path.join(dest_dir, item['path'])
            print(f"  Downloading: {item['path']} ({item['size']} bytes)")
            if download_file(item['download_url'], dest_path):
                count += 1
            else:
                print(f"  FAILED: {item['path']}")
        elif item['type'] == 'dir' and recursive:
            count += download_directory(repo, item['path'], dest_dir)
    return count


def download_repo(repo_name, dest_root, dirs=None, root_files=None):
    """Download a repository's files."""
    print(f"\n=== Downloading {repo_name} ===")
    print(f"Destination: {dest_root}")
    os.makedirs(dest_root, exist_ok=True)
    
    total = 0
    
    # Download root-level files
    if root_files:
        for filename in root_files:
            url = f"{RAW_BASE}/{repo_name}/main/{filename}"
            dest_path = os.path.join(dest_root, filename)
            print(f"  Downloading: {filename}")
            if download_file(url, dest_path):
                total += 1
            else:
                print(f"  FAILED: {filename}")
    
    # Download directories
    if dirs:
        for dir_name in dirs:
            print(f"\n  Processing directory: {dir_name}")
            items = list_directory(repo_name, dir_name)
            if items is None:
                print(f"  Directory not found or empty: {dir_name}")
                continue
            count = download_directory(repo_name, dir_name, dest_root)
            total += count
            print(f"  Downloaded {count} files from {dir_name}")
    
    print(f"\nTotal files downloaded for {repo_name}: {total}")
    return total


def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Download glslang
    glslang_dest = os.path.join(base_dir, "glslang")
    download_repo(
        "glslang",
        glslang_dest,
        dirs=GLSLANG_DIRS,
        root_files=GLSLANG_ROOT_FILES
    )
    
    # Download SPIRV-Cross
    spirv_cross_dest = os.path.join(base_dir, "SPIRV-Cross")
    download_repo(
        "SPIRV-Cross",
        spirv_cross_dest,
        dirs=SPIRV_CROSS_DIRS,
        root_files=SPIRV_CROSS_ROOT_FILES
    )
    
    print("\n=== Download complete ===")


if __name__ == "__main__":
    main()
