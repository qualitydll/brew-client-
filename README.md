# brew.

VPN-клиент на базе ядра [mihomo](https://github.com/MetaCubeX/mihomo) с дизайном Material You.
Flutter: Windows — первая платформа, дальше Android, macOS и Linux.

## Возможности

- подписки: URL, Clash/mihomo YAML, base64, ссылки `vless`, `vmess`, `trojan`, `ss`, `hysteria2`/`hy2`, `tuic`;
- трафик и срок подписки (`subscription-userinfo`), обновление профилей;
- серверы с пингом, кнопка «Самый быстрый», автовыбор (`AUTO`);
- режимы: Умный (rule), Весь трафик (global), Напрямую (direct);
- системный прокси и TUN;
- автозапуск Windows со сворачиванием на панель задач;
- живой график скорости и журнал ядра;
- Material You: фирменный оранжевый по умолчанию, свой цвет или системный акцент, светлая и тёмная темы;
- если ядро не принимает отдельный сервер из подписки, он пропускается, остальные работают.

## Сборка под Windows

Нужны [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) (stable, 3.47+)
и Visual Studio 2022 с компонентом «Desktop development with C++».

```powershell
flutter pub get
flutter build windows --release
```

Готовая программа — в `build\windows\x64\runner\Release\`.

GitHub Actions проверяет разбор маршрутизации, собирает Windows-версию и упаковывает
её вместе с `core\\mihomo.exe` в артефакт `brew-windows-x64`.

### Ядро mihomo

Скачайте `mihomo-windows-amd64-*.zip` со страницы
[релизов mihomo](https://github.com/MetaCubeX/mihomo/releases), распакуйте и переименуйте файл в `mihomo.exe`.
brew ищет ядро в таком порядке:

1. путь, указанный в настройках;
2. переменная окружения `BREW_CORE`;
3. `core\mihomo.exe` рядом с `brew.exe`;
4. `mihomo.exe` рядом с `brew.exe`;
5. папка данных приложения `core\mihomo.exe`;
6. `mihomo` в `PATH`.

Проще всего положить его в `Release\core\mihomo.exe`.

Для TUN программу нужно запускать от имени администратора.

## Разработка

```bash
flutter analyze
flutter test
flutter run -d windows   # или -d linux
```

`BREW_NO_ANIM=all` (или `aurora,orb,chart`) отключает фоновые анимации — удобно для замеров.

## Структура

- `lib/core` — ядро: процесс mihomo, REST API, генерация конфига, разбор ссылок, системный прокси;
- `lib/state` — состояние приложения, профили, настройки;
- `lib/ui` — тема, экраны и анимированные виджеты;
- `lib/brand.dart` — название, фирменные цвета и шрифт.

Шрифты — DM Sans и Onest для кириллицы (SIL OFL 1.1, `assets/fonts/OFL-*.txt`).
