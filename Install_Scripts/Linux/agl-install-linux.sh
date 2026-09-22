#!/usr/bin/env bash
# AGL installer / updater - Linux (Linux Mint, Ubuntu, Debian ...)
#
# Needs: unzip, python3, and curl or wget. A folder chooser opens if zenity or kdialog is
# available (zenity ships with Linux Mint); otherwise you are asked to type the folder.

set -euo pipefail
shopt -s nocasematch

# ======================= SETTINGS (edit only if the repo itself moves) =======================
# GITHUB_REPO     "owner/repo" of the public release repo. Everything else - which app version
#                 is current, which runtime and map builds exist - is found automatically from
#                 what is actually published there; this file does not need editing for a
#                 normal app, runtime, or map release.
# VERSION_DIR_PREFIX  the version folder is <prefix><gen>, e.g. Java25
# SETUP_SCRIPT    script in the version folder that fixes permissions and quarantines old jars
# SHORTCUT_SCRIPT script in the version folder that creates the Desktop icon
# START_SCRIPT    script in the version folder read for its AGL_TILES line
# DEFAULT_PARENT  folder the chooser opens on
GITHUB_REPO='alov1258/AGL-Release'
VERSION_DIR_PREFIX='Java'
SETUP_SCRIPT='install_AGL_linux.sh'
SHORTCUT_SCRIPT='AGL_shortcut.sh'
START_SCRIPT='AGL_start.sh'
DEFAULT_PARENT="$HOME/SOL"

# Other-OS clean-up: names/wildcards matched against items directly inside the version folder;
# a match is removed with its contents. Nothing this installer downloads is ever an other-OS
# file - this only matters for tidying up a folder from an older, single-zip release that had
# every OS's files together. Keep in step with the Windows/macOS lists.
CLEANUP_LINUX=('*.bat' 'macOS_jre*' 'windows_jre*' 'AGL_launcher.app' 'AGL.icns' 'AGL.ico' 'install_AGL.sh')
# ===============================================================================================

API_BASE="https://api.github.com/repos/$GITHUB_REPO"
USER_AGENT='Mozilla/5.0 (X11; Linux x86_64)'

