APP_ID := com.lix.piraeusbanter.mobile
FLUTTER ?= flutter
ADB ?= adb
DEVICE ?=
-include ../.env.local
-include ../.env.us.local
API_TOKEN_DEFINE := $(if $(PIRAEUS_API_TOKEN),--dart-define=PIRAEUS_API_TOKEN=$(PIRAEUS_API_TOKEN),)
SELECTED_DEVICE := $(shell $(ADB) devices | awk '\
	NR > 1 && $$2 == "device" { \
		if ($$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$$/ && ip == "") { ip = $$1 } \
		else if (first == "") { first = $$1 } \
	} \
	END { \
		if (ip != "") print ip; else if (first != "") print first; \
	}')
RESOLVED_DEVICE := $(if $(DEVICE),$(DEVICE),$(SELECTED_DEVICE))
ADB_TARGET := $(if $(RESOLVED_DEVICE),-s $(RESOLVED_DEVICE),)
DEBUG_APK := build/app/outputs/flutter-apk/app-debug.apk
RELEASE_APK := build/app/outputs/flutter-apk/app-release.apk

.PHONY: help deps devices doctor apk release-apk install install-release install-apk install-release-apk run restart logs uninstall clean

help:
	@printf '%s\n' \
		'make deps                - 拉取 Flutter 依赖' \
		'make devices             - 查看已连接设备' \
		'make doctor              - 查看 Flutter 环境' \
		'make apk                 - 构建 debug APK' \
		'make release-apk         - 构建 release APK' \
		'make install             - 构建并安装 debug 包' \
		'make install-release     - 构建并安装 release 包' \
		'make install-apk         - 安装本地 debug APK' \
		'make install-release-apk - 安装本地 release APK' \
		'make run                 - 直接运行调试' \
		'make restart             - 重启手机上的应用' \
		'make logs                - 查看应用日志' \
		'make uninstall           - 卸载应用' \
		'make clean               - 清理构建产物' \
		'' \
		'可选参数: DEVICE=<serial>'

deps:
	$(FLUTTER) pub get

devices:
	$(ADB) devices -l

doctor:
	$(FLUTTER) doctor -v

apk:
	@$(FLUTTER) build apk --debug $(API_TOKEN_DEFINE)

release-apk:
	@test -n "$(PIRAEUS_API_TOKEN)" || (echo "本地构建配置缺少 PIRAEUS_API_TOKEN" && exit 1)
	@$(FLUTTER) build apk --release $(API_TOKEN_DEFINE)

install: apk
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可安装的 Android 设备" && exit 1)
	$(ADB) $(ADB_TARGET) install -r $(DEBUG_APK)

install-release: release-apk
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可安装的 Android 设备" && exit 1)
	$(ADB) $(ADB_TARGET) install -r $(RELEASE_APK)

install-apk:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可安装的 Android 设备" && exit 1)
	@test -f "$(DEBUG_APK)" || (echo "未找到本地 debug APK: $(DEBUG_APK)" && exit 1)
	$(ADB) $(ADB_TARGET) install -r $(DEBUG_APK)

install-release-apk:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可安装的 Android 设备" && exit 1)
	@test -f "$(RELEASE_APK)" || (echo "未找到本地 release APK: $(RELEASE_APK)" && exit 1)
	$(ADB) $(ADB_TARGET) install -r $(RELEASE_APK)

run:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可运行的 Android 设备" && exit 1)
	@$(FLUTTER) run -d $(RESOLVED_DEVICE) $(API_TOKEN_DEFINE)

restart:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可重启的 Android 设备" && exit 1)
	$(ADB) $(ADB_TARGET) shell am force-stop $(APP_ID)
	$(ADB) $(ADB_TARGET) shell monkey -p $(APP_ID) -c android.intent.category.LAUNCHER 1

logs:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可查看日志的 Android 设备" && exit 1)
	$(ADB) $(ADB_TARGET) logcat --pid="$$( $(ADB) $(ADB_TARGET) shell pidof -s $(APP_ID) )"

uninstall:
	@test -n "$(RESOLVED_DEVICE)" || (echo "未找到可卸载的 Android 设备" && exit 1)
	$(ADB) $(ADB_TARGET) uninstall $(APP_ID)

clean:
	$(FLUTTER) clean
