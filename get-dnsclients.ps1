param([Parameter(Mandatory=$True)][string]$logfile)

if($logfile -like "\\*"){ $log = Get-Content "Microsoft.PowerShell.Core\FileSystem::$($logfile)" }
else{ $log = Get-Content $logfile }

$dnsclients = @()

foreach($line in $log){
    
    if($line -match "(UDP Rcv [0-9\.]+[A-Za-z0-9\s]+[\[\]A-Z0-1\s]+[\(\)\-A-Za-z0-9]+)"){ 
    
        $datapattern = '(UDP Rcv )([0-9\.]+)(\s+[A-Za-z0-9]+\s+)([A-Za-z]?\s+[A-Za-z])(\s)(\[[A-Za-z0-1\s]+\])(\s+)([A-Za-z]+)(\s+)([\(\)\-`_A-Za-z0-9]+)'

        $linedata = [regex]::Matches($line, $datapattern)

        # Leaving these here for future additions to the script(maybe)
        # Additional info can be added to the propsout array if desired

        $PacketType          = $linedata.Groups[1]
        $ClientIP            = $linedata.Groups[2]
        $QueryType           = $linedata.Groups[4]
        $QueryResponseStatus = $linedata.Groups[6]
        $QueryResponseType   = $linedata.Groups[8]
        $Query               = ($linedata.Groups[10] -replace "(\([0-9]+\))", ".").TrimStart(".")

        $addIP = $true

        foreach($existingclient in $dnsclients){ if($ClientIP -match $($existingclient.ClientIP)){ $addIP = $false } }

        if($addIP){
            $ClientHostname = ([system.net.dns]::GetHostByAddress($ClientIP)).hostname
            $propsout            = @{
                                    ClientIP        = $ClientIP
                                    ClientHostname  = $ClientHostname
                                 }
            $objout              = New-Object -TypeName psobject -Property $propsout 
            $dnsclients          += $objout               
        }            
    }
}

$dnsclients | Sort-Object ClientHostname | FT
