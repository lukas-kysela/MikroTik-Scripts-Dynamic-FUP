# D-FUP RouterOS 7 v1.1

D-FUP je dynamický QoS/FUP balík pro MikroTik RouterOS 7. Řídí IPv4 provoz přes vybraný WAN interface pomocí `mangle`, `queue tree` a `PCQ`. Cíl je férovější rozdělení linky mezi klienty a omezení velkých TCP/QUIC přenosů ve chvíli, kdy je WAN vytížená.

Autor: **Lukáš Kysela**  
Kontakt: **developer@lukaskysela.cz**  
Web: **https://www.lukaskysela.cz**

## Co balík dělá

- férově dělí běžný provoz mezi klienty přes PCQ,
- zvýhodňuje citlivé UDP porty `53,123,500,4500,51820`,
- zařazuje velký QUIC/HTTP3 provoz přes UDP/443 do bulk třídy až po překročení nastaveného objemu,
- zařazuje větší TCP spojení do `medium` a `heavy` tříd podle `connection-bytes`,
- průběžně měří zatížení WAN a přepíná 3 úrovně omezení,
- upozorňuje na aktivní FastTrack,
- obsahuje čistý uninstall.

## Soubory

| Soubor | Účel |
| --- | --- |
| `D-FUP-Install-AllInOne.rsc` | Doporučený instalátor. Obsahuje vše v jednom souboru. |
| `D-FUP-Install-Modular.rsc` | Modulární instalátor. Vyžaduje samostatný `D-FUP-Processor.rsc` ve Files. |
| `D-FUP-Processor.rsc` | Skript spouštěný schedulerem. Dynamicky mění limity front. |
| `D-FUP-Uninstall.rsc` | Odinstalace D-FUP objektů. |
| `VERSION.txt` | Verze balíku. |
| `CHANGELOG.md` | Přehled změn. |

## Doporučená instalace

Nejdřív udělej export a backup konfigurace:

```routeros
/export file=before-dfup
/system backup save name=before-dfup
```

Nahraj `D-FUP-Install-AllInOne.rsc` do RouterOS Files. Před importem uprav v horní části souboru hlavně tyto hodnoty:

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
/import file-name=D-FUP-Install-AllInOne.rsc
```

## Kontrola po instalaci

```routeros
/system scheduler print where name="D-FUP-Processor"
/system script print where name="D-FUP-Processor"
/queue tree print where name~"D-FUP"
/queue type print where name~"D-FUP"
/ip firewall mangle print where comment~"D-FUP"
/log print where message~"D-FUP"
```

## Odinstalace

Nahraj `D-FUP-Uninstall.rsc` do RouterOS Files a spusť:

```routeros
/import file-name=D-FUP-Uninstall.rsc
```

## FastTrack

D-FUP používá Queue Tree s `parent=global`. Pokud je na routeru aktivní FastTrack, část provozu může shaping obejít. Balík FastTrack automaticky nevypíná, pokud není výslovně nastaveno:

```routeros
:global dfupCfgAutoDisableFastTrack true;
```

Výchozí bezpečné nastavení je `false`, tedy pouze varování v logu.

## Omezení

- Verze v1.1 řeší IPv4 forwardovaný provoz.
- IPv6 není zahrnuté.
- Skript neprovádí Layer7 detekci aplikací.
- Skript neblokuje QUIC, pouze ho zařazuje do bulk třídy podle objemu spojení.

## Doporučení pro GitHub

Repozitář může mít jednoduchou strukturu:

```text
D-FUP-RouterOS-7/
├── D-FUP-Install-AllInOne.rsc
├── D-FUP-Install-Modular.rsc
├── D-FUP-Processor.rsc
├── D-FUP-Uninstall.rsc
├── README.md
├── CHANGELOG.md
├── VERSION.txt
└── .gitattributes
```

Pro RouterOS skripty je vhodné zachovat CRLF konce řádků. Soubor `.gitattributes` je v balíku nastaven tak, aby `.rsc` soubory zůstaly jako text s CRLF.
