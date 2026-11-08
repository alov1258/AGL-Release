# Downloads

The AGL installers. Pick your system, then the channel. **Production** is the released version. **Beta** is a pre-release that may contain bugs; it installs beside Production, in its own Java25Beta folder, so you can keep both. The same installer also updates an existing install.

How to run them is in [Installing and Upgrading AGL 25](manual/0200-installing-agl.md#21-installing-and-upgrading-agl-25). Every file is also on the [Releases page](https://github.com/alov1258/AGL-Release/releases).

## Windows

### Production

[agl-install-windows.bat](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-windows.bat) - the latest released version. Steps: [Windows](manual/0200-installing-agl.md#211-windows).

### Beta

[agl-install-windows-beta.bat](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-windows-beta.bat) - the latest beta.

## Linux

### Production

[agl-install-linux.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-linux.sh) - the latest released version. Steps: [Linux](manual/0200-installing-agl.md#213-linux).

### Beta

[agl-install-linux-beta.sh](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-linux-beta.sh) - the latest beta.

## macOS

### Production

[agl-install-macos.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-install-macos.sh) - the latest released version. Steps: [macOS](manual/0200-installing-agl.md#212-macos).

### Beta

[agl-install-macos-beta.sh](https://github.com/alov1258/AGL-Release/releases/download/beta/agl-install-macos-beta.sh) - the latest beta.

## Rolling back

If a new version gives you trouble, you can go back to the previous released version. The rollback script puts back the jar of an earlier **Production** release and changes nothing else: your races, settings and the other AGL files stay as they are. Save the script in your AGL version folder (the folder that holds `AGL_start.bat` or `AGL_start.sh`, for example `C:\SOL\Java25`), close AGL, and run it. It lists the released versions and offers the one before your newest. The newer jar is kept in a `rolled-back` folder, so you can move it back to undo. AGL will offer the newer version again at its next update check: choose **Remind Me in a Week**.

- [agl-rollback-windows.bat](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-windows.bat) - Windows: double-click it.
- [agl-rollback-linux.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-linux.sh) - Linux: in a terminal, `bash ./agl-rollback-linux.sh`.
- [agl-rollback-macos.sh](https://github.com/alov1258/AGL-Release/releases/latest/download/agl-rollback-macos.sh) - macOS: in Terminal, `bash ./agl-rollback-macos.sh`.
