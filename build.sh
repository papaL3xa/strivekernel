#!/bin/bash

# =============================================================================
# KERNEL BUILD SCRIPT FOR SAMSUNG EXYNOS 9820 DEVICES
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# KONFIGURASI AWAL
# =============================================================================

RDIR=$(pwd)
LOCATION=$(pwd)

# Default values
DEFAULT_MODEL="N975F"
DEFAULT_KERNEL_VERSION="unknown"

# =============================================================================
# FUNGSI-FUNGSI
# =============================================================================

# Fungsi untuk update submodules
submodule() {
    separator
    quotes "Fetch all Submodules Update"

    git submodule init && git submodule update --remote
    git submodule update -f -q --init --recursive > /dev/null
    check "Submodules"
}

# Fungsi untuk menampilkan usage
usage() {
    cat << EOF
Usage: $(basename "$0") [options]
Options:
    -m, --model [value]    Specify the Model Code of the Phone (default: $DEFAULT_MODEL)
    -v, --ver [value]      Specify kernel version (default: $DEFAULT_KERNEL_VERSION)
    -h, --help             Show this help message

Supported Models:
    Galaxy S10 Series: G970F, G970N, G973F, G973N
    Galaxy S10+ Series: G975F, G975N  
    Galaxy S10 5G: G977B, G977N
    Galaxy Note10 Series: N970F, N971N
    Galaxy Note10+ Series: N975F, N976B, N976N

Examples:
    $(basename "$0") -m N975F -v "v2.1"
    $(basename "$0") --model G973F --ver "stable-release"
    BUILD_KERNEL_VERSION="custom-ver" $(basename "$0") -m G977B
EOF
}

# Fungsi untuk logging
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

log_step() {
    echo "🔸 $1"
}

# Fungsi untuk parsing argumen command line
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model|-m)
                if [ -n "$2" ]; then
                    MODEL="$2"
                    shift 2
                else
                    log_error "Model value is required for $1"
                    exit 1
                fi
                ;;
            --ver|-v)
                if [ -n "$2" ]; then
                    BUILD_KERNEL_VERSION="$2"
                    shift 2
                else
                    log_error "Version value is required for $1"
                    exit 1
                fi
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Fungsi untuk validasi model
validate_model() {
    local valid_models=("G970F" "G970N" "G973F" "G973N" "G975F" "G975N" "G977B" "G977N" "N970F" "N971N" "N975F" "N976B" "N976N")
    
    for valid_model in "${valid_models[@]}"; do
        if [ "$MODEL" == "$valid_model" ]; then
            return 0
        fi
    done
    
    log_error "Unsupported model: $MODEL"
    echo "Supported models: ${valid_models[*]}"
    exit 1
}

# Fungsi untuk setup device berdasarkan model
setup_device() {
    case "$MODEL" in
        G970F) DEVICE="beyond0lte" ;;
        G970N) DEVICE="beyond0lteks" ;;
        G973F) DEVICE="beyond1lte" ;;        
        G973N) DEVICE="beyond1lteks" ;;
        G975F) DEVICE="beyond2lte" ;;        
        G975N) DEVICE="beyond2lteks" ;;
        G977B) DEVICE="beyondx" ;;         
        G977N) DEVICE="beyondxks" ;;
        N970F) DEVICE="d1" ;;        
        N971N) DEVICE="d1xks" ;;
        N975F) DEVICE="d2s" ;;
        N976B) DEVICE="d2x" ;;                     
        N976N) DEVICE="d2xks" ;;
        *)
            log_error "Device mapping not found for model: $MODEL"
            exit 1
            ;;
    esac
    
    log_success "Device configured: $DEVICE for model $MODEL"
}

