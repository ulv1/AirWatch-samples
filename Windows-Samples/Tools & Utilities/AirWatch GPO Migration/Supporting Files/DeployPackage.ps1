# Includes
#. "$PSScriptRoot\Logging.ps1"

function Write-Log {
    Param (
        [Parameter(Mandatory=$False)]
        [string]$logType = "Info",
        [Parameter(Mandatory=$True)]
        [string]$logString
    )
    
    $logDate = Get-Date -UFormat "%Y-%m-%d"
    $datetime = (Get-Date).ToString()

    #$logPath = "$([environment]::GetFolderPath("MyDocuments"))\AirWatch GPO\logs"
    #$logPath = "$PSScriptRoot\logs"
    $logPath = "$($env:ProgramData)\AirWatch\GPOs"
    if (!(Test-Path -Path $logPath)) { New-Item -Path $logPath -ItemType Directory | Out-Null }
     
    $logfilePath = "$logPath\log-$logDate.txt"
    "$dateTime | $logType | $logString" | Out-File -FilePath $logfilePath -Append
}

function MAIN {
    $result = 0
    try {
        Write-Log -logString "DeployPackage MAIN started"

        $lgpoPath = "LGPO.exe"
        $deployCsvPath = "$PSScriptRoot\DeployPackage.csv"
        $gpoResultsFilepath = "$PSScriptRoot\lgpoResults.csv"

        # If the DeployPackage.csv 
        if (!(Test-Path -Path $deployCsvPath)) {
            $result = 1
            Write-Log -logString "DeployPackage deployCsvPath '$deployCsvPath' is missing - stopping!"
            return $result
        }

        # Import the GPOs from our .csv notifying which GPO backups to apply and in which order
        $GPOs = Import-Csv -Path "$PSScriptRoot\DeployPackage.csv" -Delimiter ','
        Write-Log -logString "DeployPackage GPOs = $GPOs"

        # Add a 'completed' property for each GPO object the script will process for the CSV that will be used
        # to detect if the install has finished
        $GPOs | ForEach-Object -Process {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name completed -Value $false
        }
        Write-Log -logString "DeployPackage Finished adding completed property to GPOs"

        $GPOs | Export-Csv -Path $gpoResultsFilepath -Force
        Write-Log -logString "DeployPackage Finished updating lgpoResults.csv"

        # Attempt to import the GPO Backup using LGPO.exe and update the CSV each time it finishes running
        $GPOs | ForEach-Object -Process {
            $params = "/g ""$($_.filename)"""
            Write-Log -logString "DeployPackage Running: $lgpoPath $params in directory '$PSScriptRoot'"
            #Start-Process $lgpoPath $params -Wait -Verb runas
            Start-Process $lgpoPath $params -PassThru -Verb runas -WorkingDirectory $PSScriptRoot

            $_.completed = $true
            Write-Log -logString "DeployPackage '$($_.filename)' completed: $($_.completed)"
            $GPOs | Export-Csv -Path $gpoResultsFilepath -Force
        }
    }
    catch {
        $result = 1
        Write-Log -logString "DeployPackage ERROR = $PSItem"
    }

    Write-Log -logString "DeployPackage result = $result"
    return $result
}

$code = MAIN
echo $code
EXIT $code