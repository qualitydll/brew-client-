<div align="center">

# brew.

**A minimalist VPN client for Windows and Android, with Brew’s own visual identity**

[🇷🇺 Русский](README.md) · [🇬🇧 English](README.en.md)

Powered by [Flutter](https://flutter.dev) and [Mihomo](https://github.com/MetaCubeX/mihomo).

<img src="brewicon.jpg" alt="brew. logo" width="112" />

</div>

---

## About

**brew.** is a compact VPN client with its own visual identity, profile management, and straightforward connection controls. The project uses Flutter for its UI and Mihomo as its networking core.

> brew. is under active development. Features and compatibility may change.

## Features

- **Connectivity:** Android system VPN integration, system proxy and TUN modes where supported.
- **Profiles:** import subscriptions by URL and supported share links or Mihomo/Clash YAML configurations.
- **Servers:** browse nodes, check latency, select a node, or use automatic groups.
- **Routing:** rule-based, global, and direct modes.
- **Diagnostics:** active connections, core logs, and Experiment Lab.
- **Appearance:** light and dark themes, with orange as the default accent.
- **Subscription info:** quota and expiry are shown when supplied by the provider.

## Platforms

| Platform | Current build | Notes |
|---|---|---|
| **Windows** | GitHub Actions | Mihomo for Windows is bundled in the ready artifact |
| **Android** | GitHub Actions | Current APK targets ARM64 (arm64-v8a) |
| macOS / Linux | Not announced as ready releases | Availability depends on the project's current state |

A successful CI build does not replace testing on a real device and does not guarantee compatibility with every VPN provider.

## Download

1. Open [GitHub Actions](https://github.com/qualitydll/brew-client-/actions/workflows/build.yml).
2. Select a successful build run.
3. Find **Artifacts** near the bottom of the run page.
4. Download <code>android-release-arm64</code> or <code>windows-release</code>.

## Android setup

1. Download the APK from a successful workflow artifact.
2. Install it on a compatible 64-bit ARM Android device.
3. Open brew. and add your VPN subscription URL.
4. Tap connect and approve Android's VPN permission prompt.

The current Android build uses the embedded Mihomo core and Android's <code>VpnService</code>. sing-box is not the embedded core in the current project configuration.

## Windows setup

The ready GitHub Actions artifact includes Mihomo in the <code>core</code> directory.

To build locally, install [Flutter](https://docs.flutter.dev/get-started/install) and Visual Studio 2022 with **Desktop development with C++**, then run from the project root:

<pre><code>flutter pub get
flutter build windows --release</code></pre>

Output directory: <code>build\windows\x64\runner\Release\</code>.

TUN mode may require running the app as an administrator.

## Supported formats

Individual links may include VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC, and AnyTLS. Support depends on the link parameters and embedded core. Full Mihomo/Clash YAML configurations can contain proxy groups, routing rules, DNS settings, and rule providers.

Newer formats, including ShadowQUIC, may need compatibility testing against the core version and share-link format.

## Development

Install Flutter stable and the tools required for your target platform.

<pre><code>flutter pub get
flutter analyze
flutter test
flutter run -d windows</code></pre>

### Project structure

| Directory | Purpose |
|---|---|
| <code>lib/core</code> | Mihomo integration, API, configuration, and link parsing |
| <code>lib/state</code> | App state, profiles, and settings |
| <code>lib/ui</code> | Screens, theme, and interface components |
| <code>.github/workflows</code> | Automated Windows and Android builds |

## Security and troubleshooting

- Never post private subscription URLs, passwords, or private keys in public issues.
- Remove credentials and other secrets before sharing logs or configuration files.
- Latency depends on the test endpoint and network access. A failed latency check alone does not prove that the VPN tunnel is broken.
- Test on your own devices and use only servers you are authorized to access.

## Contributing

Found a bug or have an idea? Open an [Issue](https://github.com/qualitydll/brew-client-/issues). Include the platform, reproduction steps, and error message, after removing secrets from logs.

---

<div align="center">

**brew. — less noise. more connection.**

[🇷🇺 Читать на русском](README.md)

</div>
