$output = "points/nm01-sectionB.txt"
$vlnd_dc1 = "c1-vlnd-dc1-01"
$vlnd_www = "c1-vlnd-www-01"
$vlnd_srv = "c1-vlnd-srv-01"
$vlnd_ntp = "c1-vlnd-ntp-01"
$vlnd_mail = "c1-vlnd-mail-01"
$vlnd_pc1 = "c1-vlnd-pc1-01"
$vlnd_pc2 = "c1-vlnd-pc2-01"
$zabbix = "c1-zabbix-01"

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

# VLND-DC1.EESTIASI.EE
## B1.M1: 0.75% - Masinal on tulemüüri reegel "allow-ICMP"
$B1M1_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if (Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSourceType GroupPolicy -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -Like "allow-ICMP"}) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M1_state -Task "B1.M1"

## B1.M2: 1.75% - Reverse tsoon on seadistatud ja kirjed loodud
$B1M2_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Resolve-DnsName 172.20.0.3).NameHost -eq "vlnd-srv.eestiasi.ee") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M2_state -Task "B1.M2"

## B1.M3: 1.50% - DNS nimelahendused on edasi suunatud
$B1M3_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-DnsServerForwarder).IPAddress.IPAddressToString -Contains "198.51.100.2") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M3_state -Task "B1.M3"

## B1.M4: 1.00% - Ebaturvalised tsooni uuendused on keelatud
$B1M4_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-DnsServerZone -ZoneName eestiasi.ee).DynamicUpdate -eq "Secure") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M4_state -Task "B1.M4"

# B1.M5: 0.50% - puhastus.ps1 skript töötab ilma veateadeteta
$B1M5_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'try { C:\puhastus.ps1; return 1 } catch { return 0 }'

Invoke-ScoreUpdate -Result $B1M5_state -Task "B1.M5"

## B1.M6: 2.00% - puhastus.ps1 skript eemaldab kasutajakontod
$B1M6_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-ADUser -Filter *).Count -lt 400) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M6_state -Task "B1.M6"

## B1.M7: 2.00% - kustutatud.txt sisaldab kustutatatud AD kontode logi
$B1M7_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-Content C:\kustutatud.txt | Measure-Object -Line).Lines -gt 100) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M7_state -Task "B1.M7"

## B1.M8: 0.50% - Alamvõrk on suurendatud
$B1M8_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((ipconfig | Select-String -Pattern "Subnet Mask") -Like "*255.255.255.240") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B1M8_state -Task "B1.M8"

## B1.M9: 0.50% - NTP serverina kasutatakse VLND-NTP serverit
$B1M9_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if (w32tm /query /configuration | Select-String -Pattern "172.20.0.7", "vlnd-ntp.eestiasi.ee" ) { return 1 } else { return 0 }' 

Invoke-ScoreUpdate -Result $B1M9_state -Task "B1.M9"


# VLND-DC2.EESTIASI.EE
## B2.M1: 1.00% - Server on seadistatud domeenikontrollerina
$B2M1_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-ADDomainController -Filter *).Name -Contains "VLND-DC2") { return 1 }'

Invoke-ScoreUpdate -Result $B2M1_state -Task "B2.M1"

## B2.M2: 1.50% - Serverile on liigutatud FSMO rollid
$B2M2_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-ADDomain).InfraStructureMaster -eq "vlnd-dc2.eestiasi.ee") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B2M2_state -Task "B2.M2"

## B2.M3: 0.50% - DNS serveri parameetrid on konfigureeritud
$B2M3_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if ((Get-DnsServerForwarder).IPAddress.IPAddressToString -Contains "198.51.100.2") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B2M3_state -Task "B2.M3"

## B2.M4: 0.50% - NTP serverina kasutatakse VLND-NTP serverit
$B2M4_state = Invoke-VmCommand -VmName "${vlnd_dc1}" -User "administrator" -UserPwd "Passw0rd$" `
    -Script 'if (w32tm /query /configuration | Select-String -Pattern "172.20.0.7", "vlnd-ntp.eestiasi.ee" ) { return 1 } else { return 0 }' 

Invoke-ScoreUpdate -Result $B2M4_state -Task "B2.M4"


# ZABBIX.EESTIASI.EE
## B3.M7: 0.50% - Alamvõrk on suurendatud
$B3M7_state = Invoke-VmCommand -VmName "${zabbix}" `
    -Script 'if [ "$(ip -o -f inet addr show | awk ""/scope global/ {print $4}"" | grep 172.20.0.4/28)" == "172.20.0.4/28" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B3M7_state -Task "B3.M7"

