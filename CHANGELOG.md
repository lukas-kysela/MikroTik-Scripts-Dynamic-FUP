# Changelog

## v1.5 - 2026-06-13

### Přidáno

- GitHub-ready balík projektu **Dynamic FUP**.
- All-in-one instalátor `Dynamic-FUP-Install-AllInOne.rsc`.
- Modulární instalátor `Dynamic-FUP-Install-Modular.rsc`.
- Processor `Dynamic-FUP-Processor.rsc` pro dynamické přepínání limitů podle vytížení WAN.
- Uninstall `Dynamic-FUP-Uninstall.rsc`.
- PCQ fair queue pro běžný download/upload provoz.
- TCP medium/heavy třídy podle `connection-bytes`.
- QUIC/HTTP3 UDP/443 bulk třída podle `connection-bytes`.
- Vyšší priorita pro citlivé UDP porty `53,123,500,4500,51820`.
- Kontrola aktivního FastTracku.
- Cleanup starších RouterOS objektů s původním názvem `D-FUP` při instalaci i odinstalaci.
