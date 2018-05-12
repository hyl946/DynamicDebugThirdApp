#!/bin/sh

#签名framework dylib库
function codesignFrameworkDylib()
{
    for file in `ls "$1"`;
    do
        extension="${file#*.}"
        if [[ -d "$1/$file" ]]; then
            if [[ "$extension" == "framework" ]]; then
                /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$1/$file"
            else
                codesignFrameworkDylib "$1/$file"
            fi
        elif [[ -f "$1/$file" ]]; then

            if [[ "$extension" == "dylib" ]]; then
                /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$1/$file"
            fi
        fi
    done
}
#重签整个APP
function codesign()
{
    codesignFrameworkDylib "$1"
    /usr/bin/codesign --continue -f -s "$EXPANDED_CODE_SIGN_IDENTITY" "$1"
}

function start()
{
    #target
    Target_IPA_Path=$(find "$SRCROOT/$TARGET_NAME/TargetApp" -type f | grep ".ipa$" | head -n 1)
    Target_IPA_Name=$(basename "$Target_IPA_Path" .ipa)
    Target_IPA_Unzip_Temp="$SRCROOT/$TARGET_NAME/TargetApp/Temp"
    #CFBundleDisplayName
    CUSTOM_DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName"  "${SRCROOT}/$TARGET_NAME/Info.plist")
    #CFBundleURLTypes
    CUSTOM_URL_TYPE=$(/usr/libexec/PlistBuddy -x -c "Print CFBundleURLTypes"  "${SRCROOT}/$TARGET_NAME/Info.plist")

    #先删掉temp文件夹
    rm -rf "$Target_IPA_Unzip_Temp"
    #unzip
    unzip -u "$Target_IPA_Path" -d "$Target_IPA_Unzip_Temp"

    #target
    Target_APP_Payload_Path="$Target_IPA_Unzip_Temp/Payload"
    Target_App_Path=$(find "$Target_APP_Payload_Path" -type d | grep ".app$" | head -n 1)
    #self
    Self_APP_Path="$Target_APP_Payload_Path/$TARGET_NAME"".app"

    #重命名为本工程名字
    mv "$Target_App_Path" "$Self_APP_Path"

    #删掉多余target
    rm -rf "$Self_APP_Path/PlugIns" || true
    rm -rf "$Self_APP_Path/Watch" || true

    #删掉旧的签名文件
    rm -r "$Self_APP_Path/_CodeSignature"
    #rm "$Self_APP_Path/embedded.mobileprovision"

    #构建的App路径
    BUILD_APP_PATH="$BUILT_PRODUCTS_DIR/$TARGET_NAME.app"

    rm -rf "$BUILD_APP_PATH" || true
    mkdir -p "$BUILD_APP_PATH" || true
    #复制过去
    cp -rf "$Self_APP_Path/" "$BUILD_APP_PATH/"
    #改info.plist CFBundleDisplayName
    if [[ "$CUSTOM_DISPLAY_NAME" != "" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $CUSTOM_DISPLAY_NAME" "$BUILD_APP_PATH/Info.plist"
        for file in `ls "$BUILD_APP_PATH"`;
            do
            extension="${file#*.}"
                if [[ -d "$BUILD_APP_PATH/$file" ]]; then
                    if [[ "$extension" == "lproj" ]]; then
                        if [[ -f "$BUILD_APP_PATH/$file/InfoPlist.strings" ]];then
                            /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $CUSTOM_DISPLAY_NAME" "$BUILD_APP_PATH/$file/InfoPlist.strings"
                        fi
                    fi
                fi
            done
    else
        echo "没有设置应用名字，采用默认的"
    fi
    #CFBundleIdentifier
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $PRODUCT_BUNDLE_IDENTIFIER" "$BUILD_APP_PATH/Info.plist"

    APP_BINARY=`plutil -convert xml1 -o - $BUILD_APP_PATH/Info.plist | grep -A1 Exec | tail -n1 | cut -f2 -d\> | cut -f1 -d\<`


    #把动态库打进去
    Lib_Target_Dylib_Path="$(dirname "$BUILD_APP_PATH")/""lib""$TARGET_NAME""Dylib.dylib"

    #d：文件夹 f：文件
    echo "dylib path -> $Lib_Target_Dylib_Path"
    if [ ! -f "$Lib_Target_Dylib_Path" ];then
        echo "动态库不存在 跳过"
    else
        echo "开始注入"
        optool install -c load -p "@executable_path/Frameworks/lib""$TARGET_NAME""Dylib.dylib" -t "$BUILD_APP_PATH/$APP_BINARY"
        optool unrestrict -w -t "$BUILD_APP_PATH/$APP_BINARY"
        echo "注入成功"
    fi

    #赋权限
    chmod +x "$BUILD_APP_PATH/$APP_BINARY"

    #使用本证书签名
    echo "-------------------开始签名--------------------"

    codesign "$BUILD_APP_PATH";

    echo "--------------------结束签名--------------------"

}
start
#  sign.sh
#  Demo1
#
#  Created by Loren on 2018/5/10.
#  Copyright © 2018年 Loren. All rights reserved.
