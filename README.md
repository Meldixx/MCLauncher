# MCLauncher v1.0.0

Первый релиз MCLauncher — Minecraft-лаунчера от TrioSoft на базе ElyPrismLauncher/PineconeMC (GPL-3.0-only).

## Что уже добавлено

- единое название и версия `MCLauncher 1.0.0` без Git-канала в заголовке;
- ваше MCLauncher-лого для EXE, ярлыков и установщика;
- бренд `MCLauncher by TrioSoft` и ссылка `https://triosoft.xyz` в интерфейсе;
- кнопка `TrioSoft ID` в верхней панели;
- авторизация TrioSoft ID через безопасный OAuth Device Flow;
- профиль TrioSoft ID, аватар, роль, FREE/PREMIUM и срок Premium;
- refresh token хранится в Windows через DPAPI, а не открытым текстом;
- протокол `mclauncher://` для кнопок «Открыть в MCLauncher» на сайте;
- self-contained Windows-сборка с Qt DLL;
- обычный установщик `MCLauncher-v1.0.0.exe` для пользователей;
- ярлыки, Program Files, деинсталлятор и регистрация протокола;
- собственный Microsoft OAuth Client ID `2400e3a1-2671-4637-846c-3807cc6de2c5`;
- собственный Ely.by Client ID `mclauncher1`;
- CurseForge отключён до получения собственного API key;
- чужие Microsoft/Ely.by/CurseForge/Imgur ключи удалены.

## Сборка

1. Запустить `START.cmd` — он скачает точную GPL-исходную базу upstream и применит MCLauncher/TrioSoft изменения.
2. Запустить `BUILD-WINDOWS.cmd` — он соберёт приложение, Qt runtime и установщик.
3. Готовый файл появится в корне как `MCLauncher-v1.0.0.exe`.

Зависимости: Git, CMake, Ninja, vcpkg, Visual Studio Build Tools 2022 C++, Qt 6 MSVC x64 и JDK 17. Если NSIS не установлен, build-скрипт сам скачает portable NSIS 3.12.

GitHub Actions запускается для pull request в `main`, ручного запуска и тегов `v*`. CI публикует три артефакта: установщик, полный подготовленный corresponding-source архив и воспроизводимый build kit.

## TrioSoft ID

Лаунчер использует Public OAuth Device Flow Client ID `tsc_mclauncher_windows_v100`. Секрет в приложение не вшивается и не нужен. Для серверной стороны используется TrioSoft App Hub 16.5.34+.

## Игровые аккаунты

В релиз 1.0.0 встроены публичные Client ID MCLauncher:

- Microsoft: `2400e3a1-2671-4637-846c-3807cc6de2c5`
- Ely.by: `mclauncher1`

Это публичные идентификаторы desktop OAuth-приложений, не секреты. CurseForge пока отключён; когда будет получен собственный API key, его можно передать через `MCLAUNCHER_CURSEFORGE_API_KEY`.

## Исходная база и GPL

Официальный репозиторий: https://github.com/Meldixx/MCLauncher

MCLauncher 1.0.0 закреплён на ElyPrismLauncher upstream commit `5ea65f7a8057f06382845b870a378e8b35e62559`, чтобы исходная база релиза была воспроизводимой. MCLauncher распространяется по GPL-3.0-only; соответствующий исходный код/набор модификаций должен оставаться доступным рядом с публичными бинарными релизами.
