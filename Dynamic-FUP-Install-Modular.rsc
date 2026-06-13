# Dynamic FUP RouterOS 7
# Author: Lukáš Kysela
# Contact: developer@lukaskysela.cz
# Website: https://www.lukaskysela.cz
# Target: MikroTik RouterOS 7
# Modular installer. Requires Dynamic-FUP-Processor.rsc in RouterOS Files.
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

:if ([:len [/interface find where name=$dfupCfgWanInterface]] = 0) do={
    :log error ("Dynamic FUP: WAN interface not found: " . $dfupCfgWanInterface);
    :error "Dynamic FUP: WAN interface not found";
}

:local maxDownBps ($dfupCfgMaxDownMbps * 1000000);
:local maxUpBps ($dfupCfgMaxUpMbps * 1000000);
:local parentDownLimit (($maxDownBps * $dfupCfgParentShaperPercent) / 100);
:local parentUpLimit (($maxUpBps * $dfupCfgParentShaperPercent) / 100);
:local quicBytes ($dfupCfgQuicBulkFromMB * 1048576);
:local tcpMediumBytes ($dfupCfgTcpMediumFromMB * 1048576);
:local tcpHeavyBytes ($dfupCfgTcpHeavyFromMB * 1048576);
:local quicRange ($quicBytes . "-0");
:local tcpMediumRange ($tcpMediumBytes . "-0");
:local tcpHeavyRange ($tcpHeavyBytes . "-0");

:log warning ("Dynamic FUP: installing on WAN=" . $dfupCfgWanInterface . ", down=" . $dfupCfgMaxDownMbps . "M, up=" . $dfupCfgMaxUpMbps . "M");

# Idempotent cleanup of previous Dynamic FUP objects, including older D-FUP package names.
:foreach i in=[/system scheduler find where name="Dynamic-FUP-Processor"] do={ /system scheduler remove $i; }
:foreach i in=[/system script find where name="Dynamic-FUP-Processor"] do={ /system script remove $i; }
:foreach i in=[/system scheduler find where name="D-FUP-Processor"] do={ /system scheduler remove $i; }
:foreach i in=[/system script find where name="D-FUP-Processor"] do={ /system script remove $i; }
:foreach i in=[/ip firewall mangle find where comment~"Dynamic FUP"] do={ /ip firewall mangle remove $i; }
:foreach i in=[/ip firewall mangle find where comment~"D-FUP"] do={ /ip firewall mangle remove $i; }
:foreach i in=[/queue tree find where name~"Dynamic-FUP"] do={ /queue tree remove $i; }
:foreach i in=[/queue tree find where name~"Dynamic-FUP"] do={ /queue tree remove $i; }
:foreach i in=[/queue type find where name~"Dynamic-FUP"] do={ /queue type remove $i; }
:foreach i in=[/queue type find where name~"Dynamic-FUP"] do={ /queue type remove $i; }

:global dfupAvgRxBps 0;
:global dfupAvgTxBps 0;
:global dfupSampleCount 0;
:global dfupLastDownLevel 0;
:global dfupLastUpLevel 0;

:if ([:len [/ip firewall filter find where action=fasttrack-connection disabled=no]] > 0) do={
    :if ($dfupCfgAutoDisableFastTrack = true) do={
        /ip firewall filter disable [find where action=fasttrack-connection disabled=no];
        :log warning "Dynamic FUP: active FastTrack rules were disabled because dfupCfgAutoDisableFastTrack=true";
    } else={
        :log warning "Dynamic FUP: active FastTrack rules detected. FastTrack can bypass queue tree with parent=global. Disable or exclude Dynamic FUP traffic if shaping seems ineffective.";
    }
}

# Queue types. PCQ dynamically shares each class between client IP addresses.
/queue type add name="Dynamic-FUP PCQ Download" kind=pcq pcq-classifier=dst-address pcq-rate=0 pcq-limit=50 pcq-total-limit=2000 comment="Dynamic FUP";
/queue type add name="Dynamic-FUP PCQ Upload" kind=pcq pcq-classifier=src-address pcq-rate=0 pcq-limit=50 pcq-total-limit=2000 comment="Dynamic FUP";

# Queue tree parents.
/queue tree add name="Dynamic-FUP Download Parent" parent=global max-limit=$parentDownLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Upload Parent" parent=global max-limit=$parentUpLimit comment="Dynamic FUP";

