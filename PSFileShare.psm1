#Load manifest data
$ManifestPath = "PSFileShare.psd1"
$GLOBAL:ManifestData = Import-LocalizedData -FileName $ManifestPath

<#
    .SYNOPSIS
        New-FileShareFile

    .DESCRIPTION
        Create new file share file. 

    .PARAMETER Path
        Define file path used for export. 

    .PARAMETER ExcludeShares
        List all share you want to exclude from report.

    .EXAMPLE
        PS C:\> New-FileShareFile -Path "D:\MySharesProject"

    .EXAMPLE
        PS C:\> New-FileShareFile -Path "D:\MySharesProject" -ExcludeShares 'ADMIN$','C$','D$','print$'

    .INPUTS
        System.String,System.Array

    .OUTPUTS
        System.File

    .NOTES
        Atuhor: Jessy DESLOGES
        Date: 12/03/20
#>
Function New-FileShareFile
{
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory = $true)] 
        [string] $Path,
        [array] $ExcludeShares = @('ADMIN$', 'C$', 'D$', 'print$', 'IPC$')
    )
   
    Try	
    {
        $Shares = Get-CimInstance -Class Win32_Share | ? { $_.Name -notin $ExcludeShares }
        Write-Verbose "Number of shares found : $($Shares.count) !"

        $Shares

        If (!(Test-Path $Path)) {New-Item $Path -ItemType Directory -Force | Out-Null}
        $Shares | select Name, Path | ConvertTo-Json | Out-File "$Path\shares_$($env:COMPUTERNAME).json" -Force
    }
    Catch
    {
        Write-Host -ForegroundColor Red "ERROR: $($_) (see details below)." -BackgroundColor Black
        Write-Host -ForegroundColor Red "ERROR: [$($_.InvocationInfo.ScriptLineNumber)] $($_.InvocationInfo.ScriptName) >> " -BackgroundColor Black -NoNewline
        Write-Host -ForegroundColor White "$($_.InvocationInfo.Line.TrimStart())" -BackgroundColor Black
        [array]$GLOBAL:ErrorHashtable = @{Error = $($_); FilePath = $($_.InvocationInfo.ScriptName) ; FileLineNumber = $($_.InvocationInfo.ScriptLineNumber) ; FileLineDetails = $($_.InvocationInfo.Line).TrimStart() ; Command = $($_.InvocationInfo.MyCommand) }
    }
}

<#
    .SYNOPSIS
        Get-FileShareInfos

    .SYNOPSIS
        Get-FileShareInfos

    .DESCRIPTION
        Get all file shares informations (Name, Path, Size, Number of files and folders)

    .PARAMETER InputFile
        Import shares_COMPUTERNAME.json file created with New-FileShareFile cmdlet.

    .PARAMETER OutputPath
        Define CSV file path used for export.

    .PARAMETER ExcludeShares
        List all share you want to exclude from report.

    .PARAMETER First
        Return only x first shares specified by this parameter 

    .EXAMPLE
        C:\PS> Get-FileShareInfos -InputFile "D:\MySharesProject\shares_COMPUTERNAME.json"-OutputPath "D:\MySharesProject"

    .EXAMPLE
        C:\PS> Get-FileShareInfos -InputFile "D:\MySharesProject\shares_COMPUTERNAME.json"-OutputPath "D:\MySharesProject" -ExcludeShares 'ADMIN$','C$','D$','print$' -First 10 -Verbose

    .INPUTS
        System.String,System.Array,System.Int

    .OUTPUTS
        System.File
    
    .NOTES
    Atuhor: Jessy DESLOGES
    Date: 12/03/20
