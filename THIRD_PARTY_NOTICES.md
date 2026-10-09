# Third-party notices

## Brew

Copyright (C) 2026 qualitydll

Brew is licensed under the GNU General Public License, version 3 or (at your
option) any later version. See `LICENSE`.

## libmihomo-android

The Android application currently includes `libmihomo-android` v0.3.7 from
https://github.com/oviron/libmihomo-android/releases/tag/v0.3.7, licensed
under GPL-3.0. The AAR used by the Android build has SHA-256
`e9582440766f7e37f8f6b23344bee35d73e66e7e7a9fc3b90da5631f0fd19f24`.
Corresponding source is available from
https://github.com/oviron/libmihomo-android/tree/v0.3.7.

The Mihomo core project is separately licensed under the MIT License:
https://github.com/MetaCubeX/mihomo.

## sing-box libbox

The Android build generates `libbox.aar` and `libbox-legacy.aar` from the
official sing-box v1.14.3 source under `.build/sing-box/` using the upstream
`cmd/internal/build_libbox` generator. The pinned source is checked out from
https://github.com/SagerNet/sing-box/tree/v1.14.3 and is licensed under
GPL-3.0-or-later. The Android workflow retains the corresponding source as
the `sing-box-source-v1.14.3` artifact alongside the APK.

## Fonts

The DM Sans and Onest font files are licensed under the SIL Open Font License
1.1. The license texts are included in `assets/fonts/OFL-*.txt`.
