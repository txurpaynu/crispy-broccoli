#!/usr/bin/env python3
"""Writes TXAWPAY.xcodeproj (Xcode 16+ format, folder-synchronised groups).

Every Swift file and asset under TXAWPAY/ and TXAWPAYTests/ is picked up by Xcode
automatically, so this only needs re-running if targets or settings change.
"""
import os, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
I = {k: f"TX{n:022X}" for n, k in enumerate("""
project main_group products_group app_group tests_group config_group
app_target test_target app_product test_product
app_sources app_frameworks app_resources test_sources test_frameworks test_resources
proj_cfg_list proj_debug proj_release app_cfg_list app_debug app_release test_cfg_list test_debug test_release
dep proxy info_ref ent_ref noicloud_ref readme_ref
""".split(), start=1)}

def build_settings(d, indent="\t\t\t\t"):
    out = []
    for k in sorted(d):
        v = d[k]
        if isinstance(v, list):
            out.append(f"{indent}{k} = (\n" + "".join(f'{indent}\t"{x}",\n' for x in v) + f"{indent});")
        else:
            s = str(v)
            if not s.replace("_", "").replace(".", "").isalnum():
                s = '"' + s.replace('"', '\\"') + '"'
            out.append(f"{indent}{k} = {s};")
    return "\n".join(out)

common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
    "MTL_FAST_MATH": "YES",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
}
proj_debug = dict(common, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_OPTIMIZATION_LEVEL": "0",
    "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
})
proj_release = dict(common, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES", "MTL_ENABLE_DEBUG_INFO": "NO",
})
app = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": "Config/TXAWPAY.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "DEVELOPMENT_TEAM": "",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "Config/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.txawpay.app",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1",
}
test = {
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "GENERATE_INFOPLIST_FILE": "YES",
    "MARKETING_VERSION": "1.0.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.txawpay.app.tests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "TARGETED_DEVICE_FAMILY": "1",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/TXAWPAY.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/TXAWPAY",
}

def cfg(id_, name, settings):
    return f"""		{I[id_]} /* {name} */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{build_settings(settings)}
			}};
			name = {name};
		}};
"""

