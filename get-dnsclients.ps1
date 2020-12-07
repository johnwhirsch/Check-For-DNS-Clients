param([Parameter(Mandatory=$True)][string]$logfile,[switch]$FindUnpopular=$false,[array]$CustomIgnores)

$Verbose                 = $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent
$assetsDirectory         = "$($PSScriptRoot)\get-dnslog\assets"
$PopularFilePath         = "$($PSScriptRoot)\get-dnslog\assets\top-1m.csv"
$CustomIgnoreFilePath    = "$($PSScriptRoot)\get-dnslog\assets\CustomIgnore.csv"
$UnPopularFilePath       = "$($PSScriptRoot)\get-dnslog\UnpopularDNSqueries.csv"
$DNSClientsFilePath      = "$($PSScriptRoot)\get-dnslog\DNSClients.csv"

$dnsclients              = @()
$UnPopularQueries        = @()

if($logfile -like "\\*"){ $log = Get-Content "Microsoft.PowerShell.Core\FileSystem::$($logfile)" }
else{ $log = Get-Content $logfile }

if(!(Test-Path $PopularFilePath) -and $FindUnpopular){ 
    Write-Host "Aquiring Cisco Umbrella Top 1 Million Domains List..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip" -OutFile "$($PSScriptRoot)\top-1m.csv.zip"
    Expand-Archive -Path "$($PSScriptRoot)\top-1m.csv.zip" -DestinationPath $assetsDirectory
    Remove-Item -Path "$($PSScriptRoot)\top-1m.csv.zip"

    try { Test-Path $PopularFilePath  }
    catch { Write-Error "Error downloading Cisco Umbrella Top 1 Million Domains List... `n`n $Error" }

}

if(!(Test-Path $CustomIgnoreFilePath)){
        $ignoreList = @("$($(Get-ADDomain).forest)","$($(Get-ADDomain).DNSRoot)",".arpa")
        $ignoreList = $ignoreList | Select-Object @{Name='IgnoredURL';Expression={$_}}
        $ignoreList | Export-Csv -path $CustomIgnoreFilePath
}
if((Test-Path $CustomIgnoreFilePath) -and $CustomIgnores.count -gt 0){
    $ExistingCustomIgnores = Import-Csv $CustomIgnoreFilePath

    foreach($CustomIgnore in $CustomIgnores){
        if($CustomIgnore -match "(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]"){
            $ignore = $true;                
            $ExistingCustomIgnores | %{ if($CustomIgnore -match [regex]::escape($_.IgnoredURL)){ $ignore = $false; } }
            if($ignore){
                Write-Host "Adding custom ignore: $CustomIgnore" -ForegroundColor Cyan
                $data = @()
                $row = New-Object PSObject
                $row | Add-Member -MemberType NoteProperty -Name "IgnoredURL" -Value $CustomIgnore
                $data += $row
                $data | Export-Csv -path $CustomIgnoreFilePath -Append
            }
        }
    }
    $ignoreList = Import-Csv $CustomIgnoreFilePath 
}

if($FindUnpopular){
    Write-Host "Loading Cisco Umbrella Top 1 Million Domains List into memory, this might take ~30 seconds..." -ForegroundColor Cyan
    
    try{ $PopularArray = Import-Csv $PopularFilePath -Header "RANK","URL" | select -ExpandProperty URL }
    catch { Write-Error "Error loading Cisco Umbrella Top 1 Million Domains List... `n`n $Error" }    

    Write-Host "Ignoring the following matches during search:" -ForegroundColor Cyan
    Import-Csv $CustomIgnoreFilePath | % { Write-Host "$($_.IgnoredURL); " -ForegroundColor Cyan -NoNewline }
    Write-Host "`n---------------------------------------------------------------------";

    
}

if(Test-Path $UnPopularFilePath){ Remove-Item -Path $UnPopularFilePath }
if(Test-Path $DNSClientsFilePath){ Remove-Item -Path $DNSClientsFilePath }


function checkPopularity {
    
    param([Parameter(Mandatory=$true)][string]$url)

    if($PopularArray -eq $url){ return $true; }else{ return $false; }

}

