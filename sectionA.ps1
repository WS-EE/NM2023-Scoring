$output = "points/nm01-sectionA.txt"
$vlnd_fw = "c1-vlnd-fw-01"
$trt_fw = "c1-trt-fw-01"

Function Invoke-VmCommand {
    Param (
        [string]$VmName,
        [string]$Script,
        [string]$User="ansible",
        [string]$UserPwd="WhatW3G0tHere?",
        [string]$ScriptType,
        [switch]$raw=$False
    )

    $getVm = Get-VM -Name $VmName
    if (($getVm).PowerState -eq "PoweredOff") {
        return "Fail - VM $VmName is offline!"
    }
    if (($getVm | Get-View).Guest.ToolsStatus -eq "toolsNotRunning") {
        return "Fail - VMware Tools not running at $VmName!"
    }

    if ($ScriptType) {
        $cmd = Invoke-VMScript -VM $getVm -ScriptText $Script -GuestUser $User -GuestPassword $UserPwd -ScriptType $ScriptType -ErrorAction SilentlyContinue
    } else {
        $cmd = Invoke-VMScript -VM $getVm -ScriptText $Script -GuestUser $User -GuestPassword $UserPwd -ErrorAction SilentlyContinue
    }

    if ($raw) {
        $out_cmd = $cmd
    } else {
        $out_cmd = ($cmd).split('\s+')
    }
    return $out_cmd
}

Function Invoke-ScoreUpdate {
    Param (
        [string]$StatusFile="${output}",
        [string]$Task,
        [string]$Status,
        [string]$Result,
        [switch]$Default=$True
)
    if ($Default) {
        if ($Result -Like "Fail -*") {
            Write-Host $Result
        } elseif ($Result[0] -Eq "1") {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - OK"
        } else {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - NOT OK"
        }    
    } else {
        Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - $Status"
    }
}

# VLND-FW
## A1.M1: 1.50% - TRT-VLND VPN on kolitud IPSec peale
$A1M1_state = Invoke-VmCommand -VmName "${vlnd_fw}" -ScriptType "bash" `
    -Script 'if [ "$(configctl ipsec status | grep "IKE_SAs:")" == "IKE_SAs: 1 total, 0 half-open" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A1M1_state -Task "A1.M1"

## A1.M2: 1.00% - Alamvõrk on suurendatud
$A1M2_state = Invoke-VmCommand -VmName "${vlnd_fw}" -ScriptType "bash" `
    -Script 'if [ "$(cat /conf/config.xml | grep ''<lan>'' -A 10 | grep -o ''<subnet>[0-9]*'')" == "<subnet>28" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A1M2_state -Task "A1.M2"

## A1.M3: 1.00% - Nimelahendused suunatud ISP nimeserverile
$A1M3_state = Invoke-VmCommand -VmName "${vlnd_fw}" -ScriptType "bash" `
    -Script 'if [ "$(cat /conf/config.xml | grep -o ""198.51.100.2"")" == "198.51.100.2" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A1M3_state -Task "A1.M3"

## A1.M4: 1.00% - Ajaserverina on kasutusel ISP NTP server
$A1M4_state = Invoke-VmCommand -VmName "${vlnd_fw}" -ScriptType "bash" `
    -Script 'if [ "$(cat /conf/config.xml | grep -o "<timeservers>.*</timeservers>")" == "<timeservers>198.51.100.4</timeservers>" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A1M4_state -Task "A1.M4"

# TRT-FW
## A2.M1: 1.50% - TRT-VLND VPN on kolitud IPSec peale
$A2M1_state = Invoke-VmCommand -VmName "${trt_fw}" -ScriptType "bash" `
    -Script 'if [ "$(configctl ipsec status | grep "IKE_SAs:")" == "IKE_SAs: 1 total, 0 half-open" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A2M1_state -Task "A2.M1"

## A2.M2: 1.00% - Nimelahendused suunatud ISP nimeserverile
$A2M2_state = Invoke-VmCommand -VmName "${trt_fw}" -ScriptType "bash" `
    -Script 'if [ "$(cat /conf/config.xml | grep -o ""198.51.100.2"")" == "198.51.100.2" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A2M2_state -Task "A2.M2"

## A2.M3: 1.00% - Ajaserverina on kasutusel ISP NTP server
$A2M3_state = Invoke-VmCommand -VmName "${trt_fw}" -ScriptType "bash" `
    -Script 'if [ "$(cat /conf/config.xml | grep -o "<timeservers>.*</timeservers>")" == "<timeservers>198.51.100.4</timeservers>" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $A2M3_state -Task "A2.M3"
