#!/usr/bin/env bash
# AGL clean-up - Linux
#
# Puts this Linux account back to "AGL was never installed" FOR ONE GENERATION - the one
# AGL_GEN is set to right now (normally the current release) - so the next install starts
# from scratch. Other generations' settings, preferences, icons and installs are left alone. It removes what the installer, the setup script and the launcher leave
# behind:
#   - the export lines in your shell profile (.zshrc / .bash_profile / .bashrc / .profile;
#     each file is backed up first)
#   - ~/.config/environment.d/agl*.conf (the desktop-session copy of those settings)
#   - the launcher's saved preferences (~/.agl<gen>_launcher.properties)
#   - the Desktop icons (AGL<gen>.desktop)
#   - the files the installer saved in Downloads (zips, map zips, log file)
#   - leftover temporary files
#   - the install folder itself (Java25), if it really is an AGL install and not running
#
# It NEVER touches your races folder (AGL<gen>_Race_Dir) - it only tells you where it is.
# It shows everything first and does nothing until you type YES.
#
# Run it with:   bash agl-clean-linux.sh            (add --dry-run to only look)

set -uo pipefail

# ======================= SETTINGS =======================
# GENERATION           the generation to clean. '' = the one AGL_GEN is set to right now.
#                      ONLY this generation is cleaned: other generations' settings,
#                      preferences, icons and installs are left alone.
# FALLBACK_GENERATION  used when GENERATION is '' and AGL_GEN is not set (any more)
# DOWNLOAD_NAMES       files the installers save in Downloads (maps_*.zip are always included)
GENERATION=''
FALLBACK_GENERATION=25
DOWNLOAD_NAMES=(AGL_latest_full.zip AGL_latest_patch.zip APL_patch.zip AGL_download_debug.txt)
# ========================================================

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

if [ -t 1 ]; then Y=$'\033[33m'; R=$'\033[31m'; G=$'\033[32m'; C=$'\033[36m'; N=$'\033[0m'; else Y=''; R=''; G=''; C=''; N=''; fi
say()  { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$Y" "$*" "$N"; }
bad()  { printf '%s%s%s\n' "$R" "$*" "$N"; }

PROFILES=(.zshrc .bash_profile .bashrc .profile)

download_dirs() {
    local d=''
    if command -v xdg-user-dir >/dev/null 2>&1; then d=$(xdg-user-dir DOWNLOAD 2>/dev/null || true); fi
    if [ -n "$d" ] && [ "$d" != "$HOME" ]; then printf '%s\n' "$d"; fi
    printf '%s\n' "$HOME/Downloads"
}
desktop_dirs() {
    local d=''
    if command -v xdg-user-dir >/dev/null 2>&1; then d=$(xdg-user-dir DESKTOP 2>/dev/null || true); fi
    if [ -n "$d" ] && [ "$d" != "$HOME" ]; then printf '%s\n' "$d"; fi
    printf '%s\n' "$HOME/Desktop"
}
# The "Path=" line of an existing .desktop file, or nothing if it cannot be read - the same
# lookup the new installer uses to find an install with no environment variable set.
shortcut_work_dir() {
    [ -f "$1" ] || return 1
    sed -n -E 's/^Path=(.+)$/\1/p' "$1" | head -n 1
}
is_download_name() {
    local n=$1 k base
    base=${n%.part}
    for k in "${DOWNLOAD_NAMES[@]}"; do if [ "$base" = "$k" ]; then return 0; fi; done
    case "$base" in maps_*.zip) return 0 ;; esac
    return 1
}