# Download classes.
/queue tree add name="Dynamic-FUP Download Sensitive UDP" parent="Dynamic-FUP Download Parent" packet-mark=dfup_down_sensitive queue="Dynamic-FUP PCQ Download" priority=1 max-limit=$parentDownLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Download Default Fair" parent="Dynamic-FUP Download Parent" packet-mark=dfup_down_default queue="Dynamic-FUP PCQ Download" priority=4 max-limit=$parentDownLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Download TCP Medium" parent="Dynamic-FUP Download Parent" packet-mark=dfup_down_tcp_medium queue="Dynamic-FUP PCQ Download" priority=6 max-limit=$parentDownLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Download TCP Heavy" parent="Dynamic-FUP Download Parent" packet-mark=dfup_down_tcp_heavy queue="Dynamic-FUP PCQ Download" priority=8 max-limit=$parentDownLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Download QUIC Bulk" parent="Dynamic-FUP Download Parent" packet-mark=dfup_down_quic_bulk queue="Dynamic-FUP PCQ Download" priority=7 max-limit=$parentDownLimit comment="Dynamic FUP";

# Upload classes.
/queue tree add name="Dynamic-FUP Upload Sensitive UDP" parent="Dynamic-FUP Upload Parent" packet-mark=dfup_up_sensitive queue="Dynamic-FUP PCQ Upload" priority=1 max-limit=$parentUpLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Upload Default Fair" parent="Dynamic-FUP Upload Parent" packet-mark=dfup_up_default queue="Dynamic-FUP PCQ Upload" priority=4 max-limit=$parentUpLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Upload TCP Medium" parent="Dynamic-FUP Upload Parent" packet-mark=dfup_up_tcp_medium queue="Dynamic-FUP PCQ Upload" priority=6 max-limit=$parentUpLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Upload TCP Heavy" parent="Dynamic-FUP Upload Parent" packet-mark=dfup_up_tcp_heavy queue="Dynamic-FUP PCQ Upload" priority=8 max-limit=$parentUpLimit comment="Dynamic FUP";
/queue tree add name="Dynamic-FUP Upload QUIC Bulk" parent="Dynamic-FUP Upload Parent" packet-mark=dfup_up_quic_bulk queue="Dynamic-FUP PCQ Upload" priority=7 max-limit=$parentUpLimit comment="Dynamic FUP";

# Mangle order matters: sensitive UDP -> QUIC bulk -> TCP heavy -> TCP medium -> default fair.
# Download direction: packets entering from WAN and forwarded to LAN clients.
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp src-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_down_sensitive passthrough=no comment="Dynamic FUP down sensitive UDP src-port";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp dst-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_down_sensitive passthrough=no comment="Dynamic FUP down sensitive UDP dst-port";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp src-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_down_quic_bulk passthrough=no comment="Dynamic FUP down QUIC UDP443 bulk";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp dst-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_down_quic_bulk passthrough=no comment="Dynamic FUP down QUIC UDP443 bulk reverse";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpHeavyRange action=mark-packet new-packet-mark=dfup_down_tcp_heavy passthrough=no comment="Dynamic FUP down TCP heavy";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpMediumRange action=mark-packet new-packet-mark=dfup_down_tcp_medium passthrough=no comment="Dynamic FUP down TCP medium";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface action=mark-packet new-packet-mark=dfup_down_default passthrough=no comment="Dynamic FUP down default fair";

# Upload direction: packets leaving through WAN from LAN clients.
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp dst-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_up_sensitive passthrough=no comment="Dynamic FUP up sensitive UDP dst-port";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp src-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_up_sensitive passthrough=no comment="Dynamic FUP up sensitive UDP src-port";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp dst-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_up_quic_bulk passthrough=no comment="Dynamic FUP up QUIC UDP443 bulk";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp src-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_up_quic_bulk passthrough=no comment="Dynamic FUP up QUIC UDP443 bulk reverse";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpHeavyRange action=mark-packet new-packet-mark=dfup_up_tcp_heavy passthrough=no comment="Dynamic FUP up TCP heavy";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpMediumRange action=mark-packet new-packet-mark=dfup_up_tcp_medium passthrough=no comment="Dynamic FUP up TCP medium";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface action=mark-packet new-packet-mark=dfup_up_default passthrough=no comment="Dynamic FUP up default fair";

/system script add name="Dynamic-FUP-Processor" policy=read,write,test source=[/file get "Dynamic-FUP-Processor.rsc" contents] comment="Dynamic FUP";
/system scheduler add name="Dynamic-FUP-Processor" interval=$dfupSchedulerInterval start-time=startup on-event="/system script run Dynamic-FUP-Processor" policy=read,write,test comment="Dynamic FUP";
/system script run Dynamic-FUP-Processor;
:log warning "Dynamic FUP: installed. Check /queue tree and /log.";