foreach($line in $log){
    
    if($line -match "(UDP Rcv [0-9\.\:]+[A-Za-z0-9\s]+[\[\]A-Z0-1\s]+[\(\)\-A-Za-z0-9]+)"){ 
    
        $datapattern = '(UDP Rcv )([0-9\.\:]+)(\s+[A-Za-z0-9]+\s+)([A-Za-z]?\s+[A-Za-z])(\s)(\[[A-Za-z0-1\s]+\])(\s+)([A-Za-z]+)(\s+)([\(\)\-`_A-Za-z0-9]+)'

        $linedata = [regex]::Matches($line, $datapattern)

        # Leaving these here for future additions to the script(maybe)
        # Additional info can be added to the propsout array if desired
        
        if($linedata.groups.count -eq 11){

            $PacketType          = $linedata.Groups[1]
            $ClientIP            = $linedata.Groups[2]
            $QueryType           = $linedata.Groups[4]
            $QueryResponseStatus = $linedata.Groups[6]
            $QueryResponseType   = $linedata.Groups[8]
            $Query               = ($linedata.Groups[10] -replace "(\([0-9]+\))", ".").TrimStart(".").trimEnd(".")

            $addIP = $true

            foreach($existingclient in $dnsclients){ if($ClientIP -match $($existingclient.ClientIP)){ $addIP = $false } }

            if($addIP){
                if($ClientIP -match "::1"){ $ClientHostname = "localhost" }
                else{
                    try{ $ClientHostname = ([system.net.dns]::GetHostByAddress($ClientIP)).hostname }
                    catch { $ClientHostname = "Cannot Resolve Hostname" }
                }
                $entry = @()
                $propsout            = @{
                                        ClientIP        = $ClientIP
                                        ClientHostname  = $ClientHostname
                                     }
                $objout              = New-Object -TypeName psobject -Property $propsout 
                $entry += $objout                                     
                $entry | Export-Csv -Path $DNSClientsFilePath -Append    
                
                $dnsclients += $objout    
            }

            if($FindUnpopular){
                $ignore = $true;               
                $ignoreList | %{ if($Query -match [regex]::escape($_.IgnoredURL)){ $ignore = $false; } }
                
                #Write-Host "IP: $ClientIP | Host name: $($dnsclients | ? { $_.ClientIP -eq $ClientIP })"

                if($ignore -and $Query -match "(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]"){                    
                    
                    if($ClientIP -match "::1"){ $ClientHostname = "localhost" }
                    else{
                        try{ $ClientHostname = $($dnsclients | ? { $_.ClientIP -like $ClientIP }).ClientHostname }
                        catch { $ClientHostname = "Cannot Resolve Hostname" }
                    }
                    
                    if($Verbose){ Write-Host "Found parsable domain DNS Query for: $Query" -ForegroundColor Cyan }

                    if(!(checkPopularity -url $query)){
                        Write-Host "Found unpopular domain: " -ForegroundColor White -NoNewline
                        Write-Host $Query -ForegroundColor Red -NoNewline
                        Write-Host " [ClientHostname: " -NoNewline
                        Write-Host $ClientHostname -ForegroundColor Cyan -NoNewline
                        Write-Host " | IP: " -NoNewline
                        Write-Host $ClientIP -ForegroundColor Cyan -NoNewline
                        Write-Host " | Request Type: " -NoNewline
                        Write-Host $QueryResponseType -ForegroundColor Cyan -NoNewline
                        Write-Host "]"
                        $entry = @()
                        $propsout = @{
                                        ClientIP          = $ClientIP
                                        ClientHostname    = $ClientHostname
                                        Query             = $Query
                                        QueryResponseType = $QueryResponseType
                                    }
                        $objout = New-Object -TypeName psobject -Property $propsout 
                        $entry += $objout                     
                        $entry | Export-Csv -Path $UnPopularFilePath -Append

                        $UnPopularQueries += $objout   

                    } # EO if checkunpopularity


                }# EO if ignore

            } # EO if findunpopular

        } # EO if linedata gt 5         
    }
}

if($FindUnpopular){ 
    
    if($UnPopularQueries -gt 0){

        $UnpopularClients = @()

        foreach($dnsclient in $dnsclients){

            $UnpopularEntries = $UnpopularQueries | ? { $_.ClientIP -eq $dnsclient.ClientIP }

            if($UnpopularEntries.count -gt 0){
                $propsout         = @{
                                        ClientIP            = $dnsclient.ClientIP
                                        ClientHostname      = $dnsclient.ClientHostname
                                        UnpopularQueryCount = $UnpopularEntries.count
                                    }
                $objout            = New-Object -TypeName psobject -Property $propsout 
                $UnpopularClients  += $objout
            }

        }
        $UnpopularClients | Sort-Object ClientHostname | Select-Object ClientHostname,ClientIP,UnpopularQueryCount | FT
    }else{ Write-Host "No unpopular DNS lookups preformed" -ForegroundColor Cyan; }
}
else{ $dnsclients | Sort-Object ClientHostname | FT }