# Value of  export NAME="value"  (profile files), NAME=value (environment.d) or the environment
values_of() {   # values_of NAME_REGEX -> one value per line
    local f
    for f in "${PROFILES[@]}"; do
        [ -f "$HOME/$f" ] || continue
        grep -E "^[[:space:]]*export[[:space:]]+$1=" "$HOME/$f" 2>/dev/null | sed -E -e 's/^[^=]*=//' -e 's/^"//' -e 's/"[[:space:]]*$//' -e "s/^'//" -e "s/'[[:space:]]*\$//"
    done
    for f in "$HOME"/.config/environment.d/agl*.conf; do
        [ -f "$f" ] || continue
        grep -E "^$1=" "$f" 2>/dev/null | sed -E 's/^[^=]*=//'
    done
    env | grep -E "^$1=" | sed -E 's/^[^=]*=//'
}

# The generation to clean: GENERATION if set, else what AGL_GEN says right now (your shell
# profile files, then the running environment), else the fallback. environment.d is NOT
# consulted: a left-over file for another generation would otherwise pick the wrong one.
TARGET_GEN=''; TARGET_SRC=''
choose_generation() {
    local v f
    if [ -n "$GENERATION" ]; then TARGET_GEN=$GENERATION; TARGET_SRC='set in this script'; return; fi
    for f in "${PROFILES[@]}"; do
        [ -f "$HOME/$f" ] || continue
        v=$(grep -E "^[[:space:]]*export[[:space:]]+AGL_GEN=" "$HOME/$f" 2>/dev/null | tail -n 1 | sed -E -e 's/^[^=]*=//' -e 's/[^0-9]//g')
        if [ -n "$v" ]; then TARGET_GEN=$v; TARGET_SRC="AGL_GEN in ~/$f"; return; fi
    done
    v=$(printf '%s' "${AGL_GEN:-}" | sed -E 's/[^0-9]//g')
    if [ -n "$v" ]; then TARGET_GEN=$v; TARGET_SRC='AGL_GEN in the running environment'; return; fi
    TARGET_GEN=$FALLBACK_GENERATION; TARGET_SRC='AGL_GEN is not set - using the default'
}
choose_generation
GEN_RE="$TARGET_GEN"
VAR_RE="(AGL_GEN|AGL_PREV_GEN|AG${GEN_RE}[A-Za-z]+|AGL${GEN_RE}_Race_Dir)"

