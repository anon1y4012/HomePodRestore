#!/bin/bash

# Variables
OTA_URL="https://updates.cdn-apple.com/2024SummerFCS/patches/052-80875/A1DC193D-202E-4051-8A46-EDA77D3243EF/com_apple_MobileAsset_SoftwareUpdate/434325375ab97e7714acfa0bf7e93447ee45c3a7.zip"
IPSW_URL="https://updates.cdn-apple.com/2024SummerFCS/fullrestores/052-80874/C1704385-4B55-4D46-B8DE-D3A6DA3AE514/AppleTV5,3_17.6_21M71_Restore.ipsw"
DOWNLOADS_DIR="$HOME/Downloads"
OTA_ZIP="$DOWNLOADS_DIR/434325375ab97e7714acfa0bf7e93447ee45c3a7.zip"
IPSW_FILE="$DOWNLOADS_DIR/21M71.ipsw"
OUTPUT_IPSW="$DOWNLOADS_DIR/17.6.ipsw"
BREW_DEPENDENCIES=("libimobiledevice-glue" "libimobiledevice" "libirecovery" "idevicerestore" "gaster" "ldid-procursus" "tsschecker" "img4tool" "ra1nsn0w")
KEYS_URL="https://github.com/UnbendableStraw/homepod-restore/raw/main/_keys_17.5_and_17.6.zip"
KEYS_ZIP="$DOWNLOADS_DIR/_keys_17.5_and_17.6.zip"

# Functions
function check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ $? -eq 0 ]; then
            echo "Homebrew installed successfully."

            # Get the current user's home directory
            USER_HOME=$(eval echo ~$USER)

            # Append the necessary configuration to the user's profile
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$USER_HOME/.profile"
            eval "$(/usr/local/bin/brew shellenv)"

            echo "Homebrew environment set up for the current session."
        else
            echo "Homebrew installation failed. Exiting."
            exit 1
        fi
    else
        echo "Homebrew is already installed."
    fi
}


function install_dependencies() {
    echo "Tapping d235j/ios-restore-tools..."
    brew tap d235j/ios-restore-tools

    for dep in "${BREW_DEPENDENCIES[@]}"; do
        if ! brew list $dep &> /dev/null; then
            echo "Installing $dep..."
            brew install --HEAD "$dep"
        else
            echo "$dep is already installed."
        fi
    done
}

function check_and_download_files() {
    # Function to get the file size on macOS
    get_file_size() {
        if [[ "$OSTYPE" == "darwin"* ]]; then
            stat -f%z "$1"
        else
            stat -c%s "$1"
        fi
    }

    # Function to check the MD5 checksum
    verify_md5() {
        local file=$1
        local expected_md5=$2
        local actual_md5

        if [[ "$OSTYPE" == "darwin"* ]]; then
            actual_md5=$(md5 -q "$file")
        else
            actual_md5=$(md5sum "$file" | awk '{ print $1 }')
        fi

        if [[ "$actual_md5" == "$expected_md5" ]]; then
            return 0  # Checksum matches
        else
            return 1  # Checksum does not match
        fi
    }

    # Download the OTA ZIP file
    if [ ! -f "$OTA_ZIP" ]; then
        echo "Downloading OTA ZIP..."
        curl -L -C - -o "$OTA_ZIP" "$OTA_URL"
        if [ $? -ne 0 ] || [ ! -s "$OTA_ZIP" ]; then
            echo "Failed to download OTA ZIP. Please check your connection or the URL."
            exit 1
        fi
    else
        echo "OTA ZIP already exists at $OTA_ZIP"
    fi

    # Expected MD5 checksum for the IPSW file
    expected_ipsw_md5="c942c28915fcc2ee3c55cd9e17e1dc7d"

    # Download the IPSW file
    if [ -f "$IPSW_FILE" ]; then
        echo "IPSW file already exists at $IPSW_FILE. Verifying checksum..."
        if ! verify_md5 "$IPSW_FILE" "$expected_ipsw_md5"; then
            echo "Checksum does not match. Deleting and redownloading IPSW file..."
            rm -f "$IPSW_FILE"
        else
            echo "Checksum matches. Using existing IPSW file."
        fi
    fi

    if [ ! -f "$IPSW_FILE" ]; then
        echo "Downloading IPSW file..."
        curl -L -C - -o "$IPSW_FILE" "$IPSW_URL"
        if [ $? -ne 0 ] || [ ! -s "$IPSW_FILE" ] || [ "$(get_file_size "$IPSW_FILE")" -lt 100000 ]; then
            echo "Failed to download IPSW file. Please check your connection or the URL."
            exit 1
        fi

        # Verify the MD5 checksum after downloading
        if ! verify_md5 "$IPSW_FILE" "$expected_ipsw_md5"; then
            echo "Checksum verification failed after download. Exiting."
            exit 1
        else
            echo "Checksum verification successful."
        fi
    fi

    # Download the keys ZIP file
    if [ ! -f "$KEYS_ZIP" ]; then
        echo "Downloading keys ZIP..."
        curl -L -C - -o "$KEYS_ZIP" "$KEYS_URL"
        if [ $? -ne 0 ] || [ ! -s "$KEYS_ZIP" ]; then
            echo "Failed to download keys ZIP. Please check your connection or the URL."
            exit 1
        fi
    else
        echo "Keys ZIP already exists at $KEYS_ZIP"
    fi
}

