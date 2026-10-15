<div align="center">

<img src="https://raw.githubusercontent.com/qualitydll/brew-client-/main/brewbanner.png" alt="brew. — баннер проекта" width="100%" />

# Brew

<a href="README.md"><img alt="Русский" src="https://img.shields.io/badge/🇷🇺_Русский-1E1410?style=for-the-badge&labelColor=1E1410" /></a>
<a href="README.en.md"><img alt="English" src="https://img.shields.io/badge/🇬🇧_English-D97736?style=for-the-badge&labelColor=1E1410" /></a>

На базе [Flutter](https://flutter.dev) и [Mihomo](https://github.com/MetaCubeX/mihomo).

<p>
  <a href="https://github.com/qualitydll/brew-client-/actions/workflows/build.yml"><img alt="Сборка" src="https://img.shields.io/github/actions/workflow/status/qualitydll/brew-client-/build.yml?branch=experiment-lab-diagnostics&style=flat-square&label=build" /></a>
  <img alt="Платформы" src="https://img.shields.io/badge/platforms-Windows%20%7C%20Android-D97736?style=flat-square" />
  <img alt="Flutter" src="https://img.shields.io/badge/made%20with-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" />
</p>

**Тёмный кофейный фон · фирменный оранжевый · никаких лишних сложностей**

</div>

---

## ✦ О проекте

**brew.** — компактный VPN-клиент с собственным визуальным стилем, управлением профилями и серверами. Flutter отвечает за интерфейс, а Mihomo — за сетевую часть.

Цель проекта — сделать подключение понятным, настройки доступными, а интерфейс аккуратным и быстрым.

> Проект активно развивается. Возможности и стабильность отдельных функций могут меняться.

## Возможности

<table>
<tr>
<td width="50%" valign="top">

### ◉ Подключение
- Системный VPN на Android
- Системный прокси и режим TUN там, где поддерживаются
- Маршрутизация: умный режим, весь трафик или напрямую
- Активные соединения и журнал ядра

</td>
<td width="50%" valign="top">

### ◈ Профили и серверы
- Импорт подписок по URL
- Поддерживаемые ссылки и конфигурации Mihomo/Clash YAML
- Список серверов и проверка задержки
- Выбор узла и автоматические группы
- Квота и срок подписки, если их передаёт провайдер

</td>
</tr>
<tr>
<td width="50%" valign="top">

### ◐ Внешний вид
- Светлая и тёмная темы
- Оранжевый акцент по умолчанию
- Настройка цвета интерфейса
- Минималистичный интерфейс Flutter / Material

</td>
<td width="50%" valign="top">

### ⚙ Дополнительные инструменты
- Пользовательские правила маршрутизации
- Experiment Lab для диагностики
- Настройки Mihomo
- Пропуск отдельных неподдерживаемых узлов без удаления всего профиля

</td>
</tr>
</table>

## Платформы

| Платформа | Сборка | Примечание |
|---|---|---|
| **Windows** | GitHub Actions | В готовый артефакт включается Mihomo для Windows |
| **Android** | GitHub Actions | Текущий APK предназначен для ARM64 (arm64-v8a) |
| macOS / Linux | Не заявлены как готовые релизы | Доступность сборки зависит от текущего состояния проекта |

Успешная сборка CI подтверждает прохождение настроенных проверок и компиляции, но не заменяет тестирование на реальном устройстве и не гарантирует совместимость с каждым провайдером.

## Скачать сборку

1. Откройте [GitHub Actions](https://github.com/qualitydll/brew-client-/actions/workflows/build.yml).
2. Выберите успешный запуск.
3. Найдите раздел **Artifacts** внизу страницы.
4. Скачайте <code>android-release-arm64</code> для Android или <code>windows-release</code> для Windows.

Если артефактов нет, проверьте, что запуск завершился успешно.

## Установка и запуск

### Android

1. Скачайте APK из артефактов успешной сборки.
2. Установите его на совместимое 64-битное ARM-устройство.
3. Откройте brew. и добавьте ссылку на VPN-подписку.
4. Нажмите подключение и подтвердите системный запрос Android на создание VPN-соединения.

Android-версия использует встроенное ядро Mihomo и системный <code>VpnService</code>. В текущей конфигурации sing-box не является встроенным ядром.

### Windows

Готовый артефакт GitHub Actions уже включает Mihomo в папку <code>core</code>.

Для локальной сборки установите [Flutter](https://docs.flutter.dev/get-started/install) и Visual Studio 2022 с компонентом **Desktop development with C++**, затем выполните в корне проекта:

<pre><code>flutter pub get
flutter build windows --release</code></pre>

Результат появится в <code>build\windows\x64\runner\Release\</code>. Для режима TUN может потребоваться запуск от имени администратора.

## Поддерживаемые форматы

Отдельные ссылки могут включать VLESS, VMess, Trojan, Shadowsocks, Hysteria2, TUIC и AnyTLS. Набор параметров зависит от ссылки и возможностей встроенного ядра.

Полные конфигурации Mihomo/Clash YAML могут содержать группы серверов, правила маршрутизации, DNS и провайдеры правил. Поддержка конкретных форматов зависит от текущей реализации. Новые форматы, включая ShadowQUIC, требуют проверки совместимости с версией ядра и форматом ссылки.

## Разработка

Нужны Flutter stable и инструменты для целевой платформы.

<pre><code>flutter pub get
flutter analyze
flutter test
flutter run -d windows</code></pre>

### Структура проекта

| Папка | Назначение |
|---|---|
| <code>lib/core</code> | Mihomo, API, конфигурации и разбор ссылок |
| <code>lib/state</code> | Состояние приложения, профили и настройки |
| <code>lib/ui</code> | Экраны, тема и компоненты интерфейса |
| <code>.github/workflows</code> | Автоматическая сборка Windows и Android |

## Важные замечания

- Не публикуйте личные ссылки на подписки, пароли и другие секреты в публичных issues.
- Удаляйте приватные ключи и учётные данные перед отправкой логов и конфигураций.
- Результат проверки задержки зависит от тестового адреса и доступности сети. Неудачный тест сам по себе не доказывает, что VPN-туннель не работает.
- Перед стабильным релизом проверяйте приложение на своих устройствах и используйте только серверы, к которым у вас есть разрешённый доступ.

## Участие в проекте

Нашли ошибку или хотите предложить улучшение? Создайте [Issue](https://github.com/qualitydll/brew-client-/issues). Укажите платформу, шаги воспроизведения и текст ошибки, предварительно удалив персональные данные и секреты.

---

<div align="center">

**brew. — меньше шума. больше связи.**

<a href="README.en.md">Read this README in English →</a>

</div>
