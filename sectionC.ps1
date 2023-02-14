$output = "points/n01-sectionC.txt"
$trt_srv = "c1-trt-srv-01"
$trt_pc1 = "c1-trt-pc1-01"

Function Invoke-VmCommand {
    Param (
        [string]$VmName,
        [string]$Script,
        [string]$User="scorer",
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
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - NOT OK"
        } elseif ($Result[0] -Eq "1") {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - OK"
        } else {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - NOT OK"
        }    
    } else {
        Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - $Status"
    }
}

# TRT-SRV
## C1.M1: 2.00% - DHCP teenuse on üks-ühele kolitud OPNsense-st
$C1M1_state = Invoke-VmCommand -VmName "${trt_srv}" `
    -Script 'if [ "$(cat /etc/dhcp/dhcpd.conf 2>/dev/null | grep -o "eestiasi.ee")" == "eestiasi.ee" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $C1M1_state -Task "C1.M1"

## C1.M2: 1.50% - Forward tsoon DC1 & DC2 vastu
$C1M2_state = Invoke-VmCommand -VmName "${trt_srv}" `
    -Script 'if [ "$(sudo cat /etc/bind/* | grep "eestiasi.ee" -A 4 | grep -o "type forward")" == "type forward" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $C1M2_state -Task "C1.M2"

## C1.M3: 1.50% - Reverse tsoon DC1 & DC2 vastu
$C1M3_state = Invoke-VmCommand -VmName "${trt_srv}" `
    -Script 'if [ "$(sudo cat /etc/bind/* | grep "in-addr.arpa" -A 4 | grep -o "type forward" | head -n 1)" == "type forward" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $C1M3_state -Task "C1.M3"

## C1.M4: 1.00% - Default Forwarder ISP vastu
$C1M4_state = Invoke-VmCommand -VmName "${trt_srv}" `
    -Script 'if [ "$(sudo cat /etc/bind/* | grep -o "198.51.100.2")" == "198.51.100.2" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $C1M4_state -Task "C1.M4"

# TRT-PC1
## C2.M1: 1.50% - Masin on liidetud domeeni eestiasi.ee
$C2M1_state = Invoke-VmCommand -VmName "${trt_pc1}" `
-Script 'if ((gwmi win32_computersystem).partofdomain -eq $true) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $C2M1_state -Task "C2.M1"

## C2.M2: 1.00% - Masinal on tulemüüri reegel "allow-ICMP"
$C2M2_state = Invoke-VmCommand -VmName "${trt_pc1}" `
    -Script 'if (Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSourceType GroupPolicy -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -Like "allow-ICMP"}) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $C2M2_state -Task "C2.M2"
