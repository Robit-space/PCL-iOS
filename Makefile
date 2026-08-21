# PCL-iOS Makefile
# 参考 Amethyst-iOS (https://github.com/AngelAuraMC/Amethyst-iOS)
# 
# 用法:
#   make all       - 完整构建
#   make jre       - 下载Java JRE for iOS arm64
#   make gen       - 生成Xcode项目
#   make clean     - 清理

SHELL := /bin/bash
.SHELLFLAGS = -ec

# 配置
SOURCEDIR := $(shell pwd)
OUTPUTDIR := $(SOURCEDIR)/artifacts
DEPENDS_DIR := $(SOURCEDIR)/depends
JRE_DIR := $(OUTPUTDIR)/java_runtimes
LIBS_DIR := $(DEPENDS_DIR)/libs
FRAMEWORKS_DIR := $(DEPENDS_DIR)/Frameworks

# 是否构建slimmed版本（不含JRE，用于TrollStore）
SLIMMED ?= 0

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

# Xcode生成
XCODEGEN ?= xcodegen

.PHONY: all jre gen clean check help

all: jre gen

help:
	@echo "PCL-iOS Makefile"
	@echo ""
	@echo "目标:"
	@echo "  make all       - jre + gen"
	@echo "  make jre       - 下载Java JRE for iOS arm64"
	@echo "  make gen       - 生成Xcode项目"
	@echo "  make clean     - 清理构建产物"

check:
	@echo "=== PCL-iOS 构建检查 ==="
	@echo "Java 8:  $(if $(wildcard $(JRE8_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 17: $(if $(wildcard $(JRE17_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 21: $(if $(wildcard $(JRE21_DIR)/release),✓ 已安装,✗ 未安装)"
	@echo "Java 25: $(if $(wildcard $(JRE25_DIR)/release),✓ 已安装,✗ 未安装)"

# ============================================================================
# Java JRE下载 (与Amethyst METHOD_JAVA_UNPACK完全一致)
# 来源: https://github.com/AngelAuraMC/Amethyst-iOS/blob/main/Makefile
# ============================================================================
METHOD_JAVA_UNPACK = \
	cd $(DEPENDS_DIR); \
	if [ ! -f "java-$(1)-openjdk/release" ] && [ ! -f "$$(ls jre$(1)-*.tar.xz 2>/dev/null)" ]; then \
		echo "下载 Java $(1) for iOS arm64..."; \
		curl -sL --fail -o jre$(1)-ios-aarch64.zip "$(2)" || wget -q -O jre$(1)-ios-aarch64.zip "$(2)"; \
		if [ -f jre$(1)-ios-aarch64.zip ]; then \
			unzip -o jre$(1)-ios-aarch64.zip && rm -f jre$(1)-ios-aarch64.zip; \
		fi; \
		mkdir -p java-$(1)-openjdk; \
		tar xvf jre$(1)-*.tar.xz -C java-$(1)-openjdk; \
		rm -f jre$(1)-*.tar.xz; \
	fi

# 目录检查函数 (参考Amethyst METHOD_DIRCHECK)
METHOD_DIRCHECK = \
	if [ ! -d '$(1)' ]; then \
		mkdir -p $(1); \
	else \
		rm -rf $(1)/*; \
	fi

jre:
	@echo "[PCL-iOS] 下载Java JRE for iOS arm64 (来源: assets.angelauramc.dev)..."
	mkdir -p $(DEPENDS_DIR)
	$(call METHOD_JAVA_UNPACK,8,$(JRE8_URL))
	$(call METHOD_JAVA_UNPACK,17,$(JRE17_URL))
	$(call METHOD_JAVA_UNPACK,21,$(JRE21_URL))
	$(call METHOD_JAVA_UNPACK,25,$(JRE25_URL))
	@# 清理不必要的文件 (参考Amethyst - 这些文件会触发ldid签名错误)
	@echo "[PCL-iOS] 清理JRE中不必要的文件..."
	rm -rf $(DEPENDS_DIR)/java-*-openjdk/{ASSEMBLY_EXCEPTION,bin,include,jre,legal,LICENSE,man,THIRD_PARTY_README,lib/{ct.sym,jspawnhelper,libjsig.dylib,src.zip,tools.jar}} 2>/dev/null || true
	@# 关键修复：处理JRE中的dylib文件，移除fat binary中的非arm64架构，避免ldid "end <= size"错误
	@echo "[PCL-iOS] 处理JRE中的dylib文件（移除fat binary中的非arm64架构）..."
	@find $(DEPENDS_DIR)/java-*-openjdk -name "*.dylib" -type f 2>/dev/null | while read dylib; do \
		if file "$$dylib" 2>/dev/null | grep -q "Mach-O"; then \
			archs=$$(lipo -info "$$dylib" 2>/dev/null | grep -o "arm64\|x86_64\|i386\|armv7" | tr '\n' ' '); \
			if echo "$$archs" | grep -q " "; then \
				echo "  处理fat binary: $$(basename $$dylib) [$$archs]"; \
				lipo -extract arm64 "$$dylib" -output "$$dylib.tmp" 2>/dev/null && mv "$$dylib.tmp" "$$dylib"; \
			fi; \
		fi; \
	done
	@# 删除所有非Mach-O文件（避免ldid误解析）
	@echo "[PCL-iOS] 删除JRE中非Mach-O文件..."
	@find $(DEPENDS_DIR)/java-*-openjdk -type f \( -name "*.sh" -o -name "*.txt" -o -name "*.properties" -o -name "*.policy" -o -name "*.security" -o -name "*.cfg" -o -name "*.dat" \) -delete 2>/dev/null || true
	@# 复制JRE到输出目录
	$(call METHOD_DIRCHECK,$(JRE_DIR))
	cp -R $(JRE8_DIR) $(JRE_DIR) 2>/dev/null || true
	cp -R $(JRE17_DIR) $(JRE_DIR) 2>/dev/null || true
	cp -R $(JRE21_DIR) $(JRE_DIR) 2>/dev/null || true
	cp -R $(JRE25_DIR) $(JRE_DIR) 2>/dev/null || true
	@echo "[PCL-iOS] Java JRE下载完成"

# ============================================================================
# Xcode项目生成
# ============================================================================
gen:
	@echo "[PCL-iOS] 生成Xcode项目..."
	$(XCODEGEN) generate
	@echo "[PCL-iOS] 项目生成完成"

# ============================================================================
# 清理
# ============================================================================
clean:
	@echo "[PCL-iOS] 清理..."
	rm -rf $(OUTPUTDIR)
	rm -f PCL-iOS.xcodeproj
	@echo "[PCL-iOS] 清理完成"

# ===== 完整清理 (包括JRE) =====
distclean: clean
	@echo "[PCL-iOS] 完整清理..."
	rm -rf $(DEPENDS_DIR)/java-*-openjdk
	rm -rf $(DEPENDS_DIR)/jre*.zip
	rm -rf $(DEPENDS_DIR)/jre*.tar.xz
	@echo "[PCL-iOS] 完整清理完成"
