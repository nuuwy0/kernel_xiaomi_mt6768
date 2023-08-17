#!/usr/bin/env bash
# shellcheck disable=SC2154

# Script For Building Android arm64 Kernel#
# Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
# Copyright (c) 2023 Hoppless <hoppless@proton.me>
# Rewrites script by: Hoppless <hoppless@proton.me>

set -e
export $(grep -v '^#' config.env | xargs)


cdir() {
	cd "$1" 2>/dev/null || msger -e "The directory $1 doesn't exists !"
}

# Directory info
KERNEL_DIR="$(pwd)"
GCC64_DIR=$KERNEL_DIR/gcc64
GCC32_DIR=$KERNEL_DIR/gcc32
TC_DIR=$KERNEL_DIR/clang-llvm

# Kernel info
ZIPNAME="Atomic-Osuya"
AUTHOR="nuuwy0"
ARCH=arm64
DEFCONFIG="merlin_defconfig"
COMPILER="dtc"
LTO="0"
POLLY="1"
LINKER=ld.lld

# Device info
MODEL="Redmi Note 9"
DEVICE="merlin"

# Misc info
CLEAN="1"
SIGN="1"
if [[ $SIGN == 1 ]]; then
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi
HOST="Github-Action"
export DISTRO=$(source /etc/os-release && echo "${NAME}")
KERVER=$(make kernelversion)
COMMIT_HEAD=$(git log --oneline -1)

# Date info
DATE=$(date +"%d-%m-%Y")
ZDATE="$(date "+%d%m%Y")"

clone() {
	echo " "
	if [[ $COMPILER == "gcc" ]]; then
		echo -e "\n\e[1;93m[*] Cloning Eva GCC \e[0m"
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm gcc32
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 gcc64
	fi

	if [[ $COMPILER == "clang" ]]; then
		echo -e "\n\e[1;93m[*] Cloning Proton clang 13 \e[0m"
		git clone --depth=1 https://github.com/kdrag0n/proton-clang clang-llvm
	fi

	if [[ $COMPILER == "dtc" ]]; then
		echo -e "\e[1;93m[*] Cloning DragonTC & GCC! \e[0m"
		POLLY="0"
		git clone --depth=1 https://github.com/NusantaraDevs/DragonTC clang-llvm
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm gcc32
		git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 gcc64
	fi

	if [[ $COMPILER == "neutron" ]]; then
		echo -e "\e[1;93m[*] Cloning Neutron Clang! \e[0m"
		mkdir clang-llvm && cd clang-llvm
		bash <(curl -s https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman) -S=latest
		cd ..
	fi

	if [[ $LTO == "1" ]]; then
		if [[ $COMPILER == "clang" || $COMPILER == "neutron" ]]; then
			echo "CONFIG_LTO_CLANG=y" >>arch/arm64/configs/hopireika_defconfig
			echo "CONFIG_LTO=y" >>arch/arm64/configs/hopireika_defconfig
		else
			echo "CONFIG_LTO_GCC=y" >>arch/arm64/configs/hopireika_defconfig
		fi
	fi

	if [[ $POLLY == "1" ]]; then
		if [[ $COMPILER == "clang" || $COMPILER == "neutron" ]]; then
			echo "CONFIG_LLVM_POLLY=y" >>arch/arm64/configs/hopireika_defconfig
		fi
	fi

	echo -e "\n\e[1;93m[*] Cloning AnyKernel3 \e[0m"
	git clone --depth 1 --no-single-branch https://github.com/Hopireika/AnyKernel3.git -b merlin
}

##------------------------------------------------------##

exports() {
	KBUILD_BUILD_HOST="$HOST"
	KBUILD_BUILD_USER="$AUTHOR"
	SUBARCH=$ARCH

	if [[ $COMPILER == "clang" || $COMPILER == "neutron" ]]; then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$PATH
	elif [[ $COMPILER == "dtc" ]];then
		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	elif [[ $COMPILER == "gcc" ]]; then
		KBUILD_COMPILER_STRING=$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1)
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH
	fi
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER KBUILD_BUILD_HOST \
		KBUILD_COMPILER_STRING ARCH SUBARCH \
		PATH
}

##---------------------------------------------------------##

git clone --depth=1 https://github.com/Hopireika/telegram.sh Telegram

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

##----------------------------------------------------------##

