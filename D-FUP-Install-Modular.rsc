# D-FUP RouterOS 7 v1.1
# Author: Lukáš Kysela
# Contact: developer@lukaskysela.cz
# Website: https://www.lukaskysela.cz
# Target: MikroTik RouterOS 7
# Modular installer. Requires D-FUP-Processor.rsc in RouterOS Files.
:global dfupVersion "1.1";
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
    :log error ("D-FUP: WAN interface not found: " . $dfupCfgWanInterface);
    :error "D-FUP: WAN interface not found";
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

:log warning ("D-FUP: installing v" . $dfupVersion . " on WAN=" . $dfupCfgWanInterface . ", down=" . $dfupCfgMaxDownMbps . "M, up=" . $dfupCfgMaxUpMbps . "M");

# Idempotent cleanup of previous D-FUP objects.
:foreach i in=[/system scheduler find where name="D-FUP-Processor"] do={ /system scheduler remove $i; }
:foreach i in=[/system script find where name="D-FUP-Processor"] do={ /system script remove $i; }
:foreach i in=[/ip firewall mangle find where comment~"D-FUP"] do={ /ip firewall mangle remove $i; }
:foreach i in=[/queue tree find where name~"D-FUP"] do={ /queue tree remove $i; }
:foreach i in=[/queue type find where name~"D-FUP"] do={ /queue type remove $i; }

:global dfupAvgRxBps 0;
:global dfupAvgTxBps 0;
:global dfupSampleCount 0;
:global dfupLastDownLevel 0;
:global dfupLastUpLevel 0;

:if ([:len [/ip firewall filter find where action=fasttrack-connection disabled=no]] > 0) do={
    :if ($dfupCfgAutoDisableFastTrack = true) do={
        /ip firewall filter disable [find where action=fasttrack-connection disabled=no];
        :log warning "D-FUP: active FastTrack rules were disabled because dfupCfgAutoDisableFastTrack=true";
    } else={
        :log warning "D-FUP: active FastTrack rules detected. FastTrack can bypass queue tree with parent=global. Disable or exclude D-FUP traffic if shaping seems ineffective.";
    }
}

# Queue types. PCQ dynamically shares each class between client IP addresses.
/queue type add name="D-FUP PCQ Download" kind=pcq pcq-classifier=dst-address pcq-rate=0 pcq-limit=50 pcq-total-limit=2000 comment="D-FUP v1.1";
/queue type add name="D-FUP PCQ Upload" kind=pcq pcq-classifier=src-address pcq-rate=0 pcq-limit=50 pcq-total-limit=2000 comment="D-FUP v1.1";

# Queue tree parents.
/queue tree add name="D-FUP Download Parent" parent=global max-limit=$parentDownLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Upload Parent" parent=global max-limit=$parentUpLimit comment="D-FUP v1.1";

# Download classes.
/queue tree add name="D-FUP Download Sensitive UDP" parent="D-FUP Download Parent" packet-mark=dfup_down_sensitive queue="D-FUP PCQ Download" priority=1 max-limit=$parentDownLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Download Default Fair" parent="D-FUP Download Parent" packet-mark=dfup_down_default queue="D-FUP PCQ Download" priority=4 max-limit=$parentDownLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Download TCP Medium" parent="D-FUP Download Parent" packet-mark=dfup_down_tcp_medium queue="D-FUP PCQ Download" priority=6 max-limit=$parentDownLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Download TCP Heavy" parent="D-FUP Download Parent" packet-mark=dfup_down_tcp_heavy queue="D-FUP PCQ Download" priority=8 max-limit=$parentDownLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Download QUIC Bulk" parent="D-FUP Download Parent" packet-mark=dfup_down_quic_bulk queue="D-FUP PCQ Download" priority=7 max-limit=$parentDownLimit comment="D-FUP v1.1";

