#!/bin/zsh


((0)) && {
#被注释的内容
:<<!COMMENT!

monkeyparser说明:
https://toutiao.io/posts/0h5tnm/preview

有一个类型的工具叫optool
https://github.com/alexzielenski/optool


!COMMENT!
}


#set -e表示一旦脚本中有命令的返回值为非0，则脚本立即退出，后续命令不再执行;
#set -o pipefail表示在管道连接的命令序列中，只要有任何一个命令返回非0值，则整个管道返回非0值，即使最后一个命令返回0.
export setCmd="set -eo pipefail"
$setCmd

echo "xcode调用bash的时候, 没有执行~/.bashrc, 所以要先执行一下~/.bashrc, 初始化conda环境"
source ~/.zshrc
conda env list  #验证conda环境已经ready
echo "初始化homebrew"
eval "$(/opt/homebrew/bin/brew shellenv)"

echo "================================================================="
echo "当前运行环境: "

echo "默认的shell: $SHELL"
echo "当前运行的shell :"
ps -p $$

echo "当前脚本: $0"
echo "当前脚本参数: $*"
echo "当前所有环境变量: "
set
echo "================================================================="


MONKEYDEV_PATH="/opt/MonkeyDev"
# temp path
TEMP_PATH="${SRCROOT}/${TARGET_NAME}/tmp"

# monkeyparser
MONKEYPARSER="${MONKEYDEV_PATH}/bin/monkeyparser"

# create ipa script
#CREATE_IPA="${MONKEYDEV_PATH}/bin/createIPA.command"

# build app path
BUILD_APP_PATH="${BUILT_PRODUCTS_DIR}/${TARGET_NAME}.app"
echo "当前APP生成路径: $BUILD_APP_PATH"

# default demo app
DEMOTARGET_APP_PATH="${MONKEYDEV_PATH}/Resource/TargetApp.app"

# link framework path
FRAMEWORKS_TO_INJECT_PATH="${MONKEYDEV_PATH}/Frameworks/"

# target app placed
TARGET_APP_PUT_PATH="${SRCROOT}/${TARGET_NAME}/TargetApp"

# Compatiable old version
MONKEYDEV_INSERT_DYLIB=${MONKEYDEV_INSERT_DYLIB:=YES}
MONKEYDEV_TARGET_APP=${MONKEYDEV_TARGET_APP:=Optional}
MONKEYDEV_ADD_SUBSTRATE=${MONKEYDEV_ADD_SUBSTRATE:=YES}
MONKEYDEV_DEFAULT_BUNDLEID=${MONKEYDEV_DEFAULT_BUNDLEID:=NO}

function isRelease()
{
    #true 是 bash 的内建命令，它的返回值（$? 的值）是 0（代表执行成功）。和 true 相对应的命令是 false 命令，它也是 bash 的内建命令，它的返回值是 1（代表执行失败）。
	if [[ "${CONFIGURATION}" = "Release" ]]; then
		true
	else
		false
	fi
}

function panic()
{ # args: exitCode, message...
	local exitCode=$1
	set +e

	shift
    #如果$@不为"", 则输出$@到 标准错误管道
	[[ "$*" == "" ]] || \
		echo "$@" >&2

	exit ${exitCode}
}

function checkApp()
{
	local TARGET_APP_PATH="$1"

	# remove Plugin an Watch
	rm -rf "${TARGET_APP_PATH}/PlugIns" || true
	rm -rf "${TARGET_APP_PATH}/Watch" || true

	/usr/libexec/PlistBuddy -c 'Delete UISupportedDevices' "${TARGET_APP_PATH}/Info.plist" 2>/dev/null

  echo "执行命令/opt/MonkeyDev/bin/monkeyparser  MONKEYDEV_CLASS_DUMP=[${MONKEYDEV_CLASS_DUMP}] MONKEYDEV_RESTORE_SYMBOL=[${MONKEYDEV_RESTORE_SYMBOL}]"
	echo "export MONKEYDEV_CLASS_DUMP=${MONKEYDEV_CLASS_DUMP};MONKEYDEV_RESTORE_SYMBOL=${MONKEYDEV_RESTORE_SYMBOL}; $MONKEYPARSER verify -t ${TARGET_APP_PATH} -o ${SRCROOT}/${TARGET_NAME}"
	echo "单独的class-dump命令: /Volumes/disk1t/Desktop/AI/ios/class-dump-skfly  -a -A -H -o ./class-dump_header/  目标mach-o文件"
	VERIFY_RESULT=`export MONKEYDEV_CLASS_DUMP=${MONKEYDEV_CLASS_DUMP};MONKEYDEV_RESTORE_SYMBOL=${MONKEYDEV_RESTORE_SYMBOL};"$MONKEYPARSER" verify -t "${TARGET_APP_PATH}" -o "${SRCROOT}/${TARGET_NAME}"`
  echo "VERIFY_RESULT= $VERIFY_RESULT"
	if [[ $? -eq 16 ]]; then
	  	panic 1 "${VERIFY_RESULT}"
	else
	  	echo "${VERIFY_RESULT}"
	fi
}