# Fungsi untuk setup tzdev
setup_tzdev() {
    log_step "Setting up tzdev..."
    
    if [ ! -d "${LOCATION}/drivers/misc" ]; then
        log_error "drivers/misc directory not found"
        exit 1
    fi
    
    rm -rf "${LOCATION}/drivers/misc/tzdev"

    case "${MODEL}" in
        G970F|G970N|G973F|G973N|G975F|G975N|G977B|G977N|N971N|N976N)
            if [ -d "${LOCATION}/early_setting/tzdev_case/tzdev_A" ]; then
                cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_A" "${LOCATION}/drivers/misc/tzdev"
            else
                log_error "tzdev_A directory not found"
                exit 1
            fi
            ;;
        N970F|N975F|N976B)
            if [ -d "${LOCATION}/early_setting/tzdev_case/tzdev_B" ]; then
                cp -ar "${LOCATION}/early_setting/tzdev_case/tzdev_B" "${LOCATION}/drivers/misc/tzdev"
            else
                log_error "tzdev_B directory not found"
                exit 1
            fi
            ;;
        *)
            log_error "TZDev configuration not implemented for model: $MODEL"
            exit 1
            ;;
    esac
    log_success "TZDev setup completed"
}

# Fungsi untuk setup toolchain
setup_toolchain() {
    log_step "Setting up toolchain..."
    TOOLCHAIN_URL="https://github.com/GoRhanHee/exynos9820_toolchain/releases/download/toolchain/toolchain.tar.xz"
    TOOLCHAIN_FILE=$(basename "$TOOLCHAIN_URL")

    if [ ! -f "$TOOLCHAIN_FILE" ]; then
        log_info "Downloading toolchain..."
        if ! wget -q --show-progress -O "$TOOLCHAIN_FILE" "$TOOLCHAIN_URL"; then
            log_error "Failed to download toolchain from $TOOLCHAIN_URL"
            exit 1
        fi
    fi

    if [ -f "$TOOLCHAIN_FILE" ]; then
        if ! tar -xf "$TOOLCHAIN_FILE" && rm "$TOOLCHAIN_FILE"; then
            log_error "Failed to extract toolchain"
            exit 1
        fi
        log_success "Toolchain setup completed"
    else
        log_error "Toolchain file not found: $TOOLCHAIN_FILE"
        exit 1
    fi
}