build_kernel() {
	if [[ $CLEAN == "1" ]]; then
		echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
		make clean && make mrproper && rm -rf out
	fi

	tgm "
<b>ðŸ›  Atomic Kernel Build Triggered</b>
<b>-----------------------------------------</b>
<b>[*] Architecture</b>   => <code>$ARCH</code>
<b>[*] Build Date</b>     => <code>$DATE</code>
<b>[*] Device Name</b>    => <code>${MODEL} [${DEVICE}]</code>
<b>[*] Defconfig</b>      => <code>$DEFCONFIG</code>
<b>[*] Kernel Name</b>    => <code>${ZIPNAME}</code>
<b>[*] Kernel Version</b> => <code>${VERSION}</code>
<b>[*] Linux Version</b>  => <code>$(make kernelversion)</code>
<b>[*] Compiler Name</b>  => <code>${KBUILD_COMPILER_STRING}</code>
<b>------------------------------------------</b>
"

	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")

	if [[ $COMPILER == "clang" || $COMPILER == "neutron" || $COMPILER == "dtc" ]]; then
		MAKE+=(
			CROSS_COMPILE=aarch64-linux-gnu-
			CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
			LLVM=1
			CC=clang
			AR=llvm-ar
			OBJDUMP=llvm-objdump
			STRIP=llvm-strip
			NM=llvm-nm
			OBJCOPY=llvm-objcopy
			LD="$LINKER"
		)
	elif [[ $COMPILER == "gcc" ]]; then
		MAKE+=(
			CROSS_COMPILE_COMPAT=arm-eabi-
			CROSS_COMPILE=aarch64-elf-
			AR=llvm-ar
			NM=llvm-nm
			OBJCOPY=llvm-objcopy
			OBJDUMP=llvm-objdump
			STRIP=llvm-strip
			OBJSIZE=llvm-size
			LD=aarch64-elf-$LINKER
		)
	fi

	echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
	make -kj"$PROCS" O=out \
		V=$VERBOSE \
		"${MAKE[@]}" 2>&1 | tee error.log

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [[ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ]]; then
		echo -e "\n\e[1;32m[âœ“] Kernel successfully compiled! \e[0m"
		gen_zip
		push
	else
		echo -e "\n\e[1;32m[âœ—] Build Failed! \e[0m"
		tgf "error.log" "[X] Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds*"
	fi

}

##--------------------------------------------------------------##

gen_zip() {
	echo -e "\n\e[1;32m[*] Create a flashable zip! \e[0m"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3
	mv "$KERNEL_DIR"/out/arch/arm64/boot/dts/mediatek/mt6768.dtb AnyKernel3
	mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3
	cdir AnyKernel3
	zip -r $ZIPNAME-$VERSION-$DEVICE-"$ZDATE" . -x ".git*" -x "README.md" -x "*.zip"
	ZIP_FINAL="$ZIPNAME-$VERSION-$DEVICE-$ZDATE"

	if [[ $SIGN == 1 ]]; then
		## Sign the zip before sending it to telegram
		echo -e "\n\e[1;32m[*] Sgining a zip! \e[0m"
		tgm "<b>[*] Signing Zip file with AOSP keys!</b>"
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_SIGN="$ZIP_FINAL-signed"
		echo -e "\n\e[1;32m[âœ“] Zip Signed! \e[0m"
	fi

	cd ..
	echo -e "\n\e[1;32m[âœ“] Create flashable kernel completed! \e[0m"
}

push() {
	# Create kernel info
	echo -e "\n\e[1;93m[*] Generate source changelogs! \e[0m"
	cfile="kernel-info-$ZDATE.md"
	log="$(git log --oneline -n 10)"
	flog="$(echo "$log" | sed -E 's/^([a-zA-Z0-9]+) (.*)/* \2/')"

	touch $cfile
	{
		echo -e "## Hopireika Kernel"
		echo -e "* Kernel name: $ZIPNAME-$VERSION"
		echo -e "* Device name: ${MODEL} [$DEVICE]"
		echo -e "* Linux version: $KERVER"
		echo -e "* Build user: $AUTHOR"
		echo -e "* Build host: $KBUILD_BUILD_HOST"
		echo -e "* Compiler name: $KBUILD_COMPILER_STRING"
		echo -e ""
		echo -e "## Changelogs build $ZDATE"
		echo -e "$flog"
	} >>"$cfile"

		cd AnyKernel3
		cp ../$cfile .
		if [[ $SIGN == 1 ]]; then
			rel_file="$ZIP_SIGN.zip"
		else
			rel_file="$ZIP_FINAL.zip"
		fi
		tgm "
		<b>âœ… Hopireika Kernel Update!</b>
		<b>[*] Build date</b> => <code>$DATE</code>
		"
		tgf "$rel_file" "<b>[*] Compiler</b> => <code>${KBUILD_COMPILER_STRING}</code>"
		tgf "$cfile" "<b>[*] Kernel information</b>"
		cd ..

}

clone
exports
build_kernel
##--------------------------------------------------##