# VLND-WWW.EESTIASI.EE
## B4.M1: 0.75% - LVM volüüm on konfigureeritud
$B4M1_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'sudo pvdisplay -C -o pv_name,vg_name -S pvname=/dev/sdb'

if ($B4M1_state -Like "Fail -*") {
    Write-Host $B4M1_state

    Invoke-ScoreUpdate -Task "B4.M1" -Status "NOT OK" -Default:$False
} elseif ($B4M1_state -Like "*dev*") {
    Invoke-ScoreUpdate -Task "B4.M1" -Status "OK" -Default:$False
} else {
    Invoke-ScoreUpdate -Task "B4.M1" -Status "NOT OK" -Default:$False
}

## B4.M2: 1.25% - /var/www mount on püsiv
$B4M2_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ "$(sudo cat /etc/fstab | grep -o "/var/www")" == "/var/www" ]; then if [ "$(mount -a)" == "" ]; then echo 1; else echo 0; fi; else echo 0; fi'

Invoke-ScoreUpdate -Result $B4M2_state -Task "B4.M2"

## B4.M3: 0.75% - TRT-WWW veebiserveri sisu on kolitud
$B4M3_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ "$(cat "$(sudo find /var/www 2> /dev/null | grep wp-config.php)" | grep -o "wordpress_user")" == "wordpress_user" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B4M3_state -Task "B4.M3"

## B4.M4: 1.25% - TRT-WWW andmebaas on kolitud
$B4M4_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ $(mysql wordpress_db -u wordpress_user -pPassw0rd$ -se "SELECT user_email FROM wp_users" | grep root) == "root@eestiasi.ee" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B4M4_state -Task "B4.M4"

## B4.M5: 1.00% - Lõppkasutajal avaneb http://www.eestiasi.ee
$B4M5_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ "$(curl -s -k -L http://www.eestiasi.ee | grep -o "wordpress.org")" == "wordpress.org" ]; then echo 1; else 0; fi'

Invoke-ScoreUpdate -Result $B4M5_state -Task "B4.M5"

