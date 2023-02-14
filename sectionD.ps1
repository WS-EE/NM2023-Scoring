$output = "points/nm01-sectionD.txt"
$num = "01"

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
        } elseif ($Result[0] -Eq "1") {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - OK"
        } else {
            Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - NOT OK"
        }    
    } else {
        Add-Content -Path $StatusFile -Value "[$(Get-Date)] $Task - $Status"
    }
}

# TICKET 1
## D1.M1: 2.00% - andmebaasi konto on loodud
$D1M1_state = Invoke-VmCommand -VmName "c2-ticket01-${num}" `
    -Script 'export PGPASSWORD=Passw0rd$; if [ "$(psql --host=localhost --username=arendaja eestiasi -c "\du" 2>/dev/null | grep -o "arendaja")" == "arendaja" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D1M1_state -Task "D1.M1"

## D1.M2: 1.50% - andmebaasi saab väljaspoolt ligi
$D1M1_state = Invoke-VmCommand -VmName "c2-ticket01-${num}" `
    -Script 'export PGPASSWORD=Passw0rd$; if [ "$(psql --host=172.20.23.11 --username=arendaja eestiasi -c "\du" 2>/dev/null | grep -o "arendaja")" == "arendaja" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D1M2_state -Task "D1.M2"


# TICKET 2
## D2.M1: 1.00% - nginx konfiguratsioonid on parandatud
$D2M1_state = Invoke-VmCommand -VmName "c2-ticket02-${num}" `
    -Script 'if [ "$(sudo systemctl status nginx | grep -o "running")" == "running" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D2M1_state -Task "D2.M1"

## D2.M2: 2.00% - veebileht on kättesaadav
$D2M2_state = Invoke-VmCommand -VmName "c2-ticket02-${num}" `
    -Script 'if [ "$(sudo curl -m 5 localhost | grep "ticket 2")" == "ticket 2" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D2M2_state -Task "D2.M2"

## D2.M3: 0.50% - iptables reeglid on salvestatud
$D2M3_state = Invoke-VmCommand -VmName "c2-ticket02-${num}" `
    -Script 'if [ "$(sudo cat /etc/iptables/rules.v4 | grep -o "\-\-dport 80 \-j DROP")" == "--dport 80 -j DROP" ]; then echo 0; else echo 1; fi'

Invoke-ScoreUpdate -Result $D2M3_state -Task "D2.M3"


# TICKET 3
## D3.M1: 1.50% - docker on käivitatud
$D3M1_state = Invoke-VmCommand -VmName "c2-ticket03-${num}" `
    -Script 'if [ "$(sudo docker ps | grep -o nginx | head -n 1)" == "nginx" ]; then echo 1; else echo 0;fi'

Invoke-ScoreUpdate -Result $D3M1_state -Task "D3.M1"

## D3.M2: 2.00% - veebilehe sisu on korrigeeritud
$D3M2_state = Invoke-VmCommand -VmName "c2-ticket03-${num}" `
    -Script 'if [ "$(curl -s localhost | grep -o "ticket 3")" == "ticket 3" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D3M2_state -Task "D3.M2"


# TICKET 4
## D4.M1: 1.50% - operatsioonisüsteem bootib
$D4M1_state = Invoke-VmCommand -VmName "c2-ticket04-${num}" `
    -Script 'if [ "$(hostname | grep -o ticket04)" == "ticket04" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D4M1_state -Task "D4.M1"

## D4.M2: 2.00% - /oluline kausta sisu on alles
$D4M2_state = Invoke-VmCommand -VmName "c2-ticket04-${num}" `
    -Script 'if [ "$(sudo cat /oluline/numbrid.txt 2>/dev/null | grep -o 8414783081)" == "8414783081" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D4M2_state -Task "D4.M2"


# TICKET 5
## D5.M1: 1.50% - graafiline liides on taastatud
$D5M1_state = Invoke-VmCommand -VmName "c2-ticket05-${num}" `
    -Script 'if [ "$(systemctl status gdm | grep -o "running")" == "running" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D5M1_state -Task "D5.M1"

