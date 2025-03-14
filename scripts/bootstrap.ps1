param (
    [Parameter()]
    [ValidateRange(1, 64)]
    [Alias("GroupId")]
    [Int] $GroupNumber = 1,

    [Parameter()]
    [ValidateRange(1, 32)]
    [Alias("Labs")]
    [Int] $NumberOfNestedLabs = 6,

    [Parameter()]
    [Alias("IsAzureGovernment")] 
    [switch] $isMAG = $false,

    [Parameter()]
    [Alias("IsAutomated")] 
    [switch] $automated = $false
)

# constant variables
$Logfile = "C:\temp\bootstrap.log"
$TempPath = "C:\temp"
$MainBootstrapScriptURL = "https://raw.githubusercontent.com/Azure/avslabs/main/scripts/bootstrap.ps1"
$BootstrapScriptURL = "https://raw.githubusercontent.com/Azure/avslabs/main/scripts/bootstrap-nestedlabs.ps1"
$PackageURL = "https://avslabspremium.blob.core.windows.net/vmware-nested-lab/avs-embedded-labs-auto.zip"
#$NumberOfNestedLabs = 6

# initializing

# clear log file
<#
if (Test-Path $LogFile) {
    Clear-Content $LogFile
}
#>

# auxiliary functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [String]$message
    )
    $timeStamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $logMessage = "[$timeStamp] $message"
    Add-content $LogFile -value $LogMessage
    if (-not($IsAuto)) {
        Write-Host $logMessage
    }
}

function Test-TempDirectory {

    if (-Not $(Test-Path -Path $TempPath)) {
        [void] (New-Item -Path $TempPath -ItemType Directory -Force)
    }
}

#-------------------------------------------------------------------------------------------------------#

function Disable-IEESC {

    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
    #Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Install-Applications {

    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    choco install powershell-core -y
    choco install azcopy10 -y
    choco install azure-cli -y
    choco install 7zip -y
    choco install VMRC -y

    # Optional
    #choco install vscode -y
    #choco install microsoftazurestorageexplorer -y
    #choco install microsoft-windows-terminal -y

    # Future Use
    #choco upgrade all -y

    #refreshenv

    Write-Log "|--Install-Applications - Used Choco to install: PowerShell-Core, AzCopy, AzCli, 7zip and VMRC"
}

function Get-BootstrapScript {
    $MainBootstrapFileName = $MainBootstrapScriptURL.Split('/')[-1]
    $MainBootstrapPackagePath = Join-Path $TempPath $MainBootstrapFileName
    
    if (Test-Path $MainBootstrapPackagePath -PathType Leaf) {
        Write-Log "|--Get-BootstrapScript - Nested labs bootstrap script 'bootstrap.ps1' already exists"
    } else {
        Write-Log "|--Get-BootstrapScript - Downloading nested labs bootstrap script 'bootstrap.ps1'"
        Download-FileWithFallback -Source $MainBootstrapScriptURL -Destination $TempPath -FileName $MainBootstrapFileName
    }

    #----------------------------------------------------------------------------------------------------------------------#

    $BootstrapFileName = $BootstrapScriptURL.Split('/')[-1]
    $BootstrapPackagePath = Join-Path $TempPath $BootstrapFileName

    if (Test-Path $BootstrapPackagePath -PathType Leaf) {
        Write-Log "|--Get-BootstrapScript - Nested labs bootstrap script 'bootstrap-nestedlabs.ps1' already exists"
    } else {
        Write-Log "|--Get-BootstrapScript - Downloading nested labs bootstrap script 'bootstrap-nestedlabs.ps1'"
        Download-FileWithFallback -Source $BootstrapScriptURL -Destination $TempPath -FileName $BootstrapFileName
    }
}

function Download-FileWithFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        
        [Parameter()]
        [string]$FileName,
        
        [Parameter()]
        [int]$RetryCount = 3
    )
    
    # Get filename from URL if not specified
    if (-not $FileName) {
        $FileName = $Source.Split('/')[-1]
    }
    
    $FullDestination = Join-Path $Destination $FileName
    
    # Check if file already exists
    if (Test-Path $FullDestination) {
        Write-Log "|--Download-FileWithFallback - File already exists: $FullDestination"
        return $true
    }
    
    Write-Log "|--Download-FileWithFallback - Attempting to download $Source to $FullDestination"
    
    # Ensure TLS 1.2 is used
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Try BITS transfer first with retries
    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            Write-Log "|--Download-FileWithFallback - Trying BitsTransfer (attempt $i of $RetryCount)..."
            Start-BitsTransfer -Source $Source -Destination $FullDestination -Priority High -ErrorAction Stop
            Write-Log "|--Download-FileWithFallback - BitsTransfer completed successfully"
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "|--Download-FileWithFallback - BitsTransfer attempt $i failed: $errorMessage"
            if ($i -eq $RetryCount) {
                Write-Log "|--Download-FileWithFallback - All BitsTransfer attempts failed, trying alternative methods"
            } else {
                Write-Log "|--Download-FileWithFallback - Retrying in 5 seconds..."
                Start-Sleep -Seconds 5
            }
        }
    }
        
    # Try WebClient as fallback
    try {
        Write-Log "|--Download-FileWithFallback - Trying WebClient download method..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Source, $FullDestination)
        Write-Log "|--Download-FileWithFallback - WebClient download completed successfully"
        return $true
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Log "|--Download-FileWithFallback - WebClient download failed: $errorMessage"
        
        # Try Invoke-WebRequest as last resort
        try {
            Write-Log "|--Download-FileWithFallback - Trying Invoke-WebRequest..."
            Invoke-WebRequest -Uri $Source -OutFile $FullDestination -UseBasicParsing
            Write-Log "|--Download-FileWithFallback - Invoke-WebRequest download completed successfully"
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "|--Download-FileWithFallback - All download methods failed for $Source. Error: $errorMessage"
            return $false
        }
    }
}