function cleanup() {
    echo "Performing cleanup"
    rm -rf "${tmpdir}" 2>/dev/null || sudo rm -rf "${tmpdir}"
}

function get_ticket() {
    target=$1
    buildmanifest=$2
    output=$3
    echo "Getting OTA ticket for target '${target}'"
    tsschecker -d "${target}" -m "${buildmanifest}" -s"${output}"
}

function patch_asr() {
    asrpath=$1
    echo "Patching ASR"
    strloc=$(binrider --string "Image failed signature verification." "${asrpath}" | grep "Found 'Image failed signature verification.' at" | rev | cut -d ' ' -f1 | rev)
    strref=$(binrider --xref "${strloc}" "${asrpath}" | grep "Found xrefs at" | rev | cut -d ' ' -f1 | rev)
    bof=$(binrider --bof "${strref}" "${asrpath}" | grep "Found beginning of function at" | rev | cut -d ' ' -f1 | rev)
    cref=$(binrider --cref "${bof}" "${asrpath}" | grep "Found call refs at" | rev | cut -d ' ' -f1 | rev)
    paddr=""
    for i in $(seq 0 4 0x30); do
        tgtdec=$((${cref} - ${i}))
        tgt=$(printf '0x%x\n' ${tgtdec})
        failstr="No refs found to ${tgt}"
        bref=$(binrider --bref "${tgt}" "${asrpath}")
        if echo "${bref}" | grep "${failstr}"; then
            continue
        fi
        paddr=$(echo "${bref}" | grep "Found branch refs at" | head -n1 | rev | cut -d ' ' -f1 | rev)
        break
    done
    if [ -z "${paddr}" ]; then
        echo "Patchfinder failed to find patch addr"
        exit 3
    fi
    fof=$(binrider --fof "${paddr}" "${asrpath}" | grep "Found fileoffset at" | rev | cut -d ' ' -f1 | rev)

    echo "Patching file"
    echo -en "\x1F\x20\x03\xD5" | sudo dd of="${asrpath}" bs=1 seek=$((${fof})) conv=notrunc count=4

    echo "Resigning file"
    sudo ldid -s "${asrpath}"
}

