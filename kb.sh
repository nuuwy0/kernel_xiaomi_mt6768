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

export $(grep -v '^#' config.env | xargs)

if [ "$TELEGRAM_TOKEN" = "" ];then
  echo "You have forgot to put the Telegram Bot Token! Aborting..."
  sleep 0.5
  exit 1
fi

if [ "$TELEGRAM_CHAT" = "" ];then
  echo "You have forgot to put the Telegram Chat ID! Aborting..."
  sleep 0.5
  exit 1
fi


KERNEL_DIR="$(readlink -f -- $(pwd))"
CLANG_DIR=$KERNEL_DIR/clang
GCC64_DIR=$KERNEL_DIR/gcc64
GCC32_DIR=$KERNEL_DIR/gcc32

KERNEL_NAME="Atomic-Osuya!"
VERSION="v1"
export KERVER=$(make kernelversion)
LINKER=ld.lld
MODEL="Redmi Note 9"
DEVICE="merlin"
CONFIG="merlin_defconfig"
IMAGE="${KERNEL_DIR}/out/arch/arm64/boot/Image.gz-dtb"
PROCS="$(nproc --all)"
DATE=$(date +"%d-%m-%Y")
ZDATE="$(date "+%d%m%Y")"


export TZ="Asia/Jakarta"
export ARCH="arm64"
export KBUILD_BUILD_USER="nuuwy0"
export KBUILD_BUILD_HOST="0ywuun"


CLEAN="1"


function clone() {
git clone https://github.com/mvaisakh/gcc-arm64 --depth 1 gcc64
git clone https://github.com/mvaisakh/gcc-arm --depth 1 gcc32
git clone https://github.com/NusantaraDevs/DragonTC/ --branch 10.0 --depth 1 clang
export PATH="${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:${PATH}"
if [ ! -f '${CLANG_DIR}/bin/clang' ]; then
    export KBUILD_COMPILER_STRING="$(${CLANG_DIR}/bin/clang --version | head -n 1)"
  else
    export KBUILD_COMPILER_STRING="Unknown"
  fi

git clone --depth 1 --no-single-branch https://github.com/nuuwy0/Anykernel3.git -b merlin AnyKernel3
}

if [ ! -f "${pwd}/Telegram/telegram" ]; then
  git clone --depth=1 https://github.com/fabianonline/telegram.sh Telegram
fi

TELEGRAM="$(pwd)/Telegram/telegram"
tgm() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

tgf() {
  "${TELEGRAM}" -H \
  -f "$1" \
  "$2"
}

function gen_zip() {
    cd AnyKernel3
    zip -r9 $KERNEL_NAME-$VERSION-$DEVICE-$ZDATE.zip * -x .git README.md *placeholder
    ZIP_FINAL="$KERNEL_NAME-$VERSION-$DEVICE-$ZDATE"
   cd ..
}

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
  cd AnyKernel3
  cp ../$cfile .
  tgm "
<b>✅ ${KERNEL_NAME} Kernel</b>
<b>[*] Build Date </b> => <code>$DATE</code>
  "

  tgf "$ZIP_FINAL" "<b>[*] Compiler</b> => <code>${KBUILD_COMPILER_STRING}</code>"
  tgf "$cfile" "<b>[*] Kernel Changelog</b>"
}



build_kernel(){
if [[ $CLEAN  == "1" ]]; then
                echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
		make clean && make mrproper && rm -rf out
fi

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

make O=out ARCH=$ARCH $CONFIG
make -j"$CORES" ARCH=$ARCH O=out \
    REAL_CC="ccache clang" \
    LD="$LINKER" \
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
      echo -e "\n\e[1;32m[✓] Kernel successfully compiled! \e[0m"
      gen_zip
      push
   else
      tgf "error.log" "<i> ❌ Compile Kernel for $DEVICE_CODENAME failed, Check console log to fix it!</i>"
      exit 1
   fi
}

clone
build_kernel
