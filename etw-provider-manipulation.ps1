function Get-ETWProviders {
    Write-Host "Enumerating ETW Providers..."

    # Get PowerShell related providers
    $providers = logman query providers | Select-String -Pattern "PowerShell|Microsoft-Windows-PowerShell"

    Write-Host "Found PowerShell ETW Providers:"
    foreach ($provider in $providers) {
        Write-Host "  $provider"
    }

    # Also check WMI for more detailed info
    try {
        $wmiProviders = Get-WmiObject -Namespace "root\wmi" -Class "EventTrace" -ErrorAction SilentlyContinue
        Write-Host "WMI EventTrace objects: $($wmiProviders.Count)"
    } catch {
        Write-Host "Could not query WMI EventTrace objects"
    }
}

function Disable-ETWProvider {
    param([string]$ProviderName)

    try {
        Write-Host "Attempting to disable provider: $ProviderName"

        # Method 1: Try to stop ETW session
        $sessions = logman query -ets | Select-String -Pattern $ProviderName
        foreach ($session in $sessions) {
            $sessionName = ($session -split "\s+")[0]
            Write-Host "Found session: $sessionName"
            try {
                logman stop $sessionName -ets
                Write-Host "Stopped session: $sessionName"
            } catch {
                Write-Host "Could not stop session: $sessionName"
            }
        }

        return $true
    } catch {
        Write-Host "Error disabling provider: $($_.Exception.Message)"
        return $false
    }
}

function Test-ProviderStatus {
    Write-Host "Testing ETW Provider Status..."

    # Check active ETW sessions
    $etwSessions = logman query -ets
    Write-Host "Active ETW Sessions:"
    $etwSessions | Select-String -Pattern "PowerShell|Microsoft" | ForEach-Object {
        Write-Host "  $_"
    }

    # Test PowerShell logging specifically
    Write-Host "Testing PowerShell ETW logging..."

    $before = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count

    # Execute test command
    Write-Host "Test message for ETW"
    whoami | Out-Null

    Start-Sleep 2
    $after = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count

    $diff = $after - $before
    if ($diff -eq 0) {
        Write-Host "ETW PowerShell logging: DISABLED" -ForegroundColor Green
    } else {
        Write-Host "ETW PowerShell logging: ACTIVE ($diff new events)" -ForegroundColor Red
    }
}

# Main execution
Write-Host "ETW Provider Manipulation Tool"
Write-Host "==============================="

Get-ETWProviders
Write-Host ""
Test-ProviderStatus
Write-Host ""

# Try to disable PowerShell providers
Disable-ETWProvider -ProviderName "Microsoft-Windows-PowerShell"
Disable-ETWProvider -ProviderName "PowerShell"

Write-Host ""
Write-Host "Testing after attempted disable:"
Test-ProviderStatus