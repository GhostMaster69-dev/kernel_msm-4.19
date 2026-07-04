#! /bin/bash

#
# Copyright (C) 2020 StarLight5234
# Copyright (C) 2021-2026 Unitrix Kernel
#

set -e

# Ask Telegram Channel/Chat ID
if [ -z "$CHANNEL_ID" ]; then
    echo -n "Plox,Give Me Your TG Channel/Group ID:"
    read -r tg_channel_id
    CHANNEL_ID="$tg_channel_id"
fi

# Ask Telegram Bot API Token
if [ -z "$TELEGRAM_TOKEN" ]; then
    echo -n "Plox,Give Me Your TG Bot API Token:"
    read -r tg_token
    TELEGRAM_TOKEN="$tg_token"
fi

# Xiaomi MSM8937 Devices
#targets=("ugg" "santoni" "prada" "land")
# build for ugg only for now
targets=("ugg")

# Build Env
TC_PATH="$HOME/clang-android"
COMPILER_NAME="clang"
LD_NAME="ld.lld"
CROSS_COMPILE_ARM64="aarch64-linux-gnu-"
CROSS_COMPILE_ARM32="arm-linux-gnueabi-"
CMDS="LLVM=1 LLVM_IAS=1"
KBUILD_BUILD_USER="ghostmaster69-dev"
KBUILD_BUILD_HOST="codespace"
TZ="Asia/Kolkata"

# --- Functions ---

# Upload buildlog to group
tg_erlog() {
    ERLOG="$HOME/build/$target-build$BUILD.txt"
    curl -F document=@"$ERLOG"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
	    -F chat_id="$CHANNEL_ID" \
	    -F caption="Build ran into errors after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds, plox check logs"
}

# Upload zip to channel
tg_pushzip() {
    FZIP="$(echo $ZIP_DIR/*.zip)"
    curl -F document=@"$FZIP"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
	    -F chat_id="$CHANNEL_ID" \
	    -F caption="SHA1: $(cat $ZIP_DIR/*.zip.sha1 | cut -c 1-40)"
}

# Send Updates
tg_sendinfo() {
    curl -s "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
	    -d "parse_mode=html" \
	    -d text="$1" \
	    -d chat_id="$CHANNEL_ID" \
	    -d "disable_web_page_preview=true"
}

# Send a sticker
start_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
	    -d sticker="CAACAgUAAxkBAAMPXvdff5azEK_7peNplS4ywWcagh4AAgwBAALQuClVMBjhY-CopowaBA" \
	    -d chat_id="$CHANNEL_ID"
}

# clone toolchain
clone_tc() {
    if ! [ -d $TC_PATH ]; then
        git clone --depth=1 --single-branch -b 20.0.0 https://gitlab.com/GhostMaster69-dev/android-clang $TC_PATH
    fi
}

# clone anykernel3
clone_anykernel3() {
    if ! [ -d $ZIP_DIR ]; then
        git clone --depth=1 -b $AK3_BRANCH https://github.com/GhostMaster69-dev/AnyKernel3 $ZIP_DIR
    fi
}

# Make Kernel
build_kernel() {
    BUILD_START=$(date +"%s")
    BUILD_LOG="$HOME/build/$target-build$BUILD.txt"
    make ARCH=arm64 CC=$COMPILER_NAME LD=$LD_NAME CLANG_TRIPLE=$CROSS_COMPILE_ARM64 CROSS_COMPILE=$CROSS_COMPILE_ARM64 CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 $CMDS O=$OUT_DIR $DEFCONFIG |& tee -a $BUILD_LOG
    make ARCH=arm64 CC=$COMPILER_NAME LD=$LD_NAME CLANG_TRIPLE=$CROSS_COMPILE_ARM64 CROSS_COMPILE=$CROSS_COMPILE_ARM64 CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 $CMDS O=$OUT_DIR -j$(nproc --all) |& tee -a $BUILD_LOG
    BUILD_END=$(date +"%s")
    DIFF=$(($BUILD_END - $BUILD_START))
}

# Make flashable zip
make_flashable() {
    make -C $ZIP_DIR clean &>/dev/null
    cp $KERNEL_IMG $ZIP_DIR
    if [ "$BRANCH" = "test" ]; then
	make LINUX_VERSION="$KERNEL_VERSION" -C $ZIP_DIR test &>/dev/null
    elif [ "$BRANCH" = "beta" ]; then
	make LINUX_VERSION="$KERNEL_VERSION" -C $ZIP_DIR beta &>/dev/null
    else
	make LINUX_VERSION="$KERNEL_VERSION" -C $ZIP_DIR stable &>/dev/null
    fi
}

