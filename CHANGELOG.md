# Changelog

## v1.1 - 2026-06-13

### Změněno

- Dokumentace přepsaná pro použití na GitHubu.
- Přidán root `README.md` ve formátu Markdown.
- Přidán root `CHANGELOG.md` ve formátu Markdown.
- Do hlaviček RouterOS skriptů doplněn autor, kontakt a web.
- Balík převerzován na `D-FUP-RouterOS-7-v1.1.zip`.

### Opraveno

- Sjednocené verzování v komentářích skriptů a RouterOS objektech.

## v1.1 - 2026-06-13

### Přidáno

- Kompletní přepis od nuly.
- Pevný verzovací formát `D-FUP-RouterOS-7-vX.Y.zip`.
- All-in-one installer, který vytvoří `/system script D-FUP-Processor`.
- PCQ fair fronta pro výchozí download/upload provoz.
- TCP medium/heavy třídy podle `connection-bytes`.
- QUIC/HTTP3 UDP/443 bulk třída podle `connection-bytes`.
- Citlivé UDP porty s vyšší prioritou.
- Dynamický processor se 3 úrovněmi podle průměrného zatížení WAN.
- Kontrola aktivního FastTracku.
- Bezpečný uninstall včetně globálních proměnných.
