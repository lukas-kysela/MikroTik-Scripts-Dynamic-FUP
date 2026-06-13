# D-FUP RouterOS 7 v1.1
# Author: Lukáš Kysela
# Contact: developer@lukaskysela.cz
# Website: https://www.lukaskysela.cz
# Target: MikroTik RouterOS 7
# Uninstall script. Removes D-FUP objects and runtime variables.
:log warning "D-FUP: uninstall started";

:foreach i in=[/system scheduler find where name="D-FUP-Processor"] do={ /system scheduler remove $i; }
:foreach i in=[/system script find where name="D-FUP-Processor"] do={ /system script remove $i; }
:foreach i in=[/ip firewall mangle find where comment~"D-FUP"] do={ /ip firewall mangle remove $i; }
:foreach i in=[/queue tree find where name~"D-FUP"] do={ /queue tree remove $i; }
:foreach i in=[/queue type find where name~"D-FUP"] do={ /queue type remove $i; }

:global dfupVersion;
:global dfupCfgWanInterface;
:global dfupCfgMaxDownMbps;
:global dfupCfgMaxUpMbps;
:global dfupCfgParentShaperPercent;
:global dfupCfgSensitiveUdpPorts;
:global dfupCfgQuicBulkFromMB;
:global dfupCfgTcpMediumFromMB;
:global dfupCfgTcpHeavyFromMB;
:global dfupCfgAvgSamples;
:global dfupCfgDebug;
:global dfupCfgAutoDisableFastTrack;
:global dfupAvgRxBps;
:global dfupAvgTxBps;
:global dfupSampleCount;
:global dfupLastDownLevel;
:global dfupLastUpLevel;

:set dfupVersion;
:set dfupCfgWanInterface;
:set dfupCfgMaxDownMbps;
:set dfupCfgMaxUpMbps;
:set dfupCfgParentShaperPercent;
:set dfupCfgSensitiveUdpPorts;
:set dfupCfgQuicBulkFromMB;
:set dfupCfgTcpMediumFromMB;
:set dfupCfgTcpHeavyFromMB;
:set dfupCfgAvgSamples;
:set dfupCfgDebug;
:set dfupCfgAutoDisableFastTrack;
:set dfupAvgRxBps;
:set dfupAvgTxBps;
:set dfupSampleCount;
:set dfupLastDownLevel;
:set dfupLastUpLevel;

:log warning "D-FUP: uninstall finished";