# Upload classes.
/queue tree add name="D-FUP Upload Sensitive UDP" parent="D-FUP Upload Parent" packet-mark=dfup_up_sensitive queue="D-FUP PCQ Upload" priority=1 max-limit=$parentUpLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Upload Default Fair" parent="D-FUP Upload Parent" packet-mark=dfup_up_default queue="D-FUP PCQ Upload" priority=4 max-limit=$parentUpLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Upload TCP Medium" parent="D-FUP Upload Parent" packet-mark=dfup_up_tcp_medium queue="D-FUP PCQ Upload" priority=6 max-limit=$parentUpLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Upload TCP Heavy" parent="D-FUP Upload Parent" packet-mark=dfup_up_tcp_heavy queue="D-FUP PCQ Upload" priority=8 max-limit=$parentUpLimit comment="D-FUP v1.1";
/queue tree add name="D-FUP Upload QUIC Bulk" parent="D-FUP Upload Parent" packet-mark=dfup_up_quic_bulk queue="D-FUP PCQ Upload" priority=7 max-limit=$parentUpLimit comment="D-FUP v1.1";

# Mangle order matters: sensitive UDP -> QUIC bulk -> TCP heavy -> TCP medium -> default fair.
# Download direction: packets entering from WAN and forwarded to LAN clients.
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp src-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_down_sensitive passthrough=no comment="D-FUP v1.1 down sensitive UDP src-port";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp dst-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_down_sensitive passthrough=no comment="D-FUP v1.1 down sensitive UDP dst-port";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp src-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_down_quic_bulk passthrough=no comment="D-FUP v1.1 down QUIC UDP443 bulk";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=udp dst-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_down_quic_bulk passthrough=no comment="D-FUP v1.1 down QUIC UDP443 bulk reverse";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpHeavyRange action=mark-packet new-packet-mark=dfup_down_tcp_heavy passthrough=no comment="D-FUP v1.1 down TCP heavy";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpMediumRange action=mark-packet new-packet-mark=dfup_down_tcp_medium passthrough=no comment="D-FUP v1.1 down TCP medium";
/ip firewall mangle add chain=forward in-interface=$dfupCfgWanInterface action=mark-packet new-packet-mark=dfup_down_default passthrough=no comment="D-FUP v1.1 down default fair";

# Upload direction: packets leaving through WAN from LAN clients.
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp dst-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_up_sensitive passthrough=no comment="D-FUP v1.1 up sensitive UDP dst-port";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp src-port=$dfupCfgSensitiveUdpPorts action=mark-packet new-packet-mark=dfup_up_sensitive passthrough=no comment="D-FUP v1.1 up sensitive UDP src-port";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp dst-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_up_quic_bulk passthrough=no comment="D-FUP v1.1 up QUIC UDP443 bulk";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=udp src-port=443 connection-bytes=$quicRange action=mark-packet new-packet-mark=dfup_up_quic_bulk passthrough=no comment="D-FUP v1.1 up QUIC UDP443 bulk reverse";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpHeavyRange action=mark-packet new-packet-mark=dfup_up_tcp_heavy passthrough=no comment="D-FUP v1.1 up TCP heavy";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface protocol=tcp connection-bytes=$tcpMediumRange action=mark-packet new-packet-mark=dfup_up_tcp_medium passthrough=no comment="D-FUP v1.1 up TCP medium";
/ip firewall mangle add chain=forward out-interface=$dfupCfgWanInterface action=mark-packet new-packet-mark=dfup_up_default passthrough=no comment="D-FUP v1.1 up default fair";

/system script add name="D-FUP-Processor" policy=read,write,test source=[/file get "D-FUP-Processor.rsc" contents] comment="D-FUP v1.1";
/system scheduler add name="D-FUP-Processor" interval=$dfupSchedulerInterval start-time=startup on-event="/system script run D-FUP-Processor" policy=read,write,test comment="D-FUP v1.1";
/system script run D-FUP-Processor;
:log warning ("D-FUP: installed v" . $dfupVersion . ". Check /queue tree and /log.");
