#!/bin/sh
# Reshape Firebase / GoogleAppMeasurement macOS frameworks from shallow
# bundles into Apple's versioned layout so Xcode Validate Product can pass.
# Wired as a late app-target Run Script phase so it runs before Validate.

set -e

FRAMEWORKS_DIR="${1:-}"
if [ -z "$FRAMEWORKS_DIR" ]; then
    if [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
        FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
    fi
fi

if [ -z "$FRAMEWORKS_DIR" ] || [ ! -d "$FRAMEWORKS_DIR" ]; then
    echo "note: no Frameworks directory to reshape; skipping"
    exit 0
fi

reshape_framework() {
    name="$1"
    fw="${FRAMEWORKS_DIR}/${name}.framework"
    if [ ! -d "$fw" ]; then
        return 0
    fi

    if [ -L "$fw/Versions/Current" ] && [ -L "$fw/$name" ]; then
        if [ ! -f "$fw/Info.plist" ] || [ -L "$fw/Info.plist" ]; then
            echo "note: $name.framework already versioned"
            return 0
        fi
    fi

    echo "note: reshaping $name.framework into a versioned macOS bundle"
    tmp="${TMPDIR:-/tmp}/casmos-fw-$$-${name}"
    rm -rf "$tmp"
    dest="$tmp/Versions/A"
    mkdir -p "$dest"

    if [ -d "$fw/Versions/A" ]; then
        cp -R "$fw/Versions/A/." "$dest/"
    elif [ -d "$fw/Versions/Current" ]; then
        cp -R "$fw/Versions/Current/." "$dest/"
    fi

    for item in "$fw"/*; do
        [ -e "$item" ] || continue
        base=`basename "$item"`
        if [ "$base" = "Versions" ]; then
            continue
        fi
        if [ -L "$item" ]; then
            continue
        fi
        if [ -d "$item" ]; then
            mkdir -p "$dest/$base"
            cp -R "$item/." "$dest/$base/"
        else
            cp "$item" "$dest/$base"
        fi
    done

    if [ -f "$dest/Info.plist" ]; then
        mkdir -p "$dest/Resources"
        if [ ! -f "$dest/Resources/Info.plist" ]; then
            mv "$dest/Info.plist" "$dest/Resources/Info.plist"
        else
            rm -f "$dest/Info.plist"
        fi
    fi

    find "$fw" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    mkdir -p "$fw/Versions"
    mv "$dest" "$fw/Versions/A"
    ln -s A "$fw/Versions/Current"
    ln -s "Versions/Current/$name" "$fw/$name"
    if [ -e "$fw/Versions/Current/Resources" ]; then
        ln -s "Versions/Current/Resources" "$fw/Resources"
    fi
    if [ -e "$fw/Versions/Current/Headers" ]; then
        ln -s "Versions/Current/Headers" "$fw/Headers"
    fi
    if [ -e "$fw/Versions/Current/Modules" ]; then
        ln -s "Versions/Current/Modules" "$fw/Modules"
    fi
    if [ -e "$fw/Versions/Current/PrivateHeaders" ]; then
        ln -s "Versions/Current/PrivateHeaders" "$fw/PrivateHeaders"
    fi
    rm -rf "$tmp"

    if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
            --preserve-metadata=identifier,entitlements,flags "$fw" || true
    fi
}

reshape_framework GoogleAppMeasurement
reshape_framework FirebaseAnalytics
reshape_framework GoogleAppMeasurementIdentitySupport

exit 0
