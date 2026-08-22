# PCL-iOS Makefile
# 参考 Amethyst-iOS-MyRemastered (https://github.com/herbrine8403/Amethyst-iOS-MyRemastered)
# 
# 用法:
#   make all       - 完整构建
#   make jre       - 下载Java JRE for iOS arm64
#   make gen       - 生成Xcode项目
#   make payload   - 打包.app（含JRE复制+ldid签名）
#   make package   - 构建IPA/TIPA
#   make dsym      - 生成dSYM调试符号
#   make clean     - 清理

SHELL := /bin/bash
.SHELLFLAGS = -ec

# Prerequisite variables
SOURCEDIR := $(shell pwd)
OUTPUTDIR := $(SOURCEDIR)/artifacts
DEPENDS_DIR := $(SOURCEDIR)/depends
JRE_DIR := $(OUTPUTDIR)/java_runtimes
LIBS_DIR := $(DEPENDS_DIR)/libs
FRAMEWORKS_DIR := $(DEPENDS_DIR)/Frameworks

# 检测是否在GitHub Actions runner上运行
RUNNER ?= 0

# Release vs Debug
RELEASE ?= 0

# TrollStore JIT 变体（ldid entitlements）
TROLLSTORE_JIT_ENT ?= 0

# 是否构建slimmed版本（不含JRE，用于TrollStore）
SLIMMED ?= 0

# 代码签名标识（-1表示跳过正式签名）
SIGNING_TEAMID ?= -1

ifeq (1,$(RELEASE))
BUILD_CONFIG := Release
else
BUILD_CONFIG := Debug
endif

# Java JRE 下载链接 (与Amethyst-iOS完全相同)
# 来源: https://github.com/AngelAuraMC/Amethyst-iOS/blob/main/Makefile
JRE8_URL  := https://assets.angelauramc.dev/openjdk/ios-arm64/jre8-ios-aarch64.zip
JRE17_URL := https://assets.angelauramc.dev/openjdk/ios-arm64/jre17-ios-aarch64.zip
JRE21_URL := https://assets.angelauramc.dev/openjdk/ios-arm64/jre21-ios-aarch64.zip
JRE25_URL := https://assets.angelauramc.dev/openjdk/ios-arm64/jre25-ios-aarch64.zip

# Java版本和目录
JRE8_DIR  := $(DEPENDS_DIR)/java-8-openjdk
JRE17_DIR := $(DEPENDS_DIR)/java-17-openjdk
JRE21_DIR := $(DEPENDS_DIR)/java-21-openjdk
JRE25_DIR := $(DEPENDS_DIR)/java-25-openjdk

# App 配置
APP_NAME := PCL-iOS
APP_BUNDLE_ID := com.pcl-ios.pcl
APP_VERSION := 1.0

# Xcode生成
XCODEGEN ?= xcodegen

# 检测CPU核心数
JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 2)

.PHONY: all jre gen clean check help verify-jre payload package dsym build sign entitlements

all: jre gen

help:
	@echo "PCL-iOS Makefile"
	@echo ""
	@echo "目标:"
	@echo "  make all       - jre + gen"
	@echo "  make jre       - 下载Java JRE for iOS arm64"
	@echo "  make gen       - 生成Xcode项目"
	@echo "  make payload   - 打包.app (复制JRE+ldid签名)"
	@echo "  make package   - 打包IPA/TIPA"
	@echo "  make dsym      - 生成dSYM调试符号"
	@echo "  make clean     - 清理构建产物"
	@echo ""
	@echo "选项:"
	@echo "  RELEASE=1              发布模式(默认Debug)"
	@echo "  TROLLSTORE_JIT_ENT=1   TrollStore变体(JIT entitlements)"
	@echo "  RUNNER=1               CI环境(使用缓存JRE)"

check:
	@echo "=== PCL-iOS 构建检查 ==="
	@echo "Java 8:  $(if $(wildcard $(JRE8_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 17: $(if $(wildcard $(JRE17_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 21: $(if $(wildcard $(JRE21_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 25: $(if $(wildcard $(JRE25_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo ""
	@echo "平台: iOS"
	@echo "配置: $(BUILD_CONFIG)"
	@echo "JOBS: $(JOBS)"
	@echo "ldid: $(if $(shell which ldid 2>/dev/null),✓ 可用,✗ 未安装)"

verify-jre:
	@echo "=== 验证JRE安装状态 ==="
	@for jdir in $(JRE8_DIR) $(JRE17_DIR) $(JRE21_DIR) $(JRE25_DIR); do \
		if [ -f "$$jdir/release" ]; then \
			echo "✓ $$jdir 已安装"; \
		else \
			echo "✗ $$jdir 缺失!"; \
		fi; \
	done

