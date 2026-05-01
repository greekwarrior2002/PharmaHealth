#!/usr/bin/env python3
"""
Generates PharmaHealth.xcodeproj/project.pbxproj from the on-disk source layout.

Run from the repo root:
    python3 scripts/generate_pbxproj.py

This is intended as a one-shot scaffolder — once Xcode opens the project it
manages the file itself. Re-run only if you add new top-level files outside
Xcode.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "PharmaHealth"
WIDGET_DIR = ROOT / "PharmaHealthWidget"
PROJECT_NAME = "PharmaHealth"
WIDGET_NAME = "PharmaHealthWidget"
BUNDLE_ID = "com.yourdomain.pharmahealth"
WIDGET_BUNDLE_ID = "com.yourdomain.pharmahealth.widget"

# Files that live under PharmaHealth/ but are also compiled into the widget
# (model layer + RefillCalculator + Color/View extensions used by the widget).
SHARED_RELATIVE_PATHS = {
    "Models/Appointment.swift",
    "Models/CaregiverProfile.swift",
    "Models/DoseEntry.swift",
    "Models/Medication.swift",
    "Models/SymptomLog.swift",
    "Services/RefillCalculator.swift",
    "Utilities/Extensions.swift",
}


def make_id(prefix: str, n: int) -> str:
    """Make a deterministic 24-character hex ID from a prefix + counter."""
    suffix = f"{n:020X}"
    s = (prefix + suffix)[:24].upper()
    if len(s) != 24 or any(c not in "0123456789ABCDEF" for c in s):
        raise ValueError(f"Bad id {s!r}")
    return s


class IdAllocator:
    def __init__(self, prefix: str) -> None:
        self.prefix = prefix
        self.counter = 0

    def next(self) -> str:
        self.counter += 1
        return make_id(self.prefix, self.counter)


def list_swift_files(folder: Path) -> list[Path]:
    return sorted(p for p in folder.rglob("*.swift") if p.is_file())


def relpath(p: Path, base: Path) -> str:
    return str(p.relative_to(base)).replace(os.sep, "/")


def main() -> None:
    file_ids = IdAllocator("AAAA")
    app_build_ids = IdAllocator("BBBB")
    widget_build_ids = IdAllocator("CCCC")
    group_ids = IdAllocator("DDDD")
    target_ids = IdAllocator("EEEE")
    phase_ids = IdAllocator("FFFF")

    # --- Source file inventory -------------------------------------------------

    app_swift = list_swift_files(APP_DIR)
    widget_swift = list_swift_files(WIDGET_DIR)

    # Build a flat mapping for app files.
    # Each app file gets a fileRef + a buildRef in the app target.
    # If the relative path is in SHARED_RELATIVE_PATHS, it ALSO gets a buildRef
    # in the widget target.

    file_refs: dict[Path, str] = {}
    app_build_refs: list[tuple[str, Path]] = []      # (build_id, path)
    widget_build_refs: list[tuple[str, Path]] = []

    for path in app_swift:
        fid = file_ids.next()
        file_refs[path] = fid
        bid = app_build_ids.next()
        app_build_refs.append((bid, path))

    for path in widget_swift:
        fid = file_ids.next()
        file_refs[path] = fid
        bid = widget_build_ids.next()
        widget_build_refs.append((bid, path))

    # Shared files: add a widget build ref too.
    for path in app_swift:
        rel = relpath(path, APP_DIR)
        if rel in SHARED_RELATIVE_PATHS:
            bid = widget_build_ids.next()
            widget_build_refs.append((bid, path))

    # --- Resources & plists ---------------------------------------------------

    app_assets = APP_DIR / "Assets.xcassets"
    widget_assets = WIDGET_DIR / "Assets.xcassets"
    app_info = APP_DIR / "Info.plist"
    app_entitlements = APP_DIR / "PharmaHealth.entitlements"
    widget_info = WIDGET_DIR / "Info.plist"
    widget_entitlements = WIDGET_DIR / "PharmaHealthWidget.entitlements"

    file_refs[app_assets] = file_ids.next()
    file_refs[widget_assets] = file_ids.next()
    file_refs[app_info] = file_ids.next()
    file_refs[app_entitlements] = file_ids.next()
    file_refs[widget_info] = file_ids.next()
    file_refs[widget_entitlements] = file_ids.next()

    app_assets_build = app_build_ids.next()
    widget_assets_build = widget_build_ids.next()

    # --- Products -------------------------------------------------------------

    app_product_id = file_ids.next()
    widget_product_id = file_ids.next()
    products_group_id = group_ids.next()

    # The widget .appex needs a build ref so the app can embed it.
    embed_widget_build_id = app_build_ids.next()

    # --- SwiftPM (RevenueCat) -------------------------------------------------

    pkg_ref_id = "66660000000000000000001A"[:24]
    pkg_product_id = "66660000000000000000002A"[:24]
    pkg_link_build_id = app_build_ids.next()

    # --- Targets / phases / configs ------------------------------------------

    project_id = "BEEFCAFE0000000000000001"
    main_group_id = group_ids.next()

    app_target_id = target_ids.next()
    widget_target_id = target_ids.next()

    app_sources_phase = phase_ids.next()
    app_frameworks_phase = phase_ids.next()
    app_resources_phase = phase_ids.next()
    app_embed_phase = phase_ids.next()

    widget_sources_phase = phase_ids.next()
    widget_frameworks_phase = phase_ids.next()
    widget_resources_phase = phase_ids.next()

    proxy_id = "5555000000000000000000AA"
    dep_id = "5555000000000000000000BB"

    config_proj_debug = "3333000000000000000000A1"
    config_proj_release = "3333000000000000000000A2"
    config_app_debug = "3333000000000000000000B1"
    config_app_release = "3333000000000000000000B2"
    config_widget_debug = "3333000000000000000000C1"
    config_widget_release = "3333000000000000000000C2"

    list_proj = "4444000000000000000000A0"
    list_app = "4444000000000000000000B0"
    list_widget = "4444000000000000000000C0"

    # --- Group hierarchy ------------------------------------------------------
    #
    # We mirror the on-disk layout as PBXGroups so Xcode's navigator matches
    # what's in git.

    # group_id -> (name, sourcetree, [child_ids], path?)
    groups: dict[str, dict] = {}

    def build_group_for_dir(dir_path: Path, name: str | None = None) -> str:
        gid = group_ids.next()
        children: list[str] = []

        # Subdirectories first (alphabetical)
        subdirs = sorted(p for p in dir_path.iterdir() if p.is_dir() and p.suffix not in {".xcassets", ".appiconset", ".colorset"})
        for sub in subdirs:
            children.append(build_group_for_dir(sub, name=sub.name))

        # Then the actual swift / asset / plist files in this dir
        files = sorted(p for p in dir_path.iterdir() if p.is_file() or p.suffix == ".xcassets")
        for f in files:
            if f in file_refs:
                children.append(file_refs[f])

        groups[gid] = {
            "name": name or dir_path.name,
            "path": dir_path.name,
            "children": children,
            "sourceTree": "<group>",
        }
        return gid

    app_group_id = build_group_for_dir(APP_DIR, name=PROJECT_NAME)
    widget_group_id = build_group_for_dir(WIDGET_DIR, name=WIDGET_NAME)

    # Products group
    groups[products_group_id] = {
        "name": "Products",
        "path": None,
        "children": [app_product_id, widget_product_id],
        "sourceTree": "<group>",
    }

    # Main (root) group
    groups[main_group_id] = {
        "name": None,
        "path": None,
        "children": [app_group_id, widget_group_id, products_group_id],
        "sourceTree": "<group>",
    }

    # --- Emit -----------------------------------------------------------------

    out: list[str] = []
    a = out.append

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")
    a("")

    # PBXBuildFile
    a("/* Begin PBXBuildFile section */")
    for bid, path in app_build_refs:
        fid = file_refs[path]
        a(f"\t\t{bid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};")
    for bid, path in widget_build_refs:
        fid = file_refs[path]
        a(f"\t\t{bid} /* {path.name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {path.name} */; }};")
    a(f"\t\t{app_assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[app_assets]} /* Assets.xcassets */; }};")
    a(f"\t\t{widget_assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[widget_assets]} /* Assets.xcassets */; }};")
    a(f"\t\t{embed_widget_build_id} /* {WIDGET_NAME}.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {widget_product_id} /* {WIDGET_NAME}.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    a(f"\t\t{pkg_link_build_id} /* RevenueCat in Frameworks */ = {{isa = PBXBuildFile; productRef = {pkg_product_id} /* RevenueCat */; }};")
    a("/* End PBXBuildFile section */")
    a("")

    # PBXContainerItemProxy
    a("/* Begin PBXContainerItemProxy section */")
    a(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
    a("\t\t\tisa = PBXContainerItemProxy;")
    a(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
    a("\t\t\tproxyType = 1;")
    a(f"\t\t\tremoteGlobalIDString = {widget_target_id};")
    a(f"\t\t\tremoteInfo = {WIDGET_NAME};")
    a("\t\t};")
    a("/* End PBXContainerItemProxy section */")
    a("")

    # PBXCopyFilesBuildPhase (embed widget)
    a("/* Begin PBXCopyFilesBuildPhase section */")
    a(f"\t\t{app_embed_phase} /* Embed Foundation Extensions */ = {{")
    a("\t\t\tisa = PBXCopyFilesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tdstPath = \"\";")
    a("\t\t\tdstSubfolderSpec = 13;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{embed_widget_build_id} /* {WIDGET_NAME}.appex in Embed Foundation Extensions */,")
    a("\t\t\t);")
    a("\t\t\tname = \"Embed Foundation Extensions\";")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXCopyFilesBuildPhase section */")
    a("")

    # PBXFileReference
    a("/* Begin PBXFileReference section */")
    for path, fid in sorted(file_refs.items(), key=lambda kv: kv[1]):
        if path.suffix == ".swift":
            a(f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {path.name}; sourceTree = \"<group>\"; }};")
        elif path.suffix == ".xcassets":
            a(f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {path.name}; sourceTree = \"<group>\"; }};")
        elif path.suffix == ".plist":
            a(f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {path.name}; sourceTree = \"<group>\"; }};")
        elif path.suffix == ".entitlements":
            a(f"\t\t{fid} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = {path.name}; sourceTree = \"<group>\"; }};")
    a(f"\t\t{app_product_id} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a(f"\t\t{widget_product_id} /* {WIDGET_NAME}.appex */ = {{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = {WIDGET_NAME}.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
    a("/* End PBXFileReference section */")
    a("")

    # PBXFrameworksBuildPhase
    a("/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{app_frameworks_phase} /* Frameworks */ = {{")
    a("\t\t\tisa = PBXFrameworksBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{pkg_link_build_id} /* RevenueCat in Frameworks */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a(f"\t\t{widget_frameworks_phase} /* Frameworks */ = {{")
    a("\t\t\tisa = PBXFrameworksBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXFrameworksBuildPhase section */")
    a("")

    # PBXGroup
    a("/* Begin PBXGroup section */")
    for gid, info in groups.items():
        a(f"\t\t{gid} = {{")
        a("\t\t\tisa = PBXGroup;")
        a("\t\t\tchildren = (")
        for child in info["children"]:
            # Try to find name annotation
            label = ""
            for path, fid in file_refs.items():
                if fid == child:
                    label = f" /* {path.name} */"
                    break
            if not label:
                for ogid, oinfo in groups.items():
                    if ogid == child:
                        label = f" /* {oinfo['name'] or oinfo['path'] or ''} */"
                        break
            if not label:
                if child == app_product_id:
                    label = f" /* {PROJECT_NAME}.app */"
                elif child == widget_product_id:
                    label = f" /* {WIDGET_NAME}.appex */"
            a(f"\t\t\t\t{child}{label},")
        a("\t\t\t);")
        if info["name"] and info["name"] != info["path"]:
            a(f"\t\t\tname = {info['name']};")
        if info["path"]:
            a(f"\t\t\tpath = {info['path']};")
        a(f"\t\t\tsourceTree = \"{info['sourceTree']}\";")
        a("\t\t};")
    a("/* End PBXGroup section */")
    a("")

    # PBXNativeTarget
    a("/* Begin PBXNativeTarget section */")
    a(f"\t\t{app_target_id} /* {PROJECT_NAME} */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {list_app} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{app_sources_phase} /* Sources */,")
    a(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
    a(f"\t\t\t\t{app_resources_phase} /* Resources */,")
    a(f"\t\t\t\t{app_embed_phase} /* Embed Foundation Extensions */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a(f"\t\t\t\t{dep_id} /* PBXTargetDependency */,")
    a("\t\t\t);")
    a(f"\t\t\tname = {PROJECT_NAME};")
    a("\t\t\tpackageProductDependencies = (")
    a(f"\t\t\t\t{pkg_product_id} /* RevenueCat */,")
    a("\t\t\t);")
    a(f"\t\t\tproductName = {PROJECT_NAME};")
    a(f"\t\t\tproductReference = {app_product_id} /* {PROJECT_NAME}.app */;")
    a("\t\t\tproductType = \"com.apple.product-type.application\";")
    a("\t\t};")
    a(f"\t\t{widget_target_id} /* {WIDGET_NAME} */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {list_widget} /* Build configuration list for PBXNativeTarget \"{WIDGET_NAME}\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{widget_sources_phase} /* Sources */,")
    a(f"\t\t\t\t{widget_frameworks_phase} /* Frameworks */,")
    a(f"\t\t\t\t{widget_resources_phase} /* Resources */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a("\t\t\t);")
    a(f"\t\t\tname = {WIDGET_NAME};")
    a(f"\t\t\tproductName = {WIDGET_NAME};")
    a(f"\t\t\tproductReference = {widget_product_id} /* {WIDGET_NAME}.appex */;")
    a("\t\t\tproductType = \"com.apple.product-type.app-extension\";")
    a("\t\t};")
    a("/* End PBXNativeTarget section */")
    a("")

    # PBXProject
    a("/* Begin PBXProject section */")
    a(f"\t\t{project_id} /* Project object */ = {{")
    a("\t\t\tisa = PBXProject;")
    a("\t\t\tattributes = {")
    a("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    a("\t\t\t\tLastUpgradeCheck = 1500;")
    a("\t\t\t\tTargetAttributes = {")
    a(f"\t\t\t\t\t{app_target_id} = {{")
    a("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    a("\t\t\t\t\t};")
    a(f"\t\t\t\t\t{widget_target_id} = {{")
    a("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    a("\t\t\t\t\t};")
    a("\t\t\t\t};")
    a("\t\t\t};")
    a(f"\t\t\tbuildConfigurationList = {list_proj} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
    a("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a("\t\t\tdevelopmentRegion = en;")
    a("\t\t\thasScannedForEncodings = 0;")
    a("\t\t\tknownRegions = (")
    a("\t\t\t\ten,")
    a("\t\t\t\tBase,")
    a("\t\t\t);")
    a(f"\t\t\tmainGroup = {main_group_id};")
    a("\t\t\tpackageReferences = (")
    a(f"\t\t\t\t{pkg_ref_id} /* XCRemoteSwiftPackageReference \"purchases-ios\" */,")
    a("\t\t\t);")
    a(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    a("\t\t\tprojectDirPath = \"\";")
    a("\t\t\tprojectRoot = \"\";")
    a("\t\t\ttargets = (")
    a(f"\t\t\t\t{app_target_id} /* {PROJECT_NAME} */,")
    a(f"\t\t\t\t{widget_target_id} /* {WIDGET_NAME} */,")
    a("\t\t\t);")
    a("\t\t};")
    a("/* End PBXProject section */")
    a("")

    # PBXResourcesBuildPhase
    a("/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{app_resources_phase} /* Resources */ = {{")
    a("\t\t\tisa = PBXResourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{app_assets_build} /* Assets.xcassets in Resources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a(f"\t\t{widget_resources_phase} /* Resources */ = {{")
    a("\t\t\tisa = PBXResourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{widget_assets_build} /* Assets.xcassets in Resources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXResourcesBuildPhase section */")
    a("")

    # PBXSourcesBuildPhase
    a("/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{app_sources_phase} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for bid, path in app_build_refs:
        a(f"\t\t\t\t{bid} /* {path.name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a(f"\t\t{widget_sources_phase} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for bid, path in widget_build_refs:
        a(f"\t\t\t\t{bid} /* {path.name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXSourcesBuildPhase section */")
    a("")

    # PBXTargetDependency
    a("/* Begin PBXTargetDependency section */")
    a(f"\t\t{dep_id} /* PBXTargetDependency */ = {{")
    a("\t\t\tisa = PBXTargetDependency;")
    a(f"\t\t\ttarget = {widget_target_id} /* {WIDGET_NAME} */;")
    a(f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;")
    a("\t\t};")
    a("/* End PBXTargetDependency section */")
    a("")

    # XCBuildConfiguration
    base_settings_debug = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
        "CLANG_CXX_LANGUAGE_STANDARD": "\"gnu++20\"",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
        "COPY_PHASE_STRIP": "NO",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_TESTABILITY": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": "(\"DEBUG=1\", \"$(inherited)\", )",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR": "YES",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "MTL_FAST_MATH": "YES",
        "ONLY_ACTIVE_ARCH": "YES",
        "SDKROOT": "iphoneos",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "(\"DEBUG\", \"$(inherited)\", )",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-Onone\"",
    }
    base_settings_release = dict(base_settings_debug)
    base_settings_release.update({
        "DEBUG_INFORMATION_FORMAT": "\"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS": "NO",
        "ENABLE_TESTABILITY": "NO",
        "GCC_OPTIMIZATION_LEVEL": "s",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "\"-O\"",
    })
    for k in ("ENABLE_TESTABILITY", "ONLY_ACTIVE_ARCH", "GCC_PREPROCESSOR_DEFINITIONS",
              "SWIFT_ACTIVE_COMPILATION_CONDITIONS"):
        base_settings_release.pop(k, None)
    base_settings_release["VALIDATE_PRODUCT"] = "YES"

    def emit_config(cid: str, name: str, settings: dict) -> None:
        a(f"\t\t{cid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        for k, v in sorted(settings.items()):
            a(f"\t\t\t\t{k} = {v};")
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    app_settings_common = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_ENTITLEMENTS": f"{PROJECT_NAME}/{PROJECT_NAME}.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f"{PROJECT_NAME}/Info.plist",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "LD_RUNPATH_SEARCH_PATHS": "(\"$(inherited)\", \"@executable_path/Frameworks\", )",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "\"1,2\"",
    }

    widget_settings_common = {
        "CODE_SIGN_ENTITLEMENTS": f"{WIDGET_NAME}/{WIDGET_NAME}.entitlements",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f"{WIDGET_NAME}/Info.plist",
        "INFOPLIST_KEY_CFBundleDisplayName": "\"PharmaHealth Widget\"",
        "INFOPLIST_KEY_NSHumanReadableCopyright": "\"\"",
        "LD_RUNPATH_SEARCH_PATHS": "(\"$(inherited)\", \"@executable_path/Frameworks\", \"@executable_path/../../Frameworks\", )",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": WIDGET_BUNDLE_ID,
        "PRODUCT_NAME": "\"$(TARGET_NAME)\"",
        "SKIP_INSTALL": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "\"1,2\"",
    }

    a("/* Begin XCBuildConfiguration section */")
    emit_config(config_proj_debug, "Debug", base_settings_debug)
    emit_config(config_proj_release, "Release", base_settings_release)
    emit_config(config_app_debug, "Debug", app_settings_common)
    emit_config(config_app_release, "Release", app_settings_common)
    emit_config(config_widget_debug, "Debug", widget_settings_common)
    emit_config(config_widget_release, "Release", widget_settings_common)
    a("/* End XCBuildConfiguration section */")
    a("")

    # XCConfigurationList
    a("/* Begin XCConfigurationList section */")
    for lid, name, debug, release in [
        (list_proj, f"PBXProject \"{PROJECT_NAME}\"", config_proj_debug, config_proj_release),
        (list_app, f"PBXNativeTarget \"{PROJECT_NAME}\"", config_app_debug, config_app_release),
        (list_widget, f"PBXNativeTarget \"{WIDGET_NAME}\"", config_widget_debug, config_widget_release),
    ]:
        a(f"\t\t{lid} /* Build configuration list for {name} */ = {{")
        a("\t\t\tisa = XCConfigurationList;")
        a("\t\t\tbuildConfigurations = (")
        a(f"\t\t\t\t{debug} /* Debug */,")
        a(f"\t\t\t\t{release} /* Release */,")
        a("\t\t\t);")
        a("\t\t\tdefaultConfigurationIsVisible = 0;")
        a("\t\t\tdefaultConfigurationName = Release;")
        a("\t\t};")
    a("/* End XCConfigurationList section */")
    a("")

    # XCRemoteSwiftPackageReference
    a("/* Begin XCRemoteSwiftPackageReference section */")
    a(f"\t\t{pkg_ref_id} /* XCRemoteSwiftPackageReference \"purchases-ios\" */ = {{")
    a("\t\t\tisa = XCRemoteSwiftPackageReference;")
    a("\t\t\trepositoryURL = \"https://github.com/RevenueCat/purchases-ios\";")
    a("\t\t\trequirement = {")
    a("\t\t\t\tkind = upToNextMajorVersion;")
    a("\t\t\t\tminimumVersion = 5.0.0;")
    a("\t\t\t};")
    a("\t\t};")
    a("/* End XCRemoteSwiftPackageReference section */")
    a("")

    # XCSwiftPackageProductDependency
    a("/* Begin XCSwiftPackageProductDependency section */")
    a(f"\t\t{pkg_product_id} /* RevenueCat */ = {{")
    a("\t\t\tisa = XCSwiftPackageProductDependency;")
    a(f"\t\t\tpackage = {pkg_ref_id} /* XCRemoteSwiftPackageReference \"purchases-ios\" */;")
    a("\t\t\tproductName = RevenueCat;")
    a("\t\t};")
    a("/* End XCSwiftPackageProductDependency section */")
    a("")

    a("\t};")
    a(f"\trootObject = {project_id} /* Project object */;")
    a("}")

    out_path = ROOT / f"{PROJECT_NAME}.xcodeproj" / "project.pbxproj"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Wrote {out_path} ({len(out)} lines)")


if __name__ == "__main__":
    main()
