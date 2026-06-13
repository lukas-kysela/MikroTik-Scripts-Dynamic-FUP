# Dynamic FUP RouterOS 7
# Author: Lukáš Kysela
# Contact: developer@lukaskysela.cz
# Website: https://www.lukaskysela.cz
# Target: MikroTik RouterOS 7
# Processor script. Updates queue limits based on WAN utilization.
:global dfupCfgWanInterface;
:global dfupCfgMaxDownMbps;
:global dfupCfgMaxUpMbps;
:global dfupCfgParentShaperPercent;
:global dfupCfgAvgSamples;
:global dfupCfgDebug;

:global dfupAvgRxBps;
:global dfupAvgTxBps;
:global dfupSampleCount;
:global dfupLastDownLevel;
:global dfupLastUpLevel;

:if ([:len [/interface find where name=$dfupCfgWanInterface]] = 0) do={
    :log error ("Dynamic FUP: WAN interface not found: " . $dfupCfgWanInterface);
    :error "Dynamic FUP: WAN interface not found";
}

:if ([:typeof $dfupAvgRxBps] = "nothing") do={ :set dfupAvgRxBps 0; }
:if ([:typeof $dfupAvgTxBps] = "nothing") do={ :set dfupAvgTxBps 0; }
:if ([:typeof $dfupSampleCount] = "nothing") do={ :set dfupSampleCount 0; }
:if ([:typeof $dfupLastDownLevel] = "nothing") do={ :set dfupLastDownLevel 0; }
:if ([:typeof $dfupLastUpLevel] = "nothing") do={ :set dfupLastUpLevel 0; }

:local maxDownBps ($dfupCfgMaxDownMbps * 1000000);
:local maxUpBps ($dfupCfgMaxUpMbps * 1000000);
:if ($maxDownBps < 1) do={ :set maxDownBps 1; }
:if ($maxUpBps < 1) do={ :set maxUpBps 1; }

:local parentDownLimit (($maxDownBps * $dfupCfgParentShaperPercent) / 100);
:local parentUpLimit (($maxUpBps * $dfupCfgParentShaperPercent) / 100);

:local traffic [/interface monitor-traffic $dfupCfgWanInterface once as-value];
:local rxBps ($traffic->"rx-bits-per-second");
:local txBps ($traffic->"tx-bits-per-second");
:if ([:typeof $rxBps] = "nothing") do={ :set rxBps 0; }
:if ([:typeof $txBps] = "nothing") do={ :set txBps 0; }

:local samples $dfupSampleCount;
:if ($samples < 0) do={ :set samples 0; }
:if ($samples < $dfupCfgAvgSamples) do={
    :set dfupAvgRxBps ((($dfupAvgRxBps * $samples) + $rxBps) / ($samples + 1));
    :set dfupAvgTxBps ((($dfupAvgTxBps * $samples) + $txBps) / ($samples + 1));
    :set dfupSampleCount ($samples + 1);
} else={
    :set dfupAvgRxBps ((($dfupAvgRxBps * ($dfupCfgAvgSamples - 1)) + $rxBps) / $dfupCfgAvgSamples);
    :set dfupAvgTxBps ((($dfupAvgTxBps * ($dfupCfgAvgSamples - 1)) + $txBps) / $dfupCfgAvgSamples);
}

:local downLoadPercent (($dfupAvgRxBps * 100) / $maxDownBps);
:local upLoadPercent (($dfupAvgTxBps * 100) / $maxUpBps);

:local downLevel 1;
:if ($downLoadPercent >= 90) do={ :set downLevel 3; } else={ :if ($downLoadPercent >= 70) do={ :set downLevel 2; } }

:local upLevel 1;
:if ($upLoadPercent >= 90) do={ :set upLevel 3; } else={ :if ($upLoadPercent >= 70) do={ :set upLevel 2; } }

# Percentages are relative to the parent shaper limit.
:local downSensitivePct 100;
:local downDefaultPct 95;
:local downMediumPct 90;
:local downHeavyPct 80;
:local downQuicPct 80;

:if ($downLevel = 2) do={
    :set downDefaultPct 85;
    :set downMediumPct 65;
    :set downHeavyPct 40;
    :set downQuicPct 50;
}
:if ($downLevel = 3) do={
    :set downDefaultPct 75;
    :set downMediumPct 45;
    :set downHeavyPct 25;
    :set downQuicPct 35;
}

:local upSensitivePct 100;
:local upDefaultPct 95;
:local upMediumPct 90;
:local upHeavyPct 80;
:local upQuicPct 80;

:if ($upLevel = 2) do={
    :set upDefaultPct 85;
    :set upMediumPct 65;
    :set upHeavyPct 40;
    :set upQuicPct 50;
}
:if ($upLevel = 3) do={
    :set upDefaultPct 75;
    :set upMediumPct 45;
    :set upHeavyPct 25;
    :set upQuicPct 35;
}

:local qid "";

:set qid [/queue tree find where name="Dynamic-FUP Download Parent"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=$parentDownLimit; }
:set qid [/queue tree find where name="Dynamic-FUP Upload Parent"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=$parentUpLimit; }

:set qid [/queue tree find where name="Dynamic-FUP Download Sensitive UDP"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentDownLimit * $downSensitivePct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Download Default Fair"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentDownLimit * $downDefaultPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Download TCP Medium"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentDownLimit * $downMediumPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Download TCP Heavy"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentDownLimit * $downHeavyPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Download QUIC Bulk"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentDownLimit * $downQuicPct) / 100); }

:set qid [/queue tree find where name="Dynamic-FUP Upload Sensitive UDP"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentUpLimit * $upSensitivePct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Upload Default Fair"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentUpLimit * $upDefaultPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Upload TCP Medium"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentUpLimit * $upMediumPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Upload TCP Heavy"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentUpLimit * $upHeavyPct) / 100); }
:set qid [/queue tree find where name="Dynamic-FUP Upload QUIC Bulk"];
:if ([:len $qid] > 0) do={ /queue tree set $qid max-limit=(($parentUpLimit * $upQuicPct) / 100); }

:if (($dfupLastDownLevel != $downLevel) || ($dfupLastUpLevel != $upLevel)) do={
    :log warning ("Dynamic FUP: level changed, down=" . $downLevel . " (" . $downLoadPercent . "%), up=" . $upLevel . " (" . $upLoadPercent . "%)");
    :set dfupLastDownLevel $downLevel;
    :set dfupLastUpLevel $upLevel;
} else={
    :if ($dfupCfgDebug = true) do={
        :log info ("Dynamic FUP: rx=" . $rxBps . "bps avg=" . $dfupAvgRxBps . "bps " . $downLoadPercent . "%, tx=" . $txBps . "bps avg=" . $dfupAvgTxBps . "bps " . $upLoadPercent . "%");
    }
}
