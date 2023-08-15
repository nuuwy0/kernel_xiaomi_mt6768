#!/usr/bin/env bash
#
# Copyright (C) 2022-2023 Neebe3289 <neebexd@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Personal script for kranul compilation !!

# Load variables from config.env
export $(grep -v '^#' config.env | xargs)
sudo apt install bc
# Telegram Bot Token checking
if [ "$TELEGRAM_TOKEN" = "" ];then
  echo "You have forgot to put the Telegram Bot Token! Aborting..."
  sleep 0.5
  exit 1
fi

# Telegram Chat checking
if [ "$TELEGRAM_CHAT" = "" ];then
  echo "You have forgot to put the Telegram Chat ID! Aborting..."
  sleep 0.5
  exit 1
fi

# Path
MainPath="$(readlink -f -- $(pwd))"
MainClangPath="${MainPath}/clang"
MainGccPath="${MainPath}/los"
AnyKernelPath="${MainPath}/anykernel"
CrossCompileFlagTriple="aarch64-linux-gnu-"
CrossCompileFlag64="aarch64-linux-gnu-"
CrossCompileFlag32="arm-linux-gnueabi-"

# Clone toolchain
[[ "$(pwd)" != "${MainPath}" ]] && cd "${MainPath}"
function toolchain() {
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth 1 los
git clone https://github.com/NusantaraDevs/DragonTC/ --branch 10.0 --depth=1 clang
export PATH="${MainClangPath}/bin:${MainGccPath}/bin:${PATH}"

  if [ ! -f '${MainClangPath}-${ClangName}/bin/clang' ]; then
    export KBUILD_COMPILER_STRING="$(${MainClangPath}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi
}
# Enviromental variable
STARTTIME="$(TZ='Asia/Jakarta' date +%H%M)"
export TZ="Asia/Jakarta"
MODEL="Redmi Note 9"
DEVICE="merlin"
export DEFCONFIG="merlin_defconfig"
export ARCH="arm64"
export KBUILD_BUILD_USER="nuuwy0"
export KBUILD_BUILD_HOST="0ywuun"
#export KERNEL_NAME="$(cat "arch/arm64/configs/$DEVICE_DEFCONFIG" | grep "CONFIG_LOCALVERSION=" | sed 's/CONFIG_LOCALVERSION="-*//g' | sed 's/"*//g' )"
export KERNEL_NAME="Atomic!"
export VERSION="v1"
export KERVER=$(make kernelversion)
#export SUBLEVEL="v4.14.$(cat "${MainPath}/Makefile" | grep "SUBLEVEL =" | sed 's/SUBLEVEL = *//g')"
IMAGE="${MainPath}/out/arch/arm64/boot/Image.gz-dtb"
CORES="$(nproc --all)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
DATE=$(date +"%d-%m-%Y")
ZDATE="$(date "+%d%m%Y")"

# Function of telegram
if [ ! -f "${MainPath}/Telegram/telegram" ]; then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi
TELEGRAM="${MainPath}/Telegram/telegram"

# Telegram message sending function
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

# Telegram file sending function
tgf() {
  "${TELEGRAM}" -H \
  -f "$1" \
  "$2"
}

tgannounce() {
  "${TELEGRAM}" -c ${TELEGRAM_CHANNEL} -H \
  -f "$1" \
  "$2"
}