function make_rootfs() {
    otadir="$1"
    outramdisk="$2"
    wrkdir="$3"

    rootfsdir="${wrkdir}/rootfs"
    mkdir -p "${rootfsdir}"

    for i in $(awk -F':' '{print $1}' "${otadir}/AssetData/payloadv2/payload_chunks.txt"); do 
        nn=$(printf "%03d" "$i")
        echo "Extracting chunk ${nn}..."
        sudo yaa extract -v -d "${rootfsdir}" -i "${otadir}/AssetData/payloadv2/payload.${nn}"
    done
  
    # Copy UNMODIFIED ramdisk
    sudo cp -a "${otadir}/AssetData/payload/replace/usr/standalone/update/ramdisk/arm64SURamDisk.dmg" "${rootfsdir}/usr/standalone/update/ramdisk/"
    sudo chown root:wheel "${rootfsdir}/usr/standalone/update/ramdisk/arm64SURamDisk.dmg"
    sudo chmod 644 "${rootfsdir}/usr/standalone/update/ramdisk/arm64SURamDisk.dmg"
    sudo /usr/bin/xattr -c "${rootfsdir}/usr/standalone/update/ramdisk/arm64SURamDisk.dmg"

    BUILDTRAIN="$(/usr/bin/plutil -extract "BuildIdentities".0."Info"."BuildTrain" raw -o - "${otadir}/AssetData/boot/BuildManifest.plist")"
    BUILDNUMBER="$(/usr/bin/plutil -extract "BuildIdentities".0."Info"."BuildNumber" raw -o - "${otadir}/AssetData/boot/BuildManifest.plist")"
    APTARGETTYPE="$(/usr/bin/plutil -extract "BuildIdentities".0."Ap,TargetType" raw -o - "${otadir}/AssetData/boot/BuildManifest.plist")"
    VOLNAME="${BUILDTRAIN}${BUILDNUMBER}.${APTARGETTYPE}OS"
    IMGSIZE_MB=$(($(sudo du -A -s -m "${rootfsdir}" | awk '{ print $1 }')+100))

    # Create DMG 100MB larger
    echo "Creating a dmg with ${IMGSIZE_MB} MB free"
    IMGFILEINFO="$(hdiutil create -megabytes "${IMGSIZE_MB}" -layout NONE -attach -volname RESTORE -fs 'exFAT' "${wrkdir}/os.udrw.dmg")"
    IMGNODE="$(echo "$IMGFILEINFO" | head -n1 | awk '{print $1}')"
    diskutil unmountDisk "${IMGNODE}"
    diskutil partitionDisk -noEFI ${IMGNODE} 1 "GPT" "Free Space" "${VOLNAME}" 100
    APFSOUTPUT="$(diskutil apfs createContainer "${IMGNODE}")"
    APFSNODE="$(echo "$APFSOUTPUT" | grep 'Disk from APFS operation' | awk '{print $5}')"
    APFSVOLOUTPUT="$(diskutil apfs addVolume "${APFSNODE}" "Case-sensitive APFS" "${VOLNAME}" -role S)"
    APFSVOLNODE="$(echo "$APFSVOLOUTPUT" | grep 'Disk from APFS operation' | awk '{print $5}')"

    sudo diskutil enableOwnership ${APFSVOLNODE}

    if [[ $(diskutil info "${APFSVOLNODE}" | grep 'Mounted' | grep 'Yes') ]]; then
        MOUNTPOINT="$(diskutil info "${APFSVOLNODE}" | grep 'Mount Point' | sed 's/[[:space:]]*Mount\ Point:[[:space:]]*//')"
    else
        echo "Disk image is not mounted or could not determine mountpoint."
        exit 1
    fi

    echo "Copying to ${APFSVOLNODE} aka ${MOUNTPOINT}"
    sudo ditto "${rootfsdir}" "${MOUNTPOINT}"

    sudo rm -rf "${MOUNTPOINT}/.fseventsd"

    # Fix up the extracted files
    sudo yaa check-and-fix -d "${MOUNTPOINT}" -i "${otadir}/AssetData/payloadv2/fixup.manifest"

    # Eject rootfs
    hdiutil detach "${MOUNTPOINT}"

    # Convert image to ULFO format
    echo "Converting to ULFO format"
    hdiutil convert -format ULFO -o "${outramdisk}" "${wrkdir}/os.udrw.dmg"
    asr imagescan --source "${outramdisk}"
    echo "Done creating rootfs"
}