# ============================================================================
# 目录检查函数 (参考Amethyst METHOD_DIRCHECK)
# ============================================================================
METHOD_DIRCHECK = \
	if [ ! -d '$(1)' ]; then \
		mkdir -p $(1); \
	else \
		rm -rf $(1)/*; \
	fi

# ============================================================================
# Mach-O 文件处理方法 (参考Amethyst METHOD_MACHO)
# ============================================================================
METHOD_MACHO = \
	for file in $$(find $(1) -type f); do \
		if [[ "$$(file -b $$file 2>/dev/null)" == *"Mach-O"* ]]; then \
			$(2); \
		fi; \
	done

# ============================================================================
# 平台重打标方法 (参考Amethyst METHOD_CHANGE_PLAT)
# ============================================================================
METHOD_CHANGE_PLAT = \
	ldid -S -M $(1)

# ============================================================================
# IPA 打包方法 (参考Amethyst METHOD_PACKAGE)
# ============================================================================
METHOD_PACKAGE = \
	if [ '$(TROLLSTORE_JIT_ENT)' == '1' ]; then \
		IPA_SUFFIX="-trollstore.tipa"; \
	else \
		IPA_SUFFIX=".ipa"; \
	fi; \
	rm -f $(OUTPUTDIR)/$(APP_BUNDLE_ID)-$(APP_VERSION)-ios$$IPA_SUFFIX; \
	cd $(OUTPUTDIR)/Payload; \
	zip --symlinks -r $(OUTPUTDIR)/$(APP_BUNDLE_ID)-$(APP_VERSION)-ios$$IPA_SUFFIX .

# ============================================================================
# Java JRE下载 (与Amethyst METHOD_JAVA_UNPACK对齐)
# 来源: https://github.com/herbrine8403/Amethyst-iOS-MyRemastered
# ============================================================================
METHOD_JAVA_UNPACK = \
	cd $(DEPENDS_DIR); \
	if [ ! -f "java-$(1)-openjdk/release" ]; then \
		if [ ! -f "$$(ls jre$(1)-*.tar.xz 2>/dev/null)" ]; then \
			echo "下载 Java $(1) for iOS arm64..."; \
			wget '$(2)' -q --show-progress -O jre$(1)-ios-aarch64.zip 2>/dev/null || \
				curl -sL --fail -o jre$(1)-ios-aarch64.zip "$(2)"; \
			if [ -f jre$(1)-ios-aarch64.zip ]; then \
				unzip -o jre$(1)-ios-aarch64.zip && rm -f jre$(1)-ios-aarch64.zip; \
			fi; \
		fi; \
		if [ -f "$$(ls jre$(1)-*.tar.xz 2>/dev/null)" ]; then \
			mkdir -p java-$(1)-openjdk; \
			tar xvf jre$(1)-*.tar.xz -C java-$(1)-openjdk; \
		fi; \
	fi

# ============================================================================
# JRE下载目标
# ============================================================================
jre:
	@echo "[PCL-iOS] jre - start"
	mkdir -p $(DEPENDS_DIR)
	cd $(DEPENDS_DIR); \
	$(call METHOD_JAVA_UNPACK,8,$(JRE8_URL)); \
	$(call METHOD_JAVA_UNPACK,17,$(JRE17_URL)); \
	$(call METHOD_JAVA_UNPACK,21,$(JRE21_URL)); \
	$(call METHOD_JAVA_UNPACK,25,$(JRE25_URL)); \
	if [ -f "$(ls jre*.tar.xz 2>/dev/null)" ]; then rm -f $(DEPENDS_DIR)/jre*.tar.xz; fi; \
	cd $(SOURCEDIR); \
	rm -rf $(DEPENDS_DIR)/java-{8,17,21,25}-openjdk/{ASSEMBLY_EXCEPTION,bin,include,jre,legal,LICENSE,man,THIRD_PARTY_README,lib/{ct.sym,jspawnhelper,libjsig.dylib,src.zip,tools.jar}}; \
	$(call METHOD_DIRCHECK,$(JRE_DIR)); \
	cp -R $(JRE8_DIR) $(JRE_DIR); \
	cp -R $(JRE17_DIR) $(JRE_DIR); \
	cp -R $(JRE21_DIR) $(JRE_DIR); \
	cp -R $(JRE25_DIR) $(JRE_DIR)
	@echo "[PCL-iOS] jre - end"

# ============================================================================
# Xcode项目生成
# ============================================================================
gen:
	@echo "[PCL-iOS] 生成Xcode项目..."
	$(XCODEGEN) generate
	@echo "[PCL-iOS] 项目生成完成"

# ============================================================================
# 构建
# ============================================================================
build:
	@echo "[PCL-iOS] 构建 $(BUILD_CONFIG)..."
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-configuration $(BUILD_CONFIG) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath build \
		-jobs $(JOBS) \
		CODE_SIGNING_ALLOWED=NO \
		build
	@echo "[PCL-iOS] 构建完成"

# ============================================================================
# Entitlements 文件生成
# ============================================================================
entitlements:
	@echo "[PCL-iOS] 生成 entitlements..."
	@if [ '$(TROLLSTORE_JIT_ENT)' == '1' ]; then \
		cat > $(OUTPUTDIR)/entitlements.sideload.xml << 'XMLEOF'\
<?xml version="1.0" encoding="UTF-8"?>\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">\
<plist version="1.0">\
<dict>\
	<key>platform-application</key>\
	<true/>\
	<key>get-task-allow</key>\
	<true/>\
	<key>com.apple.p.security.jit-allow</key>\
	<true/>\
	<key>com.apple.private.cs.debugger</key>\
	<true/>\
	<key>com.apple.private.skip-library-validation</key>\
	<true/>\
	<key>com.apple.private.security.container-required</key>\
	<true/>\
	<key>com.apple.private.security.no-container</key>\
	<true/>\
	<key>com.apple.private.security.no-sandbox</key>\
	<true/>\
</dict>\
</plist>\
XMLEOF\
	else \
		cat > $(OUTPUTDIR)/entitlements.sideload.xml << 'XMLEOF'\
<?xml version="1.0" encoding="UTF-8"?>\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">\
<plist version="1.0">\
<dict>\
	<key>platform-application</key>\
	<true/>\
	<key>com.apple.private.security.container-required</key>\
	<true/>\
</dict>\
</plist>\
XMLEOF\
	fi
	@echo "[PCL-iOS] entitlements 生成完成"

# ============================================================================
# 签名
# ============================================================================
sign:
	@echo "[PCL-iOS] ldid 签名..."
	ldid -S$(OUTPUTDIR)/entitlements.sideload.xml $(OUTPUTDIR)/Payload/$(APP_NAME).app/$(APP_NAME)
	ldid -S -M $(OUTPUTDIR)/Payload/$(APP_NAME).app/$(APP_NAME)
	$(call METHOD_MACHO,$(OUTPUTDIR)/Payload/$(APP_NAME).app/Frameworks,ldid -S -M $$file)
	@echo "[PCL-iOS] 签名完成"

# ============================================================================
# dSYM 生成
# ============================================================================
dsym: payload
	@echo "[PCL-iOS] dsym - start"
	dsymutil --arch arm64 $(OUTPUTDIR)/Payload/$(APP_NAME).app/$(APP_NAME) -o $(OUTPUTDIR)/$(APP_NAME).dSYM
	@echo "[PCL-iOS] dsym - end"

# ============================================================================
# Payload 打包
# ============================================================================
payload: build entitlements
	@echo "[PCL-iOS] payload - start"
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/Payload)
	@# 复制 .app
	cp -R build/Build/Products/$(BUILD_CONFIG)-iphoneos/$(APP_NAME).app $(OUTPUTDIR)/Payload/
	@# 复制 JRE 到 .app
	cp -R $(OUTPUTDIR)/java_runtimes $(OUTPUTDIR)/Payload/$(APP_NAME).app/
	@# ldid 签名
	$(MAKE) sign
	@# 设置权限
	chmod -R 755 $(OUTPUTDIR)/Payload
	@echo "[PCL-iOS] payload - end"

# ============================================================================
# IPA/TIPA 打包
# ============================================================================
package: payload
	@echo "[PCL-iOS] package - start"
	$(call METHOD_PACKAGE)
	@ls -lh $(OUTPUTDIR)/*.ipa $(OUTPUTDIR)/*.tipa 2>/dev/null || true
	@echo "[PCL-iOS] package - end"

# ============================================================================
# 完整构建 (payload + package + dsym)
# ============================================================================
full: payload package dsym

# ============================================================================
# 清理
# ============================================================================
clean:
	@echo "[PCL-iOS] 清理..."
	rm -rf $(OUTPUTDIR)
	rm -f $(APP_NAME).xcodeproj
	rm -rf build
	@echo "[PCL-iOS] 清理完成"

# ===== 完整清理 (包括JRE) =====
distclean: clean
	@echo "[PCL-iOS] 完整清理..."
	rm -rf $(DEPENDS_DIR)/java-*-openjdk
	rm -rf $(DEPENDS_DIR)/jre*.zip
	rm -rf $(DEPENDS_DIR)/jre*.tar.xz
	@echo "[PCL-iOS] 完整清理完成"