function Set-BootstrapScheduledTask {

    $filePath = "c:\temp\bootstrap-nestedlabs.ps1"
    
    $scriptParams = "-GroupId " + $GroupNumber + " -Labs " + $NumberOfNestedLabs

    if($isMAG){
        $scriptParams+= " -isMAG"
    }

    $workingDirectory = "c:\temp"

    $taskName = "Build Nested Labs"

    $taskDescription = "Task for building nested labs inside AVS SDDC"

    $action = New-ScheduledTaskAction -Execute 'PWSH.exe' -WorkingDirectory $workingDirectory -Argument "-ExecutionPolicy Unrestricted -NonInteractive -NoProfile -WindowStyle Hidden -WorkingDirectory `"$workingDirectory`" -File `"$filePath`" $scriptParams"

    $trigger = New-ScheduledTaskTrigger -AtStartup
    #$trigger = New-ScheduledTaskTrigger -Once -At (get-date).AddMinutes(10) -RandomDelay (New-TimeSpan -Minutes 5)

    $principal = New-ScheduledTaskPrincipal -UserId "S-1-5-18" -RunLevel Highest

    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -Priority 7 -ExecutionTimeLimit $(New-TimeSpan -Hours 24)

    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description $taskDescription -Principal $principal -Settings $settings -Force
    
    Write-Log "|--Set-BootstrapScheduledTask - bootstrap-nestedlabs.ps1 will be deploying $NumberOfNestedLabs nested labs for group $GroupNumber"

}

function Get-NestedLabPackage {
    $ZipFileName = $PackageURL.Split('/')[-1]
    $ZipPackagePath = Join-Path $TempPath $ZipFileName

    if (Test-Path $ZipPackagePath -PathType Leaf) {
        Write-Log "|--Get-NestedLabPackage - Nested labs zip package already exists"
        return $true
    }
    else { 
        Write-Log "|--Get-NestedLabPackage - Downloading nested labs zip package, this may take some time..."
        $downloadResult = Download-FileWithFallback -Source $PackageURL -Destination $TempPath -FileName $ZipFileName
        
        if ($downloadResult) {
            Write-Log "|--Get-NestedLabPackage - Nested labs zip package downloaded successfully"
            return $true
        }
        else {
            Write-Log "|--Get-NestedLabPackage - Failed to download nested labs zip package. Please run bootstrap.ps1 again to make sure package is downloaded properly before you proceed"
            return $false
        }
    }
}

function Set-Jumpbox {
    Restart-Computer
}


#-------------------------------------------------------------------------------------------------------#

# Execution:

Write-Log " "
Write-Log "#---===---===---===---===---===---===---===---===---===---===---===---===---===---#"
Write-Log "Starting Execution"

Write-Log "Disabling Internet Explorer Enhanced Security Configuration"
Disable-IEESC

Write-Log "Installing essential Apps and Tools (i.e.: PowerShell Core, 7zip, AzCopy, AzCLI, VMRC)"
Install-Applications

Write-Log "Check if $TempPath exist. If it did not exist, then create it"
Test-TempDirectory

Write-Log "Downloading bootstrap-nestedlabs.ps1 script"
Get-BootstrapScript

# if automated
if ($automated) {
    Write-Log "Creating a Windows Scheduled Task to register bootstrap-nestedlabs.ps1 script, and trigger it on Jumpbox VM startup"
    Set-BootstrapScheduledTask
}

Write-Log "Downloading nested labs Zip package"
$nestedLabPackageResult = Get-NestedLabPackage
if ($automated -and $nestedLabPackageResult) {
    Write-Log "Rebooting Jumpbox VM"
    Set-Jumpbox
} else {
    Write-Host "Lab preparation is not in full automated mode. Next step:"
    Write-Host "  powershell.exe -ExecutionPolicy Unrestricted -File c:\temp\bootstrap-nestedlabs.ps1 -GroupId X -Labs Y"
}

Write-Log "Concluding Execution"
Write-Log " "
