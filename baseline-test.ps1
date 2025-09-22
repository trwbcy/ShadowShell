Write-Host "Starting baseline test..."

# Normal PowerShell commands
whoami
Get-Process | Select-Object -First 5
Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object -First 3

# Network activity
Test-NetConnection -ComputerName "8.8.8.8" -Port 53

# File operations
New-Item -Path "C:\temp\test.txt" -ItemType File -Value "Test content"
Get-Content "C:\temp\test.txt"
Remove-Item "C:\temp\test.txt"

# Potentially suspicious command
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Get-ComputerInfo"))
powershell -enc $encoded

Write-Host "Baseline test completed"