if [ -t 1 ]; then Y=$'\033[33m'; R=$'\033[31m'; G=$'\033[32m'; C=$'\033[36m'; N=$'\033[0m'; else Y=''; R=''; G=''; C=''; N=''; fi
say()  { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$Y" "$*" "$N"; }

pause_exit() {
    echo
    if [ -t 0 ] && [ -t 1 ]; then read -r -p 'Press Enter to close ' _ || true; fi
    exit "$1"
}
fail() { echo; printf '%s*** %s%s\n' "$R" "$*" "$N" >&2; pause_exit 1; }

# ask "prompt" default  ->  prints the first letter of the answer, upper-cased
ask() {
    local reply=''
    read -r -p "$1 " reply || true
    reply=${reply:-$2}
    printf '%s' "${reply:0:1}" | tr '[:lower:]' '[:upper:]'
}

# choose_folder START DESCRIPTION -> prints the chosen folder (nothing = cancelled)
choose_folder() {
    local start=$1 desc=$2 out=''
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v zenity >/dev/null 2>&1; then
        out=$(zenity --file-selection --directory --title="$desc" --filename="$start/" 2>/dev/null) || out=''
    elif [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v kdialog >/dev/null 2>&1; then
        out=$(kdialog --title "$desc" --getexistingdirectory "$start" 2>/dev/null) || out=''
    else
        read -r -p "$desc [$start]: " out || true
        out=${out:-$start}
        out=${out/#\~/$HOME}
    fi
    printf '%s' "${out%/}"
}

downloads_dir() {
    local d=''
    if command -v xdg-user-dir >/dev/null 2>&1; then d=$(xdg-user-dir DOWNLOAD 2>/dev/null || true); fi
    if [ -z "$d" ] || [ "$d" = "$HOME" ]; then d="$HOME/Downloads"; fi
    mkdir -p "$d"
    printf '%s' "$d"
}

need_tools() {
    command -v unzip >/dev/null 2>&1 || fail "'unzip' is not installed. Install it with:  sudo apt install unzip"
    command -v python3 >/dev/null 2>&1 || fail "'python3' is not installed. Install it with:  sudo apt install python3"
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        fail "neither curl nor wget is installed. Try:  sudo apt install curl"
    fi
}

# ---------------------------------------------------------------- GitHub API

# github_get PATH -> the JSON body on stdout, or fails with a clear message
github_get() {
    local url="$API_BASE/$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -A "$USER_AGENT" -H 'Accept: application/vnd.github+json' "$url" ||
            fail "Could not reach GitHub ($url). Check your internet connection and try again."
    else
        wget -q -O - --user-agent="$USER_AGENT" --header='Accept: application/vnd.github+json' "$url" ||
            fail "Could not reach GitHub ($url). Check your internet connection and try again."
    fi
}

# Prints 5 lines: GEN, VERSION, NAME, URL, SIZE - the current app release's one zip asset.
latest_app() {
    github_get 'releases/latest' | python3 -c '
import json, re, sys
d = json.load(sys.stdin)
for a in d.get("assets", []):
    m = re.match(r"^agl(\d+)_([\d_]+)\.zip$", a["name"])
    if m:
        gen, ver = m.group(1), m.group(2).replace("_", ".")
        print(gen); print(gen + "." + ver); print(a["name"]); print(a["browser_download_url"]); print(a.get("size", 0))
        sys.exit(0)
sys.stderr.write("The latest release has no agl<gen>_<version>.zip asset.\n")
sys.exit(1)
' || fail 'Could not work out the current app release from GitHub.'
}

# runtime_asset TAG_PREFIX ASSET_NAME -> 4 lines: TAG, NAME, URL, SIZE of the highest-numbered
# "<TAG_PREFIX>-<n>" release's matching asset, or nothing (exit 1) if there is no such release.
runtime_asset() {
    github_get 'releases' | python3 -c '
import json, re, sys
prefix, asset_name = sys.argv[1], sys.argv[2]
d = json.load(sys.stdin)
pattern = re.compile("^" + re.escape(prefix) + r"-(\d+)$")
best, best_n = None, -1
for r in d:
    m = pattern.match(r.get("tag_name", ""))
    if m and int(m.group(1)) > best_n:
        best_n, best = int(m.group(1)), r
if not best:
    sys.exit(1)
for a in best.get("assets", []):
    if a["name"] == asset_name:
        print(best["tag_name"]); print(a["name"]); print(a["browser_download_url"]); print(a.get("size", 0))
        sys.exit(0)
sys.exit(1)
' "$1" "$2"
}

# A map zip's tag is always its own name, so its URL needs no lookup at all.
map_zip_url() {
    printf 'https://github.com/%s/releases/download/%s/%s.zip' "$GITHUB_REPO" "$1" "$1"
}

# ---------------------------------------------------------------- download

# download URL DEST - a plain, direct download (GitHub's release CDN needs none of the
# multi-method/cookie-jar workarounds a blocking host like OneDrive used to need).
download() {
    local url=$1 dest=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar -A "$USER_AGENT" -o "$dest" "$url"
    else
        wget -q --show-progress --user-agent="$USER_AGENT" -O "$dest" "$url"
    fi
}

zip_ok()    { unzip -tq "$1" >/dev/null 2>&1; }
zip_names() { unzip -Z1 "$1"; }
zip_has_folder() { zip_names "$1" 2>/dev/null | awk -F/ -v f="$2" 'tolower($1)==tolower(f){found=1} END{exit !found}'; }

# get_or_download URL NAME DOWNLOADS EXPECT_FOLDER -> prints the path. Reuses a valid copy
# already in Downloads (e.g. from a previous run that got this far) instead of re-fetching.
get_or_download() {
    local url=$1 name=$2 downloads=$3 expect=$4
    local zip="$downloads/$name" part="$downloads/$name.part"
    if [ -f "$zip" ] && zip_ok "$zip" && zip_has_folder "$zip" "$expect"; then
        warn "$name is already in your Downloads folder - using it." >&2
        printf '%s' "$zip"
        return 0
    fi
    say "Downloading $name ..." >&2
    rm -f "$part"
    download "$url" "$part"
    if ! zip_ok "$part"; then rm -f "$part"; fail "$name did not download as a valid zip file."; fi
    if ! zip_has_folder "$part" "$expect"; then rm -f "$part"; fail "$name does not contain a '$expect' folder."; fi
    mv -f "$part" "$zip"
    printf '%s' "$zip"
}

# One line that counts unzip's work, rewritten in place
show_count() {
    awk 'BEGIN{n=0} /^ *(inflating|extracting|creating|linking):/ {n++; if (n%25==0) {printf "\r  Extracting: %d items", n; fflush()}} END{printf "\r  Extracting: %d items\n", n}'
}

# extract_zip ZIP DEST EXPECT_FOLDER - the zip must hold a top-level EXPECT_FOLDER; unzip's
# "warning" exit code 1 is accepted. Never calls fail() itself: it returns 1 on a problem so a
# caller like install_tiles can recover, while set -e still makes it fatal at an unguarded call.
extract_zip() {
    local zip=$1 dest=$2 expect=$3 rc
    if ! zip_has_folder "$zip" "$expect"; then
        echo "The zip does not contain a '$expect' folder." >&2
        return 1
    fi
    set +e +o pipefail
    unzip -o "$zip" -d "$dest" | show_count
    rc=${PIPESTATUS[0]}
    set -e -o pipefail
    [ "$rc" -le 1 ]
}

# ---------------------------------------------------------------- clean up / same-release check

valid_pattern() { [[ -n $1 && $1 != '*' && $1 != */* ]]; }
is_other_os() {
    local p
    for p in "${CLEANUP_LINUX[@]}"; do
        valid_pattern "$p" || continue
        if [[ $1 == $p ]]; then return 0; fi
    done
    return 1
}

# Removes other-OS items from an older, single-zip-era install left in DIR.
remove_leftovers() {
    local dir=$1 item n
    REMOVED=()
    for item in "$dir"/* "$dir"/.[!.]*; do
        if [ ! -e "$item" ] && [ ! -L "$item" ]; then continue; fi
        n=$(basename "$item")
        if is_other_os "$n"; then rm -rf -- "$item"; REMOVED+=("$n"); fi
    done
}

# Zips built on Windows can carry CRLF line endings and lose executable bits.
fix_files() {
    local dir=$1 f
    for f in "$dir"/*.sh; do
        [ -f "$f" ] || continue
        if grep -q $'\r' "$f"; then sed -i 's/\r$//' "$f"; fi
        chmod +x "$f"
    done
}

# True when RELEASE_DIR/JAR_NAME inside ZIP has identical content to TARGET_DIR/JAR_NAME.
same_app_release() {
    local zip=$1 release_dir=$2 jar_name=$3 target_dir=$4
    local installed="$target_dir/$jar_name"
    [ -f "$installed" ] || return 1
    local zip_hash local_hash
    zip_hash=$(unzip -p "$zip" "$release_dir/$jar_name" 2>/dev/null | sha256sum | cut -d' ' -f1) || return 1
    local_hash=$(sha256sum "$installed" | cut -d' ' -f1)
    [ -n "$zip_hash" ] && [ "$zip_hash" = "$local_hash" ]
}

# Reads AGL_TILES=... out of the extracted AGL_start.sh, the same way the start script itself
# decides which map folder it wants.
tile_name_from_start_script() {
    local f=$1
    [ -f "$f" ] || return 1
    sed -n -E 's/^AGL_TILES=(.+)$/\1/p' "$f" | head -n 1
}

# ---------------------------------------------------------------- runtime components

# install_if_missing URL NAME EXPECT_FOLDER VERSION_PATH DOWNLOADS - only fetched if
# EXPECT_FOLDER is not already there; the JRE is large and changes rarely.
install_if_missing() {
    local url=$1 name=$2 expect=$3 vpath=$4 downloads=$5
    if [ -d "$vpath/$expect" ]; then
        say "$expect is already present."
        return 0
    fi
    local zip; zip=$(get_or_download "$url" "$name" "$downloads" "$expect")
    say "Extracting $name ..."
    extract_zip "$zip" "$vpath" "$expect" || fail "Could not extract $name into $vpath."
    say "$expect installed."
}

# install_lib_always URL NAME EXPECT_FOLDER VERSION_PATH DOWNLOADS - always re-fetched and
# re-extracted, since a lib jar can be patched on its own between app releases.
install_lib_always() {
    local url=$1 name=$2 expect=$3 vpath=$4 downloads=$5
    local zip; zip=$(get_or_download "$url" "$name" "$downloads" "$expect")
    say "Extracting $name ..."
    extract_zip "$zip" "$vpath" "$expect" || fail "Could not extract $name into $vpath."
    say "$expect updated."
}

# Makes sure VERSION_PATH/NAME exists, downloading and unpacking the maps zip if not.
# Never exits: returns 1 on a problem so the rest of the run can finish.
install_tiles() {
    local vpath=$1 name=$2 downloads=$3
    local target="$vpath/$name" zip tmp
    if [ -d "$target" ]; then say "Map tiles '$name' are already present."; return 0; fi
    say "Map tiles '$name' are missing - downloading (a big download: it can take several minutes) ..."
    if ! zip=$(get_or_download "$(map_zip_url "$name")" "$name.zip" "$downloads" "$name"); then
        warn "*** Map tiles were NOT installed."
        return 1
    fi
    tmp="$vpath/_tiles_tmp"
    rm -rf "$tmp"; mkdir -p "$tmp"
    say 'Extracting map tiles...'
    if extract_zip "$zip" "$tmp" "$name" && [ -d "$tmp/$name" ] && mv "$tmp/$name" "$target"; then
        rm -rf "$tmp"
        say "Map tiles installed in $target"
        return 0
    fi
    rm -rf "$tmp"
    warn "*** Map tiles were NOT installed: could not unpack $name.zip."
    return 1
}

# ---------------------------------------------------------------- desktop icon

desktop_dir() {
    local d=''
    if command -v xdg-user-dir >/dev/null 2>&1; then d=$(xdg-user-dir DESKTOP 2>/dev/null || true); fi
    if [ -z "$d" ] || [ "$d" = "$HOME" ]; then d="$HOME/Desktop"; fi
    printf '%s' "$d"
}

# The "Path=" line of an existing .desktop file, or nothing if it cannot be read.
shortcut_work_dir() {
    [ -f "$1" ] || return 1
    sed -n -E 's/^Path=(.+)$/\1/p' "$1" | head -n 1
}

# The install this generation's Desktop icon already points at, or nothing.
find_existing_install() {
    local gen=$1 link
    link="$(desktop_dir)/AGL${gen}.desktop"
    [ -f "$link" ] || return 1
    local dir; dir=$(shortcut_work_dir "$link") || return 1
    [ -n "$dir" ] && [ -d "$dir" ] && printf '%s' "$dir"
}

update_shortcut() {
    local vpath=$1 gen=$2 script link_name link_path here there
    script="$vpath/$SHORTCUT_SCRIPT"
    if [ ! -f "$script" ]; then
        warn "Desktop icon skipped: $SHORTCUT_SCRIPT was not found in $vpath."
        return 0
    fi
    link_name="AGL${gen}.desktop"
    link_path="$(desktop_dir)/$link_name"
    echo
    if [ -f "$link_path" ]; then
        here=${vpath%/}
        there=$(shortcut_work_dir "$link_path" || true); there=${there%/}
        if [ "$there" = "$here" ]; then
            say "The Desktop icon $link_name already points at this install."
            return 0
        fi
        if [ "$(ask "The Desktop icon $link_name points somewhere else ($there). Update it to this install? (Y/N) [Y]" Y)" != Y ]; then
            say 'No icon added.'
            return 0
        fi
    else
        if [ "$(ask 'Add an AGL icon to the Desktop? (Y/N) [Y]' Y)" != Y ]; then
            say 'No icon added.'
            return 0
        fi
    fi
    AGL_GEN=$gen bash "$script"
    if [ -f "$link_path" ]; then
        say "Desktop icon $link_name created."
    else
        warn 'The icon script ran, but no icon was found afterwards - check the Desktop.'
    fi
}

# ---------------------------------------------------------------- main

main() {
    need_tools
    echo
    printf '%sAGL installer / updater (Linux)%s\n' "$C" "$N"
    echo
    warn 'Note: the screen can seem to stand still for a while during downloads and unpacking.'
    warn 'Nothing is wrong - please be patient and leave this window open.'
    echo

    # 1. Which app release is current, and where does it belong?
    say 'Checking the latest release...'
    local gen version name url size
    { read -r gen; read -r version; read -r name; read -r url; read -r size; } < <(latest_app)
    local release_dir="${VERSION_DIR_PREFIX}${gen}"
    say "Latest release: AGL $version"

    # 2. Is it already installed somewhere this account knows about? If so, skip the folder
    #    chooser entirely, but confirm before touching it; otherwise ask, same as a first install.
    local parent existing
    if existing=$(find_existing_install "$gen"); then
        parent=$(dirname "$existing")
        echo
        say "Found an existing generation $gen install: $existing"
        if [ "$(ask 'Update it? (Y/N) [Y]' Y)" != Y ]; then
            say 'Cancelled - nothing was installed or changed.'
            exit 0
        fi
    else
        say 'A folder chooser is opening. Pick the PARENT folder; the release folder (e.g. Java25) is created inside it.'
        parent=$(choose_folder "$DEFAULT_PARENT" 'Choose the PARENT folder for AGL')
        if [ -z "$parent" ]; then say 'Cancelled - nothing was installed.'; exit 1; fi
        mkdir -p "$parent"
    fi
    local version_path="$parent/$release_dir"
    local is_update=0; [ -d "$version_path" ] && is_update=1

    # 3. Downloads folder
    local downloads; downloads=$(downloads_dir)
    echo
    say "  Install folder : $version_path"
    say "  Zips saved to  : $downloads"
    echo

    # 4. App zip
    local zip_file; zip_file=$(get_or_download "$url" "$name" "$downloads" "$release_dir")

    # 4b. Is this exact release already installed here?
    local jar_name=${name%.zip}.jar
    if [ "$is_update" = 1 ] && same_app_release "$zip_file" "$release_dir" "$jar_name" "$version_path"; then
        echo
        warn "AGL $version is already installed in $version_path."
        if [ "$(ask 'Continue and reinstall anyway? (Y/N) [N]' N)" != Y ]; then
            say 'Nothing was changed. (The download is still in your Downloads folder.)'
            exit 0
        fi
    fi

    # 5. Extract the app zip and clear any pre-split-model leftovers
    say 'Extracting...'
    extract_zip "$zip_file" "$parent" "$release_dir" || fail "Could not extract $name into $parent."
    [ -d "$version_path" ] || fail "Extraction finished but '$release_dir' was not created."
    fix_files "$version_path"
    remove_leftovers "$version_path"
    if [ "${#REMOVED[@]}" -gt 0 ]; then say "Removed other-OS items from an earlier install: ${REMOVED[*]}"; fi

    # 6. Linux JRE - only if missing
    echo
    if jre_out=$(runtime_asset 'jre25-linux' 'linux_jre25.zip'); then
        { read -r jre_tag; read -r jre_name; read -r jre_url; read -r jre_size; } <<< "$jre_out"
        install_if_missing "$jre_url" "$jre_name" 'linux_jre25' "$version_path" "$downloads"
    else
        warn 'WARNING: no linux_jre25 runtime release was found.'
    fi

    # 7. Library jars - always refreshed
    if lib_out=$(runtime_asset 'lib25' 'agl25_lib.zip'); then
        { read -r lib_tag; read -r lib_name; read -r lib_url; read -r lib_size; } <<< "$lib_out"
        install_lib_always "$lib_url" "$lib_name" 'agl25_lib' "$version_path" "$downloads"
    else
        warn 'WARNING: no agl25_lib runtime release was found.'
    fi

    # 7b. Fix Java permissions / quarantine stale lib jars - needs the JRE and lib jars from
    # steps 6 and 7 to actually be there first, or its own "is the runtime present" check fails.
    if [ -f "$version_path/$SETUP_SCRIPT" ]; then
        (cd "$version_path" && bash "./$SETUP_SCRIPT")
    fi
    # install_AGL_linux.sh rewrites AGL_start.sh via mktemp+mv while picking the jar, which
    # replaces its executable bit with mktemp's default (not executable) - put it back.
    fix_files "$version_path"

    # 8. Map tiles named by AGL_start.sh - downloaded only when that folder is missing
    local tiles_ok=1 tile_name
    tile_name=$(tile_name_from_start_script "$version_path/$START_SCRIPT" || true)
    if [ -n "$tile_name" ]; then
        echo
        if ! install_tiles "$version_path" "$tile_name" "$downloads"; then tiles_ok=0; fi
    else
        say "$START_SCRIPT names no map tile folder - map tile step skipped."
    fi

    # 9. Desktop icon
    update_shortcut "$version_path" "$gen"

    echo
    if [ "$tiles_ok" = 0 ]; then
        warn "WARNING: the map tiles ($tile_name) are not installed, so AGL will have no maps yet. Run this installer again to retry."
    fi
    if [ "$is_update" = 1 ]; then printf '%sUpdate complete.%s\n' "$G" "$N"; else printf '%sInstall complete.%s\n' "$G" "$N"; fi
    say "AGL is in $version_path"
    pause_exit 0
}

main