function create_ipsw() {
    otaPath=$1
    donorPath=$2
    outputPath=$3
    keysPath=$4
    tmpdir=$(mktemp -d /tmp/homepodtmpXXXXXXXXXX)
    ipswdir=${tmpdir}/ipsw
    otadir=${tmpdir}/ota
    ra1nsn0wdir=${tmpdir}/ra1nsn0w
    rootfswrkdir=${tmpdir}/rootfswrkdir
    mkdir -p ${ipswdir} ${otadir} ${ra1nsn0wdir} ${rootfswrkdir}

    if [ -f "$outputPath" ]; then
        echo "Existing IPSW file found at $outputPath, skipping IPSW creation."
        return 0
    fi

    echo "Extracting OTA to '${otadir}'"
    unzip ${otaPath} -d ${otadir}

    make_rootfs ${otadir} "${ipswdir}/myrootfs.dmg" ${rootfswrkdir}

    mv "${otadir}/AssetData/boot/"* "${ipswdir}/"
    rm -rf "${otadir}/AssetData/boot/"

    targetProduct=$(plutil -extract "BuildIdentities".0."Ap,ProductType" raw "${ipswdir}/BuildManifest.plist")
    targetHardware=$(plutil -extract "BuildIdentities".0."Ap,Target" raw "${ipswdir}/BuildManifest.plist")
    echo "Found target: '${targetProduct}' '${targetHardware}'"
    get_ticket ${targetProduct} "${ipswdir}/BuildManifest.plist" "${tmpdir}/ticket.shsh2"

    # Pass the keys ZIP file directly to ra1nsn0w
    ra1nsn0w -t "${tmpdir}/ticket.shsh2" \
        --ipatch-no-force-dfu \
        --kpatch-always-get-task-allow \
        --kpatch-codesignature \
        -b "rd=md0 -v serial=3 nand-enable-reformat=1 -restore" \
        --dry-run "${targetProduct}":"${targetHardware}":1 \
        --dry-out "${ra1nsn0wdir}" \
        --ota "${otaPath}" \
        --keys-zip "$keysPath"

    if [ $? -ne 0 ]; then
        echo "ra1nsn0w failed, aborting."
        cleanup
        exit 1
    fi

    iBSSPathPart=$(plutil -extract "BuildIdentities".0.Manifest.iBSS.Info.Path raw "${ipswdir}/BuildManifest.plist")
    iBECPathPart=$(plutil -extract "BuildIdentities".0.Manifest.iBEC.Info.Path raw "${ipswdir}/BuildManifest.plist")

    echo "Deploying patched bootloaders"
    rm "${ipswdir}/${iBSSPathPart}"
    img4tool -e -p "${ipswdir}/${iBSSPathPart}" "${ra1nsn0wdir}/component1.bin"

    rm "${ipswdir}/${iBECPathPart}"
    img4tool -e -p "${ipswdir}/${iBECPathPart}" "${ra1nsn0wdir}/component2.bin"

    echo "Deploying patched kernel"
    ra1nsn0wLastComponent=$(ls -l ${ra1nsn0wdir} | tail -n1 | rev | cut -d ' ' -f1 | rev)
    img4tool -e -p "${ipswdir}/restorekernel.im4p" "${ra1nsn0wdir}/${ra1nsn0wLastComponent}"

    plutil -replace "BuildIdentities".0.Manifest.RestoreKernelCache.Info.Path -string restorekernel.im4p -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Extracting donor BuildManifest.plist"
    unzip "${donorPath}" -d "${tmpdir}" BuildManifest.plist

    cntIdentites=$(plutil -extract "BuildIdentities" xml1 -o - "${tmpdir}/BuildManifest.plist" | xmllint --xpath "count(//dict)" -)
    if [[ -z "$cntIdentites" ]]; then
        echo "Failed to extract build identities, please check the BuildManifest.plist."
        cleanup
        exit 1
    fi
    foundident="-1"
    echo "Donor has ${cntIdentites} build identities"

    for ((i=0; i<$cntIdentites; i++)); do
        echo "Checking identity ${i}..."
        variant=$(plutil -extract "BuildIdentities.${i}.Info.Variant" raw "${tmpdir}/BuildManifest.plist")
        if [[ "$variant" == *"Customer Erase Install (IPSW)"* ]]; then
            foundident=$i
            break
        fi
    done

    if [[ $foundident  -eq "-1" ]]; then
        echo "Failed to find target build identity"
        cleanup
        exit 2
    fi
    echo "Found target build identity (${foundident}), getting ramdisk"
    restoreramdisk=$(plutil -extract "BuildIdentities.${foundident}.Manifest.RestoreRamDisk.Info.Path" raw ${tmpdir}/BuildManifest.plist)

    echo "Extracting ramdisk '${restoreramdisk}'"
    unzip ${donorPath} -d ${tmpdir} ${restoreramdisk}
    img4tool -e -o "${tmpdir}/rdsk.dmg" "${tmpdir}/${restoreramdisk}"

    echo "Mounting ramdisk"
    mntpoint=$(hdiutil attach "${tmpdir}/rdsk.dmg" | tail -n1 | cut -d $'\t' -f3)
    echo "Ramdisk mounted at '${mntpoint}'"

    if [[ ! -f "${mntpoint}/usr/local/bin/restored_external" ]]; then
        echo "Ramdisk does not contain a restored_external binary. Either the IPSW is corrupt/incorrect, or this script has a bug."
        cleanup
        exit 3
    fi

    echo "Patching ASR"
    patch_asr "${mntpoint}/usr/sbin/asr"

    echo "Unmounting ramdisk"
    hdiutil detach "${mntpoint}"

    echo "Patching RestoreRamDisk path in BuildManifest"
    plutil -replace "BuildIdentities".0.Manifest.RestoreRamDisk.Info.Path -string myramdisk.dmg -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Packing ramdisk to IM4P file"
    img4tool -c "${ipswdir}/myramdisk.dmg" -t rdsk "${tmpdir}/rdsk.dmg"

    echo "Patching OS path in BuildManifest"
    plutil -replace "BuildIdentities".0.Manifest.OS.Info.Path -string myrootfs.dmg -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Setting Restore behavior in BuildManifest"
    plutil -replace "BuildIdentities".0.Info.RestoreBehavior -string "Erase" -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Setting Variant in BuildManifest to match Erase Install"
    plutil -replace "BuildIdentities".0.Info.Variant -string "Customer Erase Install (IPSW)" -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Setting RecoveryVariant in BuildManifest to match Recovery Customer Install"
    plutil -replace "BuildIdentities".0.Info.RecoveryVariant -string "Recovery Customer Install" -o "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"
    mv -f "${ipswdir}/BuildManifest_new.plist" "${ipswdir}/BuildManifest.plist"

    echo "Compressing IPSW"
    (
        cd "${ipswdir}"
        zip -r "${tmpdir}/mycfw.ipsw" .
    )
    mv "${tmpdir}/mycfw.ipsw" "${outputPath}"

    cleanup
    echo "Done!!"
}

function restore_homepod() {
    echo "Starting HomePod restore process..."
    gaster pwn
    gaster reset
    idevicerestore -d -e "$OUTPUT_IPSW"
}

# Main script


echo "Checking for Homebrew..."
check_homebrew

echo "Installing dependencies..."
install_dependencies

echo "Checking for existing output IPSW..."
if [ -f "$OUTPUT_IPSW" ]; then
    echo "Existing output IPSW found at $OUTPUT_IPSW. Skipping download and assembly."
else

    echo "Checking and downloading necessary files..."
    check_and_download_files

    echo "Creating IPSW file..."
    create_ipsw "$OTA_ZIP" "$IPSW_FILE" "$OUTPUT_IPSW" "$KEYS_ZIP"
fi
echo "Restoring HomePod..."
restore_homepod

echo "Process complete!"