#>
Function Get-FileShareInfos
{
    [CmdletBinding()]
    Param 
    (
        [Parameter(Mandatory = $true)] 
        [string] $InputFile,
        [Parameter(Mandatory = $true)] 
        [string] $OutputPath,
        [array] $ExcludeShares = @('ADMIN$', 'C$', 'D$', 'print$', 'IPC$'),
        [int] $First = 0
    )
    
    Try	
    {
        If (Test-Path $InputFile)
        {
            If (!(Test-Path $OutputPath)) { New-Item $OutputPath -ItemType Directory -Force | Out-Null }
            Start-Transcript -Path "$OutputPath\$(Split-Path $InputFile -LeafBase)_transcript_$(Get-Date -Format yyyyMMdd_HHmmss).log"

            $Title = "$($ManifestData.Description) v$($ManifestData.ModuleVersion) - $($ManifestData.Author)"
            Write-Verbose "**********************"
            Write-Verbose $Title
            Write-Verbose "**********************"
            Write-Verbose "START $(Get-Date)"

            Write-Verbose "[$(Get-Date)] Getting file share file $InputFile ..."
            $Shares = Get-Content $InputFile | ConvertFrom-Json

            #$Shares = Get-CimInstance -Class Win32_Share | ? { $_.Name -notin $ExcludeShares }
            Write-Verbose "[$(Get-Date)] Number of shares found : $($Shares.count) !"

            If ($First -le 0)
            {
                # All Shares
                Write-Verbose "MODE ALL SHARES"
                $i = 0
                ForEach ($Share in $Shares)
                {
                    # Get memory usage
                    $Memory = Test-MemoryUsage
                    Write-Verbose "[$(Get-Date)] MEMORY : Status $($Memory.Status) - $($Memory.FreeGB)/$($Memory.TotalGB)GB ($($Memory.PctFree)% Free)"

                    Write-Verbose "[$(Get-Date)] Getting $($Share.Name)..."
                    $i++
                    $Total = $Shares.count
                    $Percent = [math]::Round(($i / $Total * 100))
                    Write-Progress -Id 0 -Activity $Title -CurrentOperation "[$i/$Total] $($Share.Name)" -PercentComplete $Percent -Status "$Percent%"
                    $SharePath = $Share.Path
                    If ($SharePath.Length -ge 260)
                    {
                        Write-Warning "Skip $($Share.Name) because is greater than 260 characters ($($SharePath.Length))"
                    }
                    #For test purpose only
                    #$SharePath = 'X:\TEST'
                    $ShareItems = Get-ChildItem $SharePath -Force -Recurse -ErrorAction SilentlyContinue
                    $ShareRequestState = $?
                    If ($ShareRequestState)
                    {
                        Write-Verbose "[$(Get-Date)] No errror detected."
                        Write-Verbose "[$(Get-Date)] Counting number of folders ..."
                        $Folders = ($ShareItems | ? { $_.PSIsContainer -eq $true }).Count
                        Write-Verbose "[$(Get-Date)] Counting number of files ..."
                        $Files = ($ShareItems | ? { $_.PSIsContainer -eq $false }).Count
                        Write-Verbose "[$(Get-Date)] Measuring size ..."
                        If ($Files -ne 0) { $ShareSize = ($ShareItems | Measure-Object -Sum Length).Sum } Else { Write-Verbose "[$(Get-Date)] No files found."; $ShareSize = 0}
                        Write-Verbose "[$(Get-Date)] Creating share infos object ..."
                        [array]$ShareInfos += [pscustomobject]@{Name = $Share.Name; Path = $SharePath; Size = ("{0:N2}" -f ($ShareSize /1GB) + "GB"); Files = $Files; Folders = $Folders }
                    }
                    Else
                    {
                        Write-Verbose "[$(Get-Date)] Error detected !"
                        [array]$ShareErrors += [pscustomobject]@{ Name = $Share.Name; Path = $SharePath; Error = $Error[0].Exception.Message ; Timestamp = (Get-Date).ToString() }
                    }
                }
            }
            Else 
            {
                # First Shares
                Write-Verbose "MODE FIRST SHARES ($First first shares)"
                For ($i = 0 ; $i -le $First - 1 ; $i++)
                {
                    # Get memory usage
                    $Memory = Test-MemoryUsage
                    Write-Verbose "[$(Get-Date)] MEMORY : Status $($Memory.Status) - $($Memory.FreeGB)/$($Memory.TotalGB)GB ($($Memory.PctFree)% Free)"

                    If ($i -ge $Shares.count) { break }
                    Write-Verbose "[$(Get-Date)] Getting share $($i+1) : $($Shares[$i].Name)..."
                    $Total = $First
                    $Percent = [math]::Round((($i + 1) / $Total * 100))
                    Write-Progress -Id 0 -Activity $Title -CurrentOperation "[$($i+1)/$Total] $($Shares[$i].Name)" -PercentComplete $Percent -Status "$Percent%"
                    Start-Sleep -Seconds 2
                    $SharePath = $Shares[$i].Path
                    If ($SharePath.Length -ge 260)
                    {
                        Write-Warning "Skip $($Shares[$i].Name) because is greater than 260 characters ($($SharePath.Length))"
                    }
                    $ShareItems = Get-ChildItem $SharePath -Force -Recurse -ErrorAction SilentlyContinue
                    $ShareRequestState = $?
                    If ($ShareRequestState)
                    {
                        Write-Verbose "[$(Get-Date)] No errror detected."
                        Write-Verbose "[$(Get-Date)] Counting number of folders ..."
                        $Folders = ($ShareItems | ? { $_.PSIsContainer -eq $true }).Count
                        Write-Verbose "[$(Get-Date)] Counting number of files ..."
                        $Files = ($ShareItems | ? { $_.PSIsContainer -eq $false }).Count
                        Write-Verbose "[$(Get-Date)] Measuring size ..."
                        If ($Files -ne 0) { $ShareSize = ($ShareItems | Measure-Object -Sum Length).Sum } Else { Write-Verbose "[$(Get-Date)] No files found."; $ShareSize = 0 }
                        Write-Verbose "[$(Get-Date)] Creating share infos object ..."
                        [array]$ShareInfos += [pscustomobject]@{Name = $Shares[$i].Name; Path = $SharePath; Size = ("{0:N2}" -f ($ShareSize /1GB) + "GB"); Files = $Files; Folders = $Folders }
                    }
                    Else
                    {
                        Write-Verbose "[$(Get-Date)] Error detected !"
                        [array]$ShareErrors += [pscustomobject]@{ Name = $Shares[$i].Name; Path = $SharePath; Error = $Error[0].Exception.Message ; Timestamp = (Get-Date).ToString() }
                    }
                }
            }

            $ShareInfos
            Write-Verbose "[$(Get-Date)] Exporting csv file to $OutputPath ..."
            If ($ShareInfos) { $ShareInfos | Export-Csv -Path "$OutputPath\$(Split-Path $InputFile -LeafBase).csv" -Force -NoTypeInformation}
            Write-Verbose "[$(Get-Date)] Exporting $($ShareErrors.count) errors to $OutputPath ..."
            If ($ShareErrors) { $ShareErrors | ConvertTo-Json | Out-File "$OutputPath\$(Split-Path $InputFile -LeafBase)_errors_$(Get-Date -Format yyyyMMdd_HHmmss).json" -Append }
        }
        Else { Write-Warning "[$(Get-Date)] InputFile path invalid ($InputFile)"}        
    }
    Catch
    {
        Write-Host -ForegroundColor Red "ERROR: $($_) (see details below)." -BackgroundColor Black
        Write-Host -ForegroundColor Red "ERROR: [$($_.InvocationInfo.ScriptLineNumber)] $($_.InvocationInfo.ScriptName) >> " -BackgroundColor Black -NoNewline
        Write-Host -ForegroundColor White "$($_.InvocationInfo.Line.TrimStart())" -BackgroundColor Black
        [array]$GLOBAL:ErrorHashtable = @{Error = $($_); FilePath = $($_.InvocationInfo.ScriptName) ; FileLineNumber = $($_.InvocationInfo.ScriptLineNumber) ; FileLineDetails = $($_.InvocationInfo.Line).TrimStart() ; Command = $($_.InvocationInfo.MyCommand) }
    }
    Finally
    {
        Write-Verbose "END $(Get-Date)"
        Stop-Transcript
    }
}

Function Test-MemoryUsage
{
    [cmdletbinding()]
    Param()
 
    $os = Get-CimInstance Win32_OperatingSystem -Verbose:$false
    $pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100, 2)
 
    if ($pctFree -ge 45)
    {
        $Status = "OK"
    }
    elseif ($pctFree -ge 15 )
    {
        $Status = "Warning"
    }
    else
    {
        $Status = "Critical"
    }
 
    $os | Select @{Name = "Status"; Expression = { $Status } },
    @{Name = "PctFree"; Expression = { $pctFree } },
    @{Name = "FreeGB"; Expression = { [math]::Round($_.FreePhysicalMemory/1mb, 2) } },
    @{Name = "TotalGB"; Expression = { [int]($_.TotalVisibleMemorySize/1mb) } }
 
}

# Aliases
New-Alias Export-FileShareInfos Get-FileShareInfos