# Fungsi untuk setup environment build
setup_build_env() {
    log_step "Setting up build environment..."
    
    # Compile Setting
    export ARCH=arm64
    export PLATFORM_VERSION=12
    export ANDROID_MAJOR_VERSION=s
    
    # Setup directories
    OUT_DIR="${RDIR}/out"
    PAPA_DIR="${RDIR}/papa"
    AIK_DIR="${RDIR}/AIK"
    
    # Clean or create output directory
    if [ -d "$OUT_DIR" ]; then
        rm -rf "$OUT_DIR"/*
    else
        mkdir -p "$OUT_DIR"
    fi
    
    # Clean or create papa directory
    if [ -d "$PAPA_DIR" ]; then
        rm -rf "$PAPA_DIR"/*
    else
        mkdir -p "$PAPA_DIR"
    fi
    
    # Check if AIK directory exists
    if [ ! -d "$AIK_DIR" ]; then
        log_error "AIK directory not found: $AIK_DIR"
        exit 1
    fi
    
    log_success "Build environment setup completed"
}

# Fungsi untuk cleanup previous build
cleanup_previous_build() {
    log_step "Cleaning previous build..."
    
    if [ -d "$AIK_DIR" ]; then
        rm -rf "${AIK_DIR}/split_img/boot.img-kernel" 2>/dev/null || true
        rm -rf "${AIK_DIR}/image-new.img" 2>/dev/null || true
        rm -rf "${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz" 2>/dev/null || true
        rm -rf "${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop" 2>/dev/null || true
        rm -rf "${AIK_DIR}/ramdisk-new.cpio.gz" 2>/dev/null || true
        log_success "Cleanup completed"
    else
        log_error "AIK directory not found: $AIK_DIR"
        exit 1
    fi
}

# Fungsi untuk membuat ramdisk
create_ramdisk() {
    log_step "Creating ramdisk..."
    
    local ramdisk_prop_file="${LOCATION}/early_setting/ramdisk_prop/${MODEL}.prop"
    
    if [ ! -f "$ramdisk_prop_file" ]; then
        log_error "Ramdisk property file not found: $ramdisk_prop_file"
        exit 1
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "${AIK_DIR}/ramdisk/system/etc/ramdisk"
    
    cp "$ramdisk_prop_file" "${AIK_DIR}/ramdisk/system/etc/ramdisk/build.prop"
    cd "${AIK_DIR}/ramdisk"
    if ! find . | cpio -o -H newc | gzip > ../split_img/boot.img-ramdisk.cpio.gz; then
        log_error "Failed to create ramdisk"
        exit 1
    fi
    cd "${LOCATION}"
    
    log_success "Ramdisk created"
}

# Fungsi untuk setup localversion
setup_localversion() {
    log_step "Setting up localversion..."
    
    KERNEL_DEFCONFIG="exynos9820-${DEVICE}_defconfig"
    local defconfig="${RDIR}/arch/arm64/configs/${KERNEL_DEFCONFIG}"
    local localversion="-StriveKernel-${MODEL}-${BUILD_KERNEL_VERSION}-A${PLATFORM_VERSION}"
    
    # Check if defconfig exists
    if [[ ! -f "$defconfig" ]]; then
        log_error "Defconfig not found: $defconfig"
        return 1
    fi
    
    # Backup original defconfig
    cp "$defconfig" "${defconfig}.bak"
    
    # Update CONFIG_LOCALVENSION - handle different formats
    sed -i "s/^CONFIG_LOCALVERSION=\".*\"/CONFIG_LOCALVERSION=\"${localversion}\"/" "$defconfig"
    sed -i "s/^CONFIG_LOCALVERSION=\"\"$/CONFIG_LOCALVERSION=\"${localversion}\"/" "$defconfig"
    
    # Update CONFIG_LOCALVERSION_AUTO - handle different formats  
    sed -i "s/^CONFIG_LOCALVERSION_AUTO=y/CONFIG_LOCALVERSION_AUTO=n/" "$defconfig"
    sed -i "s/^CONFIG_LOCALVERSION_AUTO is not set/CONFIG_LOCALVERSION_AUTO=n/" "$defconfig"
    
    log_success "Localversion set to: $localversion"
    log_info "Defconfig modified: $defconfig"
}

# Fungsi untuk compile kernel
compile_kernel() {
    log_step "Compiling kernel..."
    
    make ARCH=arm64 -j$(nproc --all) O=${OUT_DIR} mrproper
    
    if ! make ARCH=arm64 -j$(nproc --all) O=${OUT_DIR} exynos9820-${DEVICE}_defconfig papa.config ksu.config; then
        log_error "Kernel configuration failed"
        exit 1
    fi
    
    if ! make ARCH=arm64 -j$(nproc --all) O=${OUT_DIR}; then
        log_error "Kernel compilation failed"
        exit 1
    fi
    
    # Verify kernel image
    IMAGE="${OUT_DIR}/arch/arm64/boot/Image"
    if [ ! -f "$IMAGE" ]; then
        log_error "Kernel Image not found at $IMAGE"
        exit 1
    fi
    
    log_success "Kernel compilation completed"
}

# Fungsi untuk membuat boot.img
create_boot_img() {
    log_step "Creating boot.img..."
    
    cp "${IMAGE}" "${AIK_DIR}/split_img/boot.img-kernel"
    
    # Set board info
    BOARD_FILE="${AIK_DIR}/split_img/boot.img-board"
    case "$MODEL" in
        G970F) echo "SRPRI28A016KU" > "$BOARD_FILE" ;;
        G970N) echo "SRPRI28C007KU" > "$BOARD_FILE" ;;
        G973F) echo "SRPRI28B016KU" > "$BOARD_FILE" ;;            
        G973N) echo "SRPRI28D007KU" > "$BOARD_FILE" ;;
        G975F) echo "SRPRI17C016KU" > "$BOARD_FILE" ;;        
        G975N) echo "SRPRI28E007KU" > "$BOARD_FILE" ;;
        G977B) echo "SRPSC04B014KU" > "$BOARD_FILE" ;;        
        G977N) echo "SRPRK21D006KU" > "$BOARD_FILE" ;;
        N970F) echo "SRPSD26B009KU" > "$BOARD_FILE" ;;
        N971N) echo "SRPSD23A002KU" > "$BOARD_FILE" ;;
        N975F) echo "SRPSC14B009KU" > "$BOARD_FILE" ;;
        N976B) echo "SRPSC14C009KU" > "$BOARD_FILE" ;;        
        N976N) echo "SRPSD23C002KU" > "$BOARD_FILE" ;;
        *)
            log_error "Board configuration not implemented for model: $MODEL"
            exit 1
            ;;
    esac
    
    cd "${AIK_DIR}"
    if [ ! -f "./repackimg.sh" ]; then
        log_error "repackimg.sh not found in AIK directory"
        exit 1
    fi
    
    if ! ./repackimg.sh; then
        log_error "Failed to repack boot image"
        exit 1
    fi
    
    cd "${LOCATION}"
    
    if [ ! -f "${AIK_DIR}/image-new.img" ]; then
        log_error "Repacked image not found"
        exit 1
    fi
    
    mv "${AIK_DIR}/image-new.img" "${PAPA_DIR}/boot.img"
    
    log_success "boot.img created"
}

# Fungsi untuk membuat dt.img
create_dt_img() {
    log_step "Creating dt.img..."
    
    cd "${LOCATION}"
    
    case "${MODEL}" in
        G970F|G970N|G973F|G973N|G975F|G975N|G977B|G977N)
            python3 early_setting/mkdtboimg.py create dt.img \
                --page_size=2048 \
                --version=0 \
                --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
                ${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9820.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
            ;;
        N970F|N971N|N975F|N976B|N976N)
            python3 early_setting/mkdtboimg.py create dt.img \
                --page_size=2048 \
                --version=0 \
                --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
                ${OUT_DIR}/arch/arm64/boot/dts/exynos/exynos9825.dtb --custom0=0x00 --custom1=0xff --id=0x0 --rev=0x0 
            ;;
        *)
            log_error "DT configuration not implemented for model: $MODEL"
            exit 1
            ;;
    esac
    
    if [ ! -f "dt.img" ]; then
        log_error "dt.img creation failed"
        exit 1
    fi
    
    mv "dt.img" "${PAPA_DIR}/dt.img"
    log_success "dt.img created"
}

# Fungsi untuk membuat dtbo.img (disederhanakan)
create_dtbo_img() {
    log_step "Creating dtbo.img..."
    
    cd "${LOCATION}"
    
    # Check if mkdtboimg.py exists
    if [ ! -f "early_setting/mkdtboimg.py" ]; then
        log_error "mkdtboimg.py not found at early_setting/mkdtboimg.py"
        exit 1
    fi
    
    # Hanya menangani beberapa model sebagai contoh
    case "${MODEL}" in
        G970F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_22.dtbo --custom0=0x16 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_eur_open_25.dtbo --custom0=0x19 --custom1=0xff --id=0x0 --rev=0x0 	
        ;;
    G970N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_20.dtbo --custom0=0x14 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond0lte_kor_25.dtbo --custom0=0x19 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G973F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_eur_open_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0 
        ;;        
    G973N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_21.dtbo --custom0=0x15 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond1lte_kor_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G975F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_04.dtbo --custom0=0x04 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_20.dtbo --custom0=0x14 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_25.dtbo --custom0=0x19 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_eur_open_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0 
  	;;
    G975N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_20.dtbo --custom0=0x14 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_24.dtbo --custom0=0x18 --custom1=0x18 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_25.dtbo --custom0=0x19 --custom1=0x19 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyond2lte_kor_26.dtbo --custom0=0x1a --custom1=0xff --id=0x0 --rev=0x0
        ;;
    G977B )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_00.dtbo --custom0=0x00 --custom1=0x00 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_01.dtbo --custom0=0x01 --custom1=0x01 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_02.dtbo --custom0=0x02 --custom1=0x02 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_03.dtbo --custom0=0x03 --custom1=0x03 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_04.dtbo --custom0=0x04 --custom1=0x04 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_05.dtbo --custom0=0x05 --custom1=0x05 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_06.dtbo --custom0=0x06 --custom1=0x06 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_07.dtbo --custom0=0x07 --custom1=0x07 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_eur_open_08.dtbo --custom0=0x08 --custom1=0xff --id=0x0 --rev=0x0
        ;;         
    G977N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_00.dtbo --custom0=0x00 --custom1=0x00 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_01.dtbo --custom0=0x01 --custom1=0x01 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_02.dtbo --custom0=0x02 --custom1=0x02 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_03.dtbo --custom0=0x03 --custom1=0x03 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_04.dtbo --custom0=0x04 --custom1=0x04 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_05.dtbo --custom0=0x05 --custom1=0x05 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_06.dtbo --custom0=0x06 --custom1=0x06 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_07.dtbo --custom0=0x07 --custom1=0x07 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-beyondx_kor_08.dtbo --custom0=0x08 --custom1=0xff --id=0x0 --rev=0x0
        ;; 
    N970F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1_eur_open_23.dtbo --custom0=0x17 --custom1=0xff --id=0x0 --rev=0x0
        ;;        
    N971N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d1x_kor_23.dtbo --custom0=0x17 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    N975F )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2_eur_open_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0
        ;;
    N976B )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_19.dtbo --custom0=0x13 --custom1=0x13 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_20.dtbo --custom0=0x14 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_eur_open_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0    
        ;;                  
    N976N )
        python3 early_setting/mkdtboimg.py create dtbo.img \
  	--page_size=2048 \
  	--version=0 \
  	--id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_02.dtbo --custom0=0x02 --custom1=0x0f --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_16.dtbo --custom0=0x10 --custom1=0x10 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_17.dtbo --custom0=0x11 --custom1=0x11 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_18.dtbo --custom0=0x12 --custom1=0x12 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_19.dtbo --custom0=0x13 --custom1=0x14 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_21.dtbo --custom0=0x15 --custom1=0x15 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_22.dtbo --custom0=0x16 --custom1=0x16 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_23.dtbo --custom0=0x17 --custom1=0x17 --id=0x0 --rev=0x0 \
  	${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-d2x_kor_24.dtbo --custom0=0x18 --custom1=0xff --id=0x0 --rev=0x0
        ;;
        *)
            log_warning "DTBO configuration not fully implemented for model: $MODEL, using minimal configuration"
            # Fallback minimal configuration
            python3 early_setting/mkdtboimg.py create dtbo.img \
                --page_size=2048 \
                --version=0 \
                --id=0x0 --rev=0x0 --custom0=0x0 --custom1=0x0 --custom2=0x0 --custom3=0x0 \
                ${OUT_DIR}/arch/arm64/boot/dts/samsung/exynos9820-${DEVICE}_*.dtbo
            ;;
    esac
    
    if [ ! -f "dtbo.img" ]; then
        log_error "dtbo.img creation failed"
        exit 1
    fi
    
    mv "dtbo.img" "${PAPA_DIR}/dtbo.img"
    log_success "dtbo.img created"
}

# Fungsi untuk membuat package Odin
create_odin_package() {
    log_step "Creating Odin package..."
    
    cd "${PAPA_DIR}"
    
    # Check if required files exist
    if [ ! -f "boot.img" ] || [ ! -f "dt.img" ] || [ ! -f "dtbo.img" ]; then
        log_error "Required image files not found in ${PAPA_DIR}"
        exit 1
    fi
    
    if ! tar -cvf "StriveKernel_${MODEL}_${BUILD_KERNEL_VERSION}_Odin_KSUN.tar" boot.img dt.img dtbo.img; then
        log_error "Failed to create Odin package"
        exit 1
    fi
    
    log_success "Odin package created"
}

# Fungsi untuk membuat package TWRP
create_twrp_package() {
    log_step "Creating TWRP package..."
    
    cd "${LOCATION}"
    if [ -d "$(pwd)/early_setting/META-INF" ]; then
        cp -ar "$(pwd)/early_setting/META-INF" "${PAPA_DIR}/META-INF"
    else
        log_warning "META-INF directory not found, TWRP package may not work properly"
    fi
    
    cd "${PAPA_DIR}"
    
    # Check if required files exist
    if [ ! -f "boot.img" ] || [ ! -f "dt.img" ] || [ ! -f "dtbo.img" ]; then
        log_error "Required image files not found in ${PAPA_DIR}"
        exit 1
    fi
    
    if ! zip -r "StriveKernel_${MODEL}_${BUILD_KERNEL_VERSION}_TWRP_KSUN.zip" META-INF boot.img dt.img dtbo.img; then
        log_error "Failed to create TWRP package"
        exit 1
    fi
    
    log_success "TWRP package created"
}

# Fungsi untuk cleanup akhir
final_cleanup() {
    log_step "Performing final cleanup..."
    
    if [ -d "$AIK_DIR" ]; then
        rm -rf ${AIK_DIR}/split_img/boot.img-kernel 2>/dev/null || true
        rm -rf ${AIK_DIR}/split_img/boot.img-ramdisk.cpio.gz 2>/dev/null || true
        rm -rf ${AIK_DIR}/ramdisk-new.cpio.gz 2>/dev/null || true
    fi
    
    log_success "Cleanup completed"
}

# Fungsi utama
main() {
    log_info "🚀 Starting kernel build process..."
    echo "=========================================="
    
    # Setup model dan version
    MODEL=${MODEL:-$DEFAULT_MODEL}
    MODEL=$(echo "$MODEL" | tr '[:lower:]' '[:upper:]')
    
    # Parse arguments first to override defaults
    parse_arguments "$@"
    
    # Set version after parsing arguments
    BUILD_KERNEL_VERSION=${BUILD_KERNEL_VERSION:-$DEFAULT_KERNEL_VERSION}
    
    # Validasi
    validate_model
    
    # Display build info
    echo "🔨 Building kernel for: $MODEL"
    echo "📋 Version: $BUILD_KERNEL_VERSION"
    echo "📁 Working directory: $RDIR"
    echo "=========================================="
    
    # Eksekusi proses build
    setup_device
    setup_tzdev
    
    log_step "Updating submodules..."
    git submodule init && git submodule update --remote
    
    setup_toolchain
    setup_build_env
    cleanup_previous_build
    create_ramdisk
    setup_localversion
    compile_kernel
    create_boot_img
    create_dt_img
    create_dtbo_img
    create_odin_package
    create_twrp_package
    final_cleanup
    
    # Output final
    echo ""
    log_success "Build completed successfully! 🎉"
    echo "📦 Output files in ${PAPA_DIR}/:"
    echo "   - StriveKernel_${MODEL}_${BUILD_KERNEL_VERSION}_Odin_KSUN.tar"
    echo "   - StriveKernel_${MODEL}_${BUILD_KERNEL_VERSION}_TWRP_KSUN.zip"
    echo ""
    log_info "Model: $MODEL | Device: $DEVICE | Version: $BUILD_KERNEL_VERSION"
}

# =============================================================================
# EKSEKUSI SCRIPT
# =============================================================================

# Pastikan script tidak di-source melainkan di-execute langsung
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