# Why this folder must NOT be deleted (prints nothing when it is safe to delete)
install_problem() {
    local d=$1 real depth
    if [ ! -d "$d" ]; then echo 'not a folder (already gone?)'; return; fi
    real=$(cd -P -- "$d" 2>/dev/null && pwd -P) || { echo 'cannot open it'; return; }
    case "$real" in
        /|"$HOME"|"$HOME/Desktop"|"$HOME/Downloads"|"$HOME/Documents") echo 'that is a system or personal folder'; return ;;
    esac
    case "$HOME/" in "$real"/*) echo 'it contains your home folder'; return ;; esac
    depth=$(printf '%s' "$real" | tr -cd '/' | wc -c | tr -d ' ')
    if [ "$depth" -lt 2 ]; then echo 'too close to the top of the disk'; return; fi
    if [ ! -f "$real/agl_launcher.jar" ] && [ ! -f "$real/install_AGL_linux.sh" ] && [ -z "$(ls -d "$real"/agl*_lib 2>/dev/null | head -n 1)" ]; then
        echo 'it does not look like an AGL install (no agl_launcher.jar / install script / agl*_lib)'; return
    fi
    if command -v pgrep >/dev/null 2>&1 && pgrep -f -- "$real/" >/dev/null 2>&1; then
        echo 'AGL seems to be running from it - close it first'; return
    fi
}

# ---------------------------------------------------------------- scan
PROFILE_HITS=(); ENVD_FILES=(); PREF_FILES=(); ICON_FILES=(); DL_FILES=(); TEMP_ITEMS=()
INSTALL_DIRS=(); INSTALL_OK=(); INSTALL_WHY=()
VAR_NAMES=(); RACE_DIRS=(); SHORTCUT_DIRS=()

scan() {
    local f n g d dir line real why
    PROFILE_HITS=(); ENVD_FILES=(); PREF_FILES=(); ICON_FILES=(); DL_FILES=(); TEMP_ITEMS=()
    INSTALL_DIRS=(); INSTALL_OK=(); INSTALL_WHY=(); VAR_NAMES=(); RACE_DIRS=(); SHORTCUT_DIRS=()

    for f in "${PROFILES[@]}"; do
        [ -f "$HOME/$f" ] || continue
        n=$(grep -cE "^[[:space:]]*export[[:space:]]+${VAR_RE}=" "$HOME/$f" 2>/dev/null || true)
        if [ "${n:-0}" -gt 0 ]; then
            PROFILE_HITS+=("$HOME/$f|$n")
            while IFS= read -r line; do VAR_NAMES+=("$line"); done < <(grep -E "^[[:space:]]*export[[:space:]]+${VAR_RE}=" "$HOME/$f" | sed -E 's/^[[:space:]]*export[[:space:]]+([A-Za-z0-9_]+)=.*/\1/')
        fi
    done
    for f in "$HOME"/.config/environment.d/agl*.conf; do
        [ -f "$f" ] || continue
        g=$(basename "$f" | sed -n -E 's/^agl([0-9]+)\.conf$/\1/p')
        [ -n "$g" ] || continue
        if [ "$g" = "$TARGET_GEN" ]; then ENVD_FILES+=("$f"); fi
    done
    for f in "$HOME"/.agl*_launcher.properties; do
        [ -f "$f" ] || continue
        g=$(basename "$f" | sed -n -E 's/^\.agl([0-9]+)_launcher\.properties$/\1/p')
        [ -n "$g" ] || continue
        if [ "$g" = "$TARGET_GEN" ]; then PREF_FILES+=("$f"); fi
    done
    while IFS= read -r d; do
        for f in "$d"/AGL*.desktop; do
            [ -f "$f" ] || continue
            g=$(basename "$f" | sed -n -E 's/^AGL([0-9]+)\.desktop$/\1/p')
            [ -n "$g" ] || continue
            if [ "$g" = "$TARGET_GEN" ]; then
                ICON_FILES+=("$f")
                # No environment variable points at the install any more - the new installer
                # and AGL_shortcut.sh both find it through this same shortcut, so this is how
                # the cleaner finds it too.
                dir=$(shortcut_work_dir "$f" || true)
                [ -n "$dir" ] && SHORTCUT_DIRS+=("$dir")
            fi
        done
    done < <(desktop_dirs | sort -u)
    while IFS= read -r d; do
        [ -d "$d" ] || continue
        for f in "$d"/*; do
            [ -f "$f" ] || continue
            if is_download_name "$(basename "$f")"; then DL_FILES+=("$f"); fi
        done
    done < <(download_dirs | sort -u)
    for f in "${TMPDIR:-/tmp}"/agl_patch.* "${TMPDIR:-/tmp}"/agl_cookies.* "${TMPDIR:-/tmp}"/agl_prof.* "${TMPDIR:-/tmp}"/agl_fix.*; do
        [ -e "$f" ] && TEMP_ITEMS+=("$f")
    done

    # install folders: every AG<gen>InstallDir we can find, every install a matching Desktop
    # icon points at, plus one typed by the user
    while IFS= read -r d; do
        [ -n "$d" ] || continue
        INSTALL_DIRS+=("$d")
    done < <( { values_of "AG${GEN_RE}InstallDir"; printf '%s\n' "${SHORTCUT_DIRS[@]+"${SHORTCUT_DIRS[@]}"}"; [ -n "${EXTRA_INSTALL:-}" ] && printf '%s\n' "$EXTRA_INSTALL"; } | sort -u)
    for d in ${INSTALL_DIRS[@]+"${INSTALL_DIRS[@]}"}; do
        [ -d "$d" ] || continue          # already gone: nothing to remove or report
        why=$(install_problem "$d")
        if [ -z "$why" ]; then INSTALL_OK+=("$d"); else INSTALL_WHY+=("$d|$why"); fi
    done
    while IFS= read -r d; do [ -n "$d" ] && RACE_DIRS+=("$d"); done < <( { values_of "AGL${GEN_RE}_Race_Dir"; for f in "${PREF_FILES[@]+"${PREF_FILES[@]}"}"; do sed -n -E 's/^AGL[0-9]+_Race_Dir=//p' "$f" | sed -e 's/\\:/:/g' -e 's/\\\\/\\/g'; done; } | sort -u)
}

show_plan() {
    local x
    say
    say "${C}What will be removed${N}"
    if [ "${#PROFILE_HITS[@]}" -gt 0 ]; then
        for x in "${PROFILE_HITS[@]}"; do say "  shell profile lines : ${x#*|} line(s) in ${x%|*}   (a backup copy is kept)"; done
    fi
    if [ "${#ENVD_FILES[@]}" -gt 0 ]; then for x in "${ENVD_FILES[@]}"; do say "  session settings    : $x"; done; fi
    if [ "${#PREF_FILES[@]}" -gt 0 ]; then for x in "${PREF_FILES[@]}"; do say "  launcher preferences: $x"; done; fi
    if [ "${#ICON_FILES[@]}" -gt 0 ]; then for x in "${ICON_FILES[@]}"; do say "  Desktop icon        : $x"; done; fi
    if [ "${#DL_FILES[@]}" -gt 0 ]; then for x in "${DL_FILES[@]}"; do say "  saved download      : $x"; done; fi
    if [ "${#TEMP_ITEMS[@]}" -gt 0 ]; then for x in "${TEMP_ITEMS[@]}"; do say "  temporary file      : $x"; done; fi
    if [ "${#INSTALL_OK[@]}" -gt 0 ]; then for x in "${INSTALL_OK[@]}"; do say "  INSTALL FOLDER      : $x   (everything inside, including maps)"; done; fi
    if [ "${#INSTALL_WHY[@]}" -gt 0 ]; then
        say
        for x in "${INSTALL_WHY[@]}"; do warn "  NOT removing folder : ${x%%|*}  - ${x#*|}"; done
    fi
    if [ "${#VAR_NAMES[@]}" -gt 0 ]; then
        say
        say "  variables that go with those lines: $(printf '%s\n' "${VAR_NAMES[@]}" | sort -u | tr '\n' ' ')"
    fi
    if [ "${#RACE_DIRS[@]}" -gt 0 ]; then
        say
        for x in "${RACE_DIRS[@]}"; do say "${G}  NOT touched - your races folder: $x${N}"; done
    fi
}

count_items() {
    echo $(( ${#PROFILE_HITS[@]} + ${#ENVD_FILES[@]} + ${#PREF_FILES[@]} + ${#ICON_FILES[@]} + ${#DL_FILES[@]} + ${#TEMP_ITEMS[@]} + ${#INSTALL_OK[@]} ))
}

# ---------------------------------------------------------------- main
echo
printf '%sAGL clean-up (Linux)%s\n' "$C" "$N"
say 'Puts this account back to "AGL was never installed". Your races folder is never touched.'
say "Scope: generation $TARGET_GEN only ($TARGET_SRC). Other generations are left alone."
if [ "$TARGET_GEN" != "$FALLBACK_GENERATION" ]; then
    warn "Note: this is not the usual generation ($FALLBACK_GENERATION). Set GENERATION at the top of this script to override."
fi

EXTRA_INSTALL=''
scan
show_plan

read -r -p $'\nAnother AGL install folder to remove (full path), or press Enter for none: ' EXTRA_INSTALL || true
if [ -n "$EXTRA_INSTALL" ]; then
    EXTRA_INSTALL=${EXTRA_INSTALL/#\~/$HOME}; if [ "$EXTRA_INSTALL" != / ]; then EXTRA_INSTALL=${EXTRA_INSTALL%/}; fi
    if [ ! -d "$EXTRA_INSTALL" ]; then warn "Not found, ignored: $EXTRA_INSTALL"; EXTRA_INSTALL=''; fi
    scan; show_plan
fi

TOTAL=$(count_items)
if [ "$TOTAL" = 0 ]; then
    echo; printf '%sNothing to remove - this account already looks like a fresh one.%s\n' "$G" "$N"; exit 0
fi
if [ "$DRY_RUN" = 1 ]; then echo; say '(--dry-run: nothing was changed)'; exit 0; fi

REFUSED=()
if [ "${#INSTALL_WHY[@]}" -gt 0 ]; then REFUSED=("${INSTALL_WHY[@]}"); fi
read -r -p $'\nType YES to remove everything listed above: ' ANSWER || true
case "$ANSWER" in YES|yes|Yes) ;; *) echo; say 'Nothing was changed.'; exit 0 ;; esac

echo
FAILED=0
STAMP=$(date +%Y%m%d-%H%M%S)

# 1. shell profile lines (backup first)
if [ "${#PROFILE_HITS[@]}" -gt 0 ]; then
    for x in "${PROFILE_HITS[@]}"; do
        f=${x%|*}
        cp -p "$f" "$f.agl-clean-$STAMP.bak" || { bad "could not back up $f - left it alone"; FAILED=$((FAILED+1)); continue; }
        tmp=$(mktemp "${TMPDIR:-/tmp}/agl_clean.XXXXXX")
        grep -vE "^[[:space:]]*export[[:space:]]+${VAR_RE}=" "$f" > "$tmp"
        if cat "$tmp" > "$f"; then say "cleaned $f  (backup: $f.agl-clean-$STAMP.bak)"; else bad "could not rewrite $f"; FAILED=$((FAILED+1)); fi
        rm -f "$tmp"
    done
fi
# 2. files
for f in ${ENVD_FILES[@]+"${ENVD_FILES[@]}"} ${PREF_FILES[@]+"${PREF_FILES[@]}"} ${ICON_FILES[@]+"${ICON_FILES[@]}"} ${DL_FILES[@]+"${DL_FILES[@]}"}; do
    if rm -f -- "$f"; then say "removed $f"; else bad "could not remove $f"; FAILED=$((FAILED+1)); fi
done
for f in ${TEMP_ITEMS[@]+"${TEMP_ITEMS[@]}"}; do rm -rf -- "$f" 2>/dev/null; done
# 3. the running desktop session still holds the old values: ask systemd to forget them
if command -v systemctl >/dev/null 2>&1 && [ "${#VAR_NAMES[@]}" -gt 0 ]; then
    systemctl --user unset-environment $(printf '%s\n' "${VAR_NAMES[@]}" | sort -u | tr '\n' ' ') >/dev/null 2>&1 || true
fi
# 4. install folders
for d in ${INSTALL_OK[@]+"${INSTALL_OK[@]}"}; do
    say "removing $d (this can take a while - it holds many map tiles) ..."
    rm -rf -- "$d"
    if [ -e "$d" ]; then bad "could not remove all of $d"; FAILED=$((FAILED+1)); else say "removed $d"; fi
done

# ---------------------------------------------------------------- verify
EXTRA_INSTALL=${EXTRA_INSTALL:-}
scan
LEFT=$(count_items)
echo
if [ "$LEFT" = 0 ] && [ "$FAILED" = 0 ]; then
    if [ "${#REFUSED[@]}" -eq 0 ]; then
        printf '%sClean. Nothing AGL-related is left in this account.%s\n' "$G" "$N"
    else
        printf '%sClean, except for the folders left in place on purpose:%s\n' "$Y" "$N"
    fi
else
    warn "Finished with $FAILED problem(s); $LEFT item(s) still listed:"
    show_plan
fi
if [ "${#REFUSED[@]}" -gt 0 ]; then
    for x in "${REFUSED[@]}"; do warn "  left in place: ${x%%|*}  - ${x#*|}"; done
fi
say
say 'To finish: log out and back in (or reboot) so the desktop session forgets the old settings, and open a NEW terminal.'
say 'Then run agl-install-linux.sh for the clean install.'
exit 0