# 打包
function pack()
{
  $setCmd

	TARGET_INFO_PLIST=${SRCROOT}/${TARGET_NAME}/Info.plist
	# environment
	echo "Xcode指定的Info.plist文件路径: $TARGET_INFO_PLIST"
	XCODE_CFBundleExecutable=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "${TARGET_INFO_PLIST}" 2>/dev/null) || true
	echo "Xcode生成的可执行文件名称: $XCODE_CFBundleExecutable" || true

	# create tmp dir
	rm -rf "${TEMP_PATH}" || true       #保证执行完该命令之后, $?始终为0, 主要是避免了 set -e 导致的脚本退出
	mkdir -p "${TEMP_PATH}" || true

	# 在工程目录下创建一个指向 *.app生成目录的软连接LatestBuild
	ln -fhs "${BUILT_PRODUCTS_DIR}" "${PROJECT_DIR}"/LatestBuild    #"${PROJECT_DIR}"/LatestBuild 指向生成目录
	#cp -rf "/opt/MonkeyDev/bin/createIPA.command" "${PROJECT_DIR}"/LatestBuild/

	# deal ipa or app
	TARGET_APP_PATH=$(find "${SRCROOT}/${TARGET_NAME}" -type d | grep "\.app$" | head -n 1) || true     #工程根目录下以.app结尾的第一个文件夹. 包括子目录
  if [[ -n $TARGET_APP_PATH ]]
  then
    echo "从工程目录下发现了目标app: $TARGET_APP_PATH"
  else
    echo "工程目录下没有发现目标app"
  fi

	TARGET_IPA_PATH=$(find "${SRCROOT}/${TARGET_NAME}" -type f | grep "\.ipa$" | head -n 1) || true     #工程根目录下以.ipa结尾的第一个文件.  包括子目录
	if [[ -n $TARGET_IPA_PATH ]]
  then
    echo "从工程目录下发现了目标ipa: $TARGET_IPA_PATH"
  else
    echo "工程目录下没有发现目标ipa"
  fi

  # 工程目录(包括子目录)下以.app结尾的第一个文件夹, 如果存在就复制到targetApp目录下
  if [ -n "${TARGET_APP_PATH}" ]; then
		cp -rf "${TARGET_APP_PATH}" "${TARGET_APP_PUT_PATH}"
  	echo "1"
	fi

	if [[ -z ${TARGET_APP_PATH} ]] && [[ -z ${TARGET_IPA_PATH} ]] && [[ ${MONKEYDEV_TARGET_APP} != "Optional" ]]; then
		echo "工程目录下没有以.app或者.ipa结尾的文件, 使用frida-ios-dump工具从越狱设备上dump MONKEYDEV_TARGET_APP指定的app......."
    echo "iproxy 2222 22端口转发. TODO: 此处应判断手机是否连接成功. "
    killall -9 iproxy || true
    iproxy 2222 22 &
		PYTHONIOENCODING=utf-8 ${MONKEYDEV_PATH}/bin/dump.py ${MONKEYDEV_TARGET_APP} -o "${TARGET_APP_PUT_PATH}/TargetApp.ipa" || panic 1 "dump.py error"
    killall -9 iproxy || true
		if [[ -f  "${TARGET_APP_PUT_PATH}/TargetApp.ipa" ]]; then
		  echo "dump应用 [${MONKEYDEV_TARGET_APP}] 成功. ipa路径: ${TARGET_APP_PUT_PATH}/TargetApp.ipa"
		else
		  echo "frida-ios-dump执行失败! 退出脚本"
		  exit 1
		fi
		TARGET_IPA_PATH=$(find "${TARGET_APP_PUT_PATH}" -type f | grep "\.ipa$" | head -n 1)
	fi

	if [[ ! ${TARGET_APP_PATH} ]] && [[ ${TARGET_IPA_PATH} ]]; then
	  echo "*.app不存在, 但是*.ipa存在, 解压*.ipa, 并复制到./TargetApp/目录下备用"
		unzip -oqq "${TARGET_IPA_PATH}" -d "${TEMP_PATH}"
		cp -rf "${TEMP_PATH}/Payload/"*.app "${TARGET_APP_PUT_PATH}"
	fi

	if [ -f "${BUILD_APP_PATH}/embedded.mobileprovision" ]; then
		mv "${BUILD_APP_PATH}/embedded.mobileprovision" "${BUILD_APP_PATH}"/..
	fi

	TARGET_APP_PATH=$(find "${TARGET_APP_PUT_PATH}" -type d | grep "\.app$" | head -n 1)
	echo "用来替换xcode生成的app的app的路径: $TARGET_APP_PATH"

  #这个里面好像永远不会进去
	if [[ -f "${TARGET_APP_PUT_PATH}"/.current_put_app ]]; then
		if [[ $(cat ${TARGET_APP_PUT_PATH}/.current_put_app) !=  "${TARGET_APP_PATH}" ]]; then
			rm -rf "${BUILD_APP_PATH}" || true
		 	mkdir -p "${BUILD_APP_PATH}" || true
		 	rm -rf "${TARGET_APP_PUT_PATH}"/.current_put_app
			echo "${TARGET_APP_PATH}" >> "${TARGET_APP_PUT_PATH}"/.current_put_app
		fi
	fi

	COPY_APP_PATH=${TARGET_APP_PATH}

	if [[ "${TARGET_APP_PATH}" = "" ]]; then
	  echo "没有成功获取到.app文件, 使用默认的.app文件"
		COPY_APP_PATH=${DEMOTARGET_APP_PATH}
		cp -rf "${COPY_APP_PATH}/" "${BUILD_APP_PATH}/"
		checkApp "${BUILD_APP_PATH}"
	else
		checkApp "${COPY_APP_PATH}"
		cp -rf "${COPY_APP_PATH}/" "${BUILD_APP_PATH}/"
	fi

	if [ -f "${BUILD_APP_PATH}/../embedded.mobileprovision" ]; then
		mv "${BUILD_APP_PATH}/../embedded.mobileprovision" "${BUILD_APP_PATH}"
	fi

	# get target info
	My_CFBundleIdentifier=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier"  "${COPY_APP_PATH}/Info.plist" 2>/dev/null)
	My_CFBundleExecutable=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable"  "${COPY_APP_PATH}/Info.plist" 2>/dev/null)

	if [[ ${XCODE_CFBundleExecutable} != ${My_CFBundleExecutable} ]]; then
	  echo "xcode工程指定的app的可执行文件名 与 要破解的app的可执行文件名不一致. 用要破解的app的Info.plist文件替换xcode工程的Info.plist文件"
	  echo "如果下次修改了工程目录下的Info.plist, 那就会启用工程目录下的Info.plist,没毛病"
		cp -rf "${COPY_APP_PATH}/Info.plist" "${TARGET_INFO_PLIST}"
	fi

	TARGET_DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName" "${TARGET_INFO_PLIST}" 2>/dev/null)

	# copy default framewrok
	TARGET_APP_FRAMEWORKS_PATH="${BUILD_APP_PATH}/Frameworks/"

	if [ ! -d "${TARGET_APP_FRAMEWORKS_PATH}" ]; then
		mkdir -p "${TARGET_APP_FRAMEWORKS_PATH}"
	fi

	if [[ ${MONKEYDEV_INSERT_DYLIB} == "YES" ]];then
    #/Users/skfly/Library/Developer/Xcode/DerivedData/MonkeyAppTest-azqothidlyviyngrlzemuvggqpqz/Build/Products/Debug-iphoneos/libMonkeyAppTestDylib.dylib
    echo "将Xcode生成的libMonkeyAppTestDylib.dylib复制到*.app/Frameworks/"
		cp -rf "${BUILT_PRODUCTS_DIR}/lib""${TARGET_NAME}""Dylib.dylib" "${TARGET_APP_FRAMEWORKS_PATH}"
		echo "将/opt/MonkeyDev/Frameworks目录下的文件复制到*.app/Frameworks/"
		cp -rf "${FRAMEWORKS_TO_INJECT_PATH}" "${TARGET_APP_FRAMEWORKS_PATH}"
		if [[ ${MONKEYDEV_ADD_SUBSTRATE} != "YES" ]];then
		  echo "工程配置不启用tweak, 删除*.app/Frameworks/目录下的libsubstrate.dylib文件"
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}/libsubstrate.dylib"
		fi
		if isRelease; then
		  echo "工程为Release版本, 删除*.app/Frameworks/目录下的RevealServer.framework和libcycript*"
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}"/RevealServer.framework
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}"/libcycript*
		fi
	fi


	if [[ -d "$SRCROOT/${TARGET_NAME}/Resources" ]]; then
	 for file in "$SRCROOT/${TARGET_NAME}/Resources"/*; do
    extension="${file#*.}"
	  filename="${file##*/}"
	  if [[ "$extension" == "storyboard" ]]; then
	  	ibtool --compile "${BUILD_APP_PATH}/$filename"c "$file"
	  else
	  	cp -rf "$file" "${BUILD_APP_PATH}/"
	  fi
	 done
	fi

	# Inject the Dynamic Lib
	APP_BINARY=`plutil -convert xml1 -o - ${BUILD_APP_PATH}/Info.plist | grep -A1 Exec | tail -n1 | cut -f2 -d\> | cut -f1 -d\<`


	if [[ ${MONKEYDEV_INSERT_DYLIB} == "YES" ]];then
	  echo "使用/opt/MonkeyDev/bin/monkeyparser工具将libMonkeyAppTestDylib.dylib文件注入到可执行文件中"
		"$MONKEYPARSER" install -c load -p "@executable_path/Frameworks/lib""${TARGET_NAME}""Dylib.dylib" -t "${BUILD_APP_PATH}/${APP_BINARY}"
		"$MONKEYPARSER" unrestrict -t "${BUILD_APP_PATH}/${APP_BINARY}"
		chmod +x "${BUILD_APP_PATH}/${APP_BINARY}"
	fi

	# Update Info.plist for Target App
	#如果*.app/*.lproj/InfoPlist.strings文件存在, 则依据*.app/Info.plist文件里的CFBundleDisplayName字段修正InfoPlist.strings文件中的CFBundleDisplayName
	if [[ "${TARGET_DISPLAY_NAME}" != "" ]]; then
		#for file in `ls $BUILD_APP_PATH`;
		for file in "$BUILD_APP_PATH"/*;
		do
			extension="${file#*.}"
		  if [[ -d "${BUILD_APP_PATH}/$file" ]] && [[ "${extension}" == "lproj" ]] && [[ -f "${BUILD_APP_PATH}/${file}/InfoPlist.strings" ]];then
		    echo "修改${BUILD_APP_PATH}/${file}/InfoPlist.strings文件的CFBundleDisplayName字段的值为: ${TARGET_DISPLAY_NAME}"
				/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${TARGET_DISPLAY_NAME}" "${BUILD_APP_PATH}/${file}/InfoPlist.strings"
			fi
		done
	fi

	if [[ ${MONKEYDEV_DEFAULT_BUNDLEID} = NO ]];then
	  echo "使用xcode工程默认的PRODUCT_BUNDLE_IDENTIFIER(${PRODUCT_BUNDLE_IDENTIFIER})修正*.app/Info.plist文件的CFBundleIdentifier字段"
		/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${PRODUCT_BUNDLE_IDENTIFIER}" "${TARGET_INFO_PLIST}"
	else
	  echo "使用被破解的app的CFBundleIdentifier字段的值(${My_CFBundleIdentifier})修正*.app/Info.plist文件的CFBundleIdentifier字段"
		/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${My_CFBundleIdentifier}" "${TARGET_INFO_PLIST}"
	fi

  echo "更改目标app图标"
	/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFiles" "${TARGET_INFO_PLIST}"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFiles array" "${TARGET_INFO_PLIST}"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFiles: string ${TARGET_NAME}/icon.png" "${TARGET_INFO_PLIST}"

  echo "将工程目录下的Info.plist复制到生成目录*.app"
	cp -rf "${TARGET_INFO_PLIST}" "${BUILD_APP_PATH}/Info.plist"

	#cocoapods
	echo "尝试执行: ${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	if [[ -f "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh" ]]; then
		source "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	fi

	echo "尝试执行: ${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	if [[ -f "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh" ]]; then
		source "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	fi

	echo "尝试执行: ${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	if [[ -f "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh" ]]; then
		source "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	fi

	echo "尝试执行: ${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	if [[ -f "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh" ]]; then
		source "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	fi


# 在这里打包不行的, 还没有签名
	echo "打包生成ipa文件(未签名)"
	rm -rf ./tmp_ipa_workspace
	mkdir -p ./tmp_ipa_workspace/Payload/
	cp -r "${BUILD_APP_PATH}" ./tmp_ipa_workspace/Payload/
	cd ./tmp_ipa_workspace
	zip -r ./out_unsigned.ipa Payload


	echo "执行完毕!"
}

if [[ "$1" == "codesign" ]]; then
  echo "仅执行签名动作, 主要用于MonkeyAppLibrary工程"
	${MONKEYPARSER} codesign -i "${EXPANDED_CODE_SIGN_IDENTITY}" -t "${BUILD_APP_PATH}"
	if [[ ${MONKEYDEV_INSERT_DYLIB} == "NO" ]];then
		rm -rf "${BUILD_APP_PATH}/Frameworks/lib${TARGET_NAME}Dylib.dylib"
	fi
else
  echo "执行全套动作"
	pack
fi