def phase(id_, isa, name):
    return f"""		{I[id_]} /* {name} */ = {{
			isa = {isa};
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 77;
	objects = {{

/* Begin PBXContainerItemProxy section */
		{I['proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {I['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {I['app_target']};
			remoteInfo = TXAWPAY;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
		{I['app_product']} /* TXAWPAY.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TXAWPAY.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{I['test_product']} /* TXAWPAYTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TXAWPAYTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
		{I['info_ref']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{I['ent_ref']} /* TXAWPAY.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = TXAWPAY.entitlements; sourceTree = "<group>"; }};
		{I['noicloud_ref']} /* TXAWPAY-NoiCloud.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "TXAWPAY-NoiCloud.entitlements"; sourceTree = "<group>"; }};
		{I['readme_ref']} /* README.md */ = {{isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = README.md; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		{I['app_group']} /* TXAWPAY */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = TXAWPAY;
			sourceTree = "<group>";
		}};
		{I['tests_group']} /* TXAWPAYTests */ = {{
			isa = PBXFileSystemSynchronizedRootGroup;
			path = TXAWPAYTests;
			sourceTree = "<group>";
		}};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
{phase('app_frameworks', 'PBXFrameworksBuildPhase', 'Frameworks')}{phase('test_frameworks', 'PBXFrameworksBuildPhase', 'Frameworks')}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{I['main_group']} = {{
			isa = PBXGroup;
			children = (
				{I['readme_ref']} /* README.md */,
				{I['config_group']} /* Config */,
				{I['app_group']} /* TXAWPAY */,
				{I['tests_group']} /* TXAWPAYTests */,
				{I['products_group']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{I['config_group']} /* Config */ = {{
			isa = PBXGroup;
			children = (
				{I['info_ref']} /* Info.plist */,
				{I['ent_ref']} /* TXAWPAY.entitlements */,
				{I['noicloud_ref']} /* TXAWPAY-NoiCloud.entitlements */,
			);
			path = Config;
			sourceTree = "<group>";
		}};
		{I['products_group']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{I['app_product']} /* TXAWPAY.app */,
				{I['test_product']} /* TXAWPAYTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{I['app_target']} /* TXAWPAY */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {I['app_cfg_list']} /* Build configuration list for PBXNativeTarget "TXAWPAY" */;
			buildPhases = (
				{I['app_sources']} /* Sources */,
				{I['app_frameworks']} /* Frameworks */,
				{I['app_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				{I['app_group']} /* TXAWPAY */,
			);
			name = TXAWPAY;
			packageProductDependencies = (
			);
			productName = TXAWPAY;
			productReference = {I['app_product']} /* TXAWPAY.app */;
			productType = "com.apple.product-type.application";
		}};
		{I['test_target']} /* TXAWPAYTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {I['test_cfg_list']} /* Build configuration list for PBXNativeTarget "TXAWPAYTests" */;
			buildPhases = (
				{I['test_sources']} /* Sources */,
				{I['test_frameworks']} /* Frameworks */,
				{I['test_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{I['dep']} /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				{I['tests_group']} /* TXAWPAYTests */,
			);
			name = TXAWPAYTests;
			packageProductDependencies = (
			);
			productName = TXAWPAYTests;
			productReference = {I['test_product']} /* TXAWPAYTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{I['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
				TargetAttributes = {{
					{I['app_target']} = {{
						CreatedOnToolsVersion = 16.0;
					}};
					{I['test_target']} = {{
						CreatedOnToolsVersion = 16.0;
						TestTargetID = {I['app_target']};
					}};
				}};
			}};
			buildConfigurationList = {I['proj_cfg_list']} /* Build configuration list for PBXProject "TXAWPAY" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {I['main_group']};
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = {I['products_group']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{I['app_target']} /* TXAWPAY */,
				{I['test_target']} /* TXAWPAYTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase('app_resources', 'PBXResourcesBuildPhase', 'Resources')}{phase('test_resources', 'PBXResourcesBuildPhase', 'Resources')}/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase('app_sources', 'PBXSourcesBuildPhase', 'Sources')}{phase('test_sources', 'PBXSourcesBuildPhase', 'Sources')}/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{I['dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {I['app_target']} /* TXAWPAY */;
			targetProxy = {I['proxy']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{cfg('proj_debug', 'Debug', proj_debug)}{cfg('proj_release', 'Release', proj_release)}{cfg('app_debug', 'Debug', app)}{cfg('app_release', 'Release', app)}{cfg('test_debug', 'Debug', test)}{cfg('test_release', 'Release', test)}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{I['proj_cfg_list']} /* Build configuration list for PBXProject "TXAWPAY" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{I['proj_debug']} /* Debug */,
				{I['proj_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{I['app_cfg_list']} /* Build configuration list for PBXNativeTarget "TXAWPAY" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{I['app_debug']} /* Debug */,
				{I['app_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{I['test_cfg_list']} /* Build configuration list for PBXNativeTarget "TXAWPAYTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{I['test_debug']} /* Debug */,
				{I['test_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {I['project']} /* Project object */;
}}
"""

proj = ROOT / "TXAWPAY.xcodeproj"
(proj / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
(proj / "project.pbxproj").write_text(pbx)
(proj / "project.xcworkspace" / "contents.xcworkspacedata").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace\n   version = "1.0">\n   <FileRef\n      location = "self:">\n   </FileRef>\n</Workspace>\n')
schemes = proj / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
ref = lambda t, n, p: f'''<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{I[t]}"
               BuildableName = "{p}"
               BlueprintName = "{n}"
               ReferencedContainer = "container:TXAWPAY.xcodeproj">
            </BuildableReference>'''
(schemes / "TXAWPAY.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            {ref('app_target', 'TXAWPAY', 'TXAWPAY.app')}
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            {ref('test_target', 'TXAWPAYTests', 'TXAWPAYTests.xctest')}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref('app_target', 'TXAWPAY', 'TXAWPAY.app')}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {ref('app_target', 'TXAWPAY', 'TXAWPAY.app')}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
''')
print("wrote", proj)
