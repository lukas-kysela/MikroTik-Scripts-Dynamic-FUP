# Dynamic FUP for MikroTik RouterOS 7

Dynamic FUP je dynamický QoS/FUP balík pro MikroTik RouterOS 7. Řídí IPv4 provoz přes vybraný WAN interface pomocí `mangle`, `queue tree` a `PCQ`. Cíl je férovější rozdělení linky mezi klienty a omezení velkých TCP/QUIC přenosů ve chvíli, kdy je WAN vytížená.

## Co balík dělá

- férově dělí běžný provoz mezi klienty přes PCQ,
- zvýhodňuje citlivé UDP porty `53,123,500,4500,51820`,
- zařazuje velký QUIC/HTTP3 provoz přes UDP/443 do bulk třídy až po překročení nastaveného objemu,
- zařazuje větší TCP spojení do `medium` a `heavy` tříd podle `connection-bytes`,
- průběžně měří zatížení WAN a přepíná 3 úrovně omezení,
- upozorňuje na aktivní FastTrack,
- obsahuje čistý uninstall včetně runtime proměnných.

## Soubory

| Soubor | Účel |
| --- | --- |
| `Dynamic-FUP-Install-AllInOne.rsc` | Doporučený instalátor. Obsahuje vše v jednom souboru. |
| `Dynamic-FUP-Install-Modular.rsc` | Modulární instalátor. Vyžaduje samostatný `Dynamic-FUP-Processor.rsc` ve Files. |
| `Dynamic-FUP-Processor.rsc` | Skript spouštěný schedulerem. Dynamicky mění limity front. |
| `Dynamic-FUP-Uninstall.rsc` | Odinstalace Dynamic FUP objektů. |
| `CHANGELOG.md` | Přehled změn. |
| `.gitattributes` | Nastavení konců řádků pro GitHub/Git. |

## Doporučená instalace

Nejdřív udělej export a backup konfigurace:

```routeros
/export file=before-dynamic-fup
/system backup save name=before-dynamic-fup
```

Nahraj `Dynamic-FUP-Install-AllInOne.rsc` do RouterOS Files. Před importem uprav v horní části souboru hlavně tyto hodnoty:

```routeros
:global dfupCfgWanInterface "ether2";
:global dfupCfgMaxDownMbps 100;
:global dfupCfgMaxUpMbps 20;
:global dfupCfgParentShaperPercent 95;
:global dfupCfgSensitiveUdpPorts "53,123,500,4500,51820";
:global dfupCfgQuicBulkFromMB 10;
:global dfupCfgTcpMediumFromMB 5;
:global dfupCfgTcpHeavyFromMB 25;
:global dfupCfgAvgSamples 12;
:global dfupCfgDebug false;
:global dfupCfgAutoDisableFastTrack false;
:local dfupSchedulerInterval "5s";
```

Import:

```routeros
/import file-name=Dynamic-FUP-Install-AllInOne.rsc
```

## Kontrola po instalaci

```routeros
/system scheduler print where name="Dynamic-FUP-Processor"
/system script print where name="Dynamic-FUP-Processor"
/queue tree print where name~"Dynamic-FUP"
/queue type print where name~"Dynamic-FUP"
/ip firewall mangle print where comment~"Dynamic FUP"
/log print where message~"Dynamic FUP"
```

## Odinstalace

Nahraj `Dynamic-FUP-Uninstall.rsc` do RouterOS Files a spusť:

```routeros
/import file-name=Dynamic-FUP-Uninstall.rsc
```

## FastTrack

Balík FastTrack automaticky nevypíná, pokud `dfupCfgAutoDisableFastTrack=false`. Pokud shaping nebude účinný, zkontroluj FastTrack pravidla. FastTrack může obcházet queue tree s `parent=global`, takže provoz určený pro Dynamic FUP nemá být fasttrackovaný.

## Poznámka k IPv6

Tento balík řeší IPv4. Pokud síť používá IPv6, je potřeba doplnit obdobná pravidla do `/ipv6 firewall mangle`, jinak může IPv6 provoz shaping obejít.