# B4.M6: 1.50% - VLND-SRV veebiserveri pihta on konfigureeritud veebiproksi
$B4M6_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ "$(curl -m 5 -s -L -k www.eestiasi.ee:8080)" == "$(curl -m 5 -s 172.20.0.6)" ] && [ "$(curl -m 5 -s -L -k www.eestiasi.ee:8080)" != "" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B4M6_state -Task "B4.M6"

## B4.M7: 1.50% - HTTPS tugi on seadistatud ja loodud suunamised
$B4M7_state = Invoke-VmCommand -VmName "${vlnd_www}" `
    -Script 'if [ "$(timeout 5 openssl 2>/dev/null s_client -connect www.eestiasi.ee:443 </dev/null | openssl x509 -text | grep Issuer | grep -o meister)" == "meister" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B4M7_state -Task "B4.M7"

# VLND-SRV.EESTIASI.EE
## B5.M1: 0.50% - IIS veebiserver on konfigureeritud
$B5M1_state = Invoke-VmCommand -VmName "${vlnd_srv}" `
    -Script 'if ((Get-WindowsFeature Web-Server).InstallState -Like "Installed") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B5M1_state -Task "B5.M1"

## B5.M2: 1.00% - IIS veebiserver on kättesaadav ainult VLND-WWW serverile
if ($B5M1_state -Like "*1*" ) {
    $B5M2_state = Invoke-VmCommand -VmName "${vlnd_pc2}" `
        -Script 'if curl -sL --fail http://172.20.0.6 --max-time 2 -o /dev/null; then echo 0; else echo 1; fi'
    
    Invoke-ScoreUpdate -Result $B5M2_state -Task "B5.M2"
} else {
    Invoke-ScoreUpdate -Status "NOT OK" -Task "B5.M2"
}

## B5.M3: 1.50% - DHCP teenuse on kolitud OPNsense-st
$B5M3_state = Invoke-VmCommand -VmName "${vlnd_srv}" `
    -Script 'if ((Get-DhcpServerv4Scope).StartRange -eq "172.20.0.11") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B5M3_state -Task "B5.M3"

## B5.M4: 1.50% - iSCSI Target Server on konfigureeritud
$B5M4_state = Invoke-VmCommand -VmName "${vlnd_srv}" `
    -Script 'if (((Get-IscsiServerTarget).LunMappings).TargetName -like "*ntp*") { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B5M4_state -Task "B5.M4"

# VLND-NTP.EESTIASI.EE
## B6.M1: 0.50% - Kella sünkroonitakse ISP NTP serverilt
$B6M1_state = Invoke-VmCommand -VmName "${vlnd_ntp}" `
    -Script 'if [ "$(chronyc sources 2>/dev/null | grep -o "198.51.100.4")" == "198.51.100.4" ] || [ "$(ntpq -p 2>/dev/null | grep -o "198.51.100.4" | head -n 1)" == "198.51.100.4" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B6M1_state -Task "B6.M1"

## B6.M2: 0.50% - Kellaserver on seadistatud
$B6M2_state = Invoke-VmCommand -VmName "${vlnd_ntp}" `
    -Script 'if [ "$(netstat -dulpn 2>/dev/null | grep -o :123 | head -n 1)" == ":123" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B6M2_state -Task "B6.M2"

## B6.M3: 1.00% - iSCSI Initiator on konfigureeritud ja mountitud /backups kausta
$B6M3_state = Invoke-VmCommand -VmName "${vlnd_ntp}" `
    -Script 'if [ "$( df | grep -o "/backups")" == "/backups" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B6M3_state -Task "B6.M3"

## B6.M4: 1.00% - /backups kausta on tehtud NTP konfiguratsiooni varundus
# backups kaustas on midagi, mis sisaldab ntp'd 
$B6M4_state = Invoke-VmCommand -VmName "${vlnd_ntp}" `
    -Script 'if [ "$(sudo cat /backups/* 2>/dev/null | grep -o driftfile)" == "driftfile" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B6M4_state -Task "B6.M4"

# VLND-MAIL.EESTIASI.EE
## B7.M1: 1.00% - Postfix ja Dovecot teenused on kolitud
$B7M1_state = Invoke-VmCommand -VmName "${vlnd_mail}" `
    -Script 'if [ "$(sudo cat /etc/dovecot/conf.d/10-ssl.conf | grep "ssl_key =")" == "ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B7M1_state -Task "B7.M1"

## B7.M2: 1.00% - Kasutajakontod on kolitud
$B7M2_state = Invoke-VmCommand -VmName "${vlnd_mail}" -User "mia" -UserPwd "edasitagasi" `
    -Script 'if [ "$(ip a | grep -o 172.20.0.10)" == "172.20.0.10" ]; then echo 1; else echo 0; fi'

Invoke-ScoreUpdate -Result $B7M2_state -Task "B7.M2"

# VLND-PC1.EESTIASI.EE
## B9.M1: 0.50% - Masin on liidetud domeeni eestiasi.ee
$B9M1_state = Invoke-VmCommand -VmName "${vlnd_pc1}" -User "meister" -UserPwd "Passw0rd$" `
-Script 'if ((gwmi win32_computersystem).partofdomain -eq $true) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B9M1_state -Task "B9.M1"

## B9.M2: 0.50% - Masinal on tulemüüri reegel "deny-RDP"
$B9M2_state = Invoke-VmCommand -VmName "${vlnd_pc1}" -User "meister" -UserPwd "Passw0rd$" `
    -Script 'if (Get-NetFirewallRule -PolicyStore ActiveStore -PolicyStoreSourceType GroupPolicy -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -Like "deny-RDP"}) { return 1 } else { return 0 }'

Invoke-ScoreUpdate -Result $B9M2_state -Task "B9.M2"