## D5.M2: 2.00% - graafiline liides on taastatud
$D5M2_state = Invoke-VmCommand -VmName "c2-ticket05-${num}" `
    -Script 'if [ "$(systemctl status gdm | grep -o "enabled;")" == "enabled;" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $D5M2_state -Task "D5.M2"


# TICKET 6
## D6.M1: 1.50% - John Doe on taastatud
$D6M1_state = Invoke-VmCommand -VmName "c2-ticket06-${num}" `
    -Script 'try { if ((Get-ADUser John.Doe).Enabled) { return 1 } } catch { return 0 }'
    
Invoke-ScoreUpdate -Result $D6M1_state -Task "D6.M1"

## D6.M2: 2.00% - Jane Doe on taastatud
$D6M2_state = Invoke-VmCommand -VmName "c2-ticket06-${num}" `
    -Script 'try { if ((Get-ADUser Jane.Doe).Enabled) { return 1 } } catch { return 0 }'

Invoke-ScoreUpdate -Result $D6M2_state -Task "D6.M2"


# TICKET 7
## D7.M1: 1.50% - outlook.com dns kirjed
$D7M1_state = Invoke-VmCommand -VmName "c2-ticket07-${num}" `
    -Script 'if ((Resolve-DnsName -Type TXT -Name spf.protection.outlook.com -ErrorAction SilentlyContinue).Strings) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D7M1_state -Task "D7.M1"

## D7.M2: 2.00% - tix7.ee dns kirjed
$D7M2_state = Invoke-VmCommand -VmName "c2-ticket07-${num}" `
    -Script 'if ((Resolve-DnsName -Type TXT -Name tix7.ee).Strings -Like "v=spf1*") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D7M2_state -Task "D7.M2"

# TICKET 8
## D8.M1: 1.50% - task schedulerid puhastatud
$D8M1_state = Invoke-VmCommand -VmName "c2-ticket08-${num}" `
    -Script '$task = (Get-ScheduledTask -TaskName EdgeUpdater -ErrorAction SilentlyContinue); if (!($task.State)) { return 1 } elseif ($task.State -eq "Disabled") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D8M1_state -Task "D8.M1"

## D8.M2: 2.00% - startup skript puhastatud # settings staatuse kontroll manuaalne, kui NOT OK
$D8M2_state = Invoke-VmCommand -VmName "c2-ticket08-${num}" `
    -Script 'if (!((Get-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\reboot.bat" -ErrorAction SilentlyContinue).Name)) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D8M2_state -Task "D8.M2"

# TICKET 9
## D9.M1: 1.50% - avalikud võrgukettad on eemaldatud
$D9M1_state = Invoke-VmCommand -VmName "c2-ticket09-${num}" `
    -Script 'if (!(Get-SmbShare | Where {$_.Name -eq "ADMIN"})) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D9M1_state -Task "D9.M1"

## D9.M2: 2.00% - peidetud võrgukettad on eemaldatud
$D9M2_state = Invoke-VmCommand -VmName "c2-ticket09-${num}" `
    -Script 'if (!(Get-SmbShare | Where {$_.Name -eq "hmm$"})) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $D9M2_state -Task "D9.M2"

# TICKET 10
## D10.M1: 1.50% - power plan redigeeritud
$D10M1_state = Invoke-VmCommand -VmName "c2-ticket10-${num}" `
    -Script 'if (powercfg /GetActiveScheme |  select-string "Ultimate") { return 0 } else { return 1 }'

Invoke-ScoreUpdate -Result $D10M1_state -Task "D10.M1"

## D10.M2: 2.00% - power plan redigeeritud
$D10M2_state = Invoke-VmCommand -VmName "c2-ticket10-${num}" `
    -Script 'if (powercfg /GetActiveScheme |  select-string "Ultimate") { return 0 } else { return 1 }'

Invoke-ScoreUpdate -Result $D10M2_state -Task "D10.M2"