# Function for uploaded kernel file
function push() {

  cfile="kernel-info-$VERSION-$ZDATE.md"
	log="$(git log --oneline -n 40)"
	flog="$(echo "$log" | sed -E 's/^([a-zA-Z0-9]+) (.*)/* \2/')"

	touch $cfile
	{
		echo -e "## Atomic Kernel"
		echo -e "* Kernel name: $KERNEL_NAME-$VERISON"
		echo -e "* Device name: ${MODEL} [$DEVICE]"
		echo -e "* Linux version: $KERVER"
		echo -e "* Build user: $KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"
		echo -e "* Compiler name: $KBUILD_COMPILER_STRING"
		echo -e ""
		echo -e "## Changelogs build $ZDATE"
		echo -e "$flog"
	} >>"$cfile"

  ZIP=$(echo $AnyKernelPath/*.zip)
  tgm "
<b>✅ ${KERNEL_NAME} Kernel</b>
<b>[*] Build Date </b> => <code>$DATE</code>
  "
  tgf "$ZIP" "<b>[*] Compiler</b> => <code>${KBUILD_COMPILER_STRING}</code>"
  tgf "$cfile" "<b>[*] Kernel Changelog</b>"

  sleep 3
    if [ "$CLEANUP" = "yes" ];then
       cleanup
    fi
}



function sendinfo(){
  tgm "
<b> ${KERNEL_NAME} Kernel Build Triggered</b>
<b>-----------------------------------------</b>
<b> Architecture</b>   : <code>$ARCH</code>
<b> Build Date</b>     : <code>$DATE</code>
<b> Device Name</b>    : <code>${MODEL} [${DEVICE}]</code>
<b> Kernel Name</b>    : <code>${KERNEL_NAME}</code>
<b> Linux Version</b>  : <code>$KERVER</code>
<b> Compiler Name</b>  : <code>${KBUILD_COMPILER_STRING}</code>
<b>------------------------------------------</b>
" 
}

# Start Compile
START=$(date +"%s")

compile(){
if [ "$ClangName" = "proton" ]; then
  sed -i 's/CONFIG_LLVM_POLLY=y/# CONFIG_LLVM_POLLY is not set/g' ${MainPath}/arch/$ARCH/configs/xiaomi_defconfig || echo ""
else
  sed -i 's/# CONFIG_LLVM_POLLY is not set/CONFIG_LLVM_POLLY=y/g' ${MainPath}/arch/$ARCH/configs/xiaomi_defconfig || echo ""
fi

make O=out ARCH=$ARCH $DEFCONFIG
make -j"$CORES" ARCH=$ARCH O=out \
    REAL_CC="ccache clang" \
    LD=ld.lld \
    LLVM=1 \
    LLVM_IAS=1 \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE=${CrossCompileFlagTriple} \
    CROSS_COMPILE=${CrossCompileFlag64} \
    CROSS_COMPILE_ARM32=${CrossCompileFlag32} 2>&1 | tee error.log
    
   if [[ -f "$IMAGE" ]]; then
      cd ${MainPath}
      #cp out/.config arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git add arch/${ARCH}/configs/${DEVICE_DEFCONFIG} && git commit -m "defconfig: Regenerate"
      git clone --depth 1 --no-single-branch https://github.com/HeyYoWhatBro/AnyKernel3 -b merlin ${AnyKernelPath}
      cp $IMAGE ${AnyKernelPath}
   else
      tgf "${MainPath}/error.log" "<i> ❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!</i>"
      if [ "$CLEANUP" = "yes" ];then
        cleanup
      fi
      exit 1
   fi
}

# Zipping function
function zipping() {
    cd ${AnyKernelPath} || exit 1
    sed -i "s/kernel.string=.*/kernel.string=$KERNEL_NAME-$VERSION-$DEVICE_CODENAME-$ZDATE by ${KBUILD_BUILD_USER} for ${DEVICE_MODEL} (${DEVICE_CODENAME})/g" anykernel.sh
    zip -r9 $KERNEL_NAME-$VERSION-$DEVICE-$ZDATE.zip * -x .git README.md *placeholder
    cd ..
    mkdir -p builds
    cp ${AnyKernelPath}/*.zip ./builds/
}

# Cleanup function
function cleanup() {
    cd ${MainPath}
    sudo rm -rf ${AnyKernelPath}
    sudo rm -rf out/
    sudo rm -rf error.log
}

toolchain
sendinfo
compile
zipping
push
