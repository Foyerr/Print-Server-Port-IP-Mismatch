Function BackUp-Registry(){
    Reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print\Printers" .\PrinterListBak.reg
    Reg export "HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\ports" .\MonitorPortBak.reg
}

Function Get-PrinterIP{

    $list=@()
    $portname = Get-Printer *

    foreach($i in $portname) {

        try{
            $Printer=$(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$($i.Name)")
            $OldPortName=$Printer.port
     
            $MonitorKey=$(REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\ports\$($OldPortName)" /V "Hostname" 2>$null).split("    ")
            $RealIP=$MonitorKey[16]

        }catch{
            $RealIP=""
            $OldPortName=""
            write-host("Error on $($i.Name)")
        }

        $list += $(""|select-object @{n="PrinterName";e={$i.Name}},@{n="Location";e={$i.Location}},@{n="Real IP";e={$RealIP}},@{n="DisplayedPort";e={($OldPortName)}})
    }
    return($list)
}

Function Set-PrinterIP($printerList){
    $ans='y'
    foreach($i in $printerList){
        if($i.DisplayedPort -ne $i."Real IP" -AND $i."Real IP" -ne ""){

            #Confirm one at a time or all
            if($ans.ToLower() -eq 'y'){
                Write-Host "Change $($i.PrinterName,$i.DisplayedPort) to $($i."Real IP")"
                $ans=Read-host "[Y] Yes  [A] Yes to All  [H] Halt Command (Default: H)"
                
                #If not entered, set to y
                if ([string]::IsNullOrWhiteSpace($ans)){
                    $ans='h'
                }
            }
            #if not y or a break the loop
            if($ans.ToLower() -notin @("y","a")){break}

            
            #Change Current Port Name to new IP
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$($i.PrinterName)" -Name port -value $i."Real IP"
        
            #Change monitor key name to new port name
            Rename-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Standard TCP/IP Port\Ports\$($i.DisplayedPort)" -NewName $i."Real IP"
        }
    }
}

BackUp-Registry

$printerList = Get-PrinterIP

Set-PrinterIP $printerList

Restart-Service -Force Spooler -confirm