# Credits: @madeofgreat
BTXT="$HOME/build/buildno.txt" #BTXT is Build number TeXT
if ! [ -a "$BTXT" ]; then
    mkdir $HOME/build
    touch $HOME/build/buildno.txt
    echo $RANDOM > $BTXT
fi
BUILD=$(cat $BTXT)
BUILD=$(($BUILD + 1))
echo $BUILD > $BTXT

# send stickers if build failed
sticker=$(($RANDOM % 5 + 1)) # Randomly pick a sticker number between 1 and 5
if [ "$sticker" = "1" ]; then
    STICKER="CAACAgUAAxkBAAMQXvdgEdkCuvPzzQeXML3J6srMN4gAAvIAA3PMoVfqdoREJO6DahoE"
elif [ "$sticker" = "2" ];then
    STICKER="CAACAgQAAxkBAAMRXveCWisHv4FNMrlAacnmFRWSL0wAAgEBAAJyIUgjtWOZJdyKFpMaBA"
elif [ "$sticker" = "3" ];then
    STICKER="CAACAgUAAxkBAAMSXveCj7P1y5I5AAGaH2wt2tMCXuqZAAL_AAO-xUFXBB9-5f3MjMsaBA"
elif [ "$sticker" = "4" ];then
    STICKER="CAACAgUAAxkBAAMTXveDSSQq2q8fGrIvpmJ4kPx8T1AAAhEBAALKhyBVEsDSQXY-jrwaBA"
elif [ "$sticker" = "5" ];then
    STICKER="CAACAgUAAxkBAAMUXveDrb4guQZSu7mP7ZptE4547PsAAugAA_scAAFXWZ-1a2wWKUcaBA"
fi

# Function to send sticker on errors
error_sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker" \
	    -d sticker="$STICKER" \
	    -d chat_id="$CHANNEL_ID"
}

# Function to upload build logs to Telegram
tg_push_logs() {
    LOG=$HOME/build/$target-build$BUILD.txt
    curl -F document=@"$LOG"  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
	    -F chat_id=$CHANNEL_ID \
	    -F caption="Build Finished after $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds"
}

# The magic begins here.

# Clone toolchain
clone_tc

# Add toolchain to PATH
PATH="$TC_PATH/bin:$PATH"

# Loop through each target
for target in "${targets[@]}"; do
    DEVICE="xiaomi $target"
    DEFCONFIG="vendor/xiaomi/msm8937/unitrix-perf_defconfig vendor/xiaomi/msm8937/"$target".config vendor/feature/kernelsu.config"
    OUT_DIR="$(pwd)/out_$target"
    KERNEL_IMG="$OUT_DIR/arch/arm64/boot/Image.gz-dtb"
    ZIP_DIR="$HOME/AnyKernel3-$target"
    AK3_BRANCH="$target"

    # Cleanup
    make mrproper &>/dev/null
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
    rm -rf "$ZIP_DIR"

    start_sticker

    # Gather some useful info
    COMPILER_VERSION="$($COMPILER_NAME -v 2>&1 | grep ' version ' | sed 's/([^)]*)[[:space:]]//' | sed 's/([^)]*)//' | sed 's/[[:space:]]*$//'), $($LD_NAME -v | sed 's/[[:space:]](.*)//')"
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    COMMIT_HASH="$(git log --pretty=format:'%h' -1)"
    COMMIT_MESSAGE="$(git log --pretty=format:'%s' -1)"
    KERNEL_VERSION="$(make --no-print-directory kernelversion)"

    # Send info to Telegram
    tg_sendinfo "$(echo -e "\n<b>Device</b>: <code>$DEVICE</code>\n<b>Date</b>: <code>$(date +"%d %B %Y")</code>\n<b>Linux Version</b>: <code>$KERNEL_VERSION</code>\n<b>Username</b>: <code>$KBUILD_BUILD_USER</code>\n<b>Hostname</b>: <code>$KBUILD_BUILD_HOST</code>\n<b>Compiler version</b>: <code>$COMPILER_VERSION</code>\n<b>Commit Branch</b>: <code>$BRANCH</code>\n<b>Commit Hash</b>: <code>$COMMIT_HASH</code>\n<b>Commit Message</b>: <i>$COMMIT_MESSAGE</i>\n")"

    # Build kernel
    build_kernel

    # Post-build actions
    clone_anykernel3
    if ! [ -a "$KERNEL_IMG" ]; then
        echo "Error: Kernel image not found for $target."
        error_sticker
        tg_erlog
        exit 1
    else
        tg_push_logs
        make_flashable
        tg_pushzip
    fi
done
