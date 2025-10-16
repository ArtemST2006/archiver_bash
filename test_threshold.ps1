# Test disk fill threshold conditions
Write-Host "=== TEST 1: Disk Fill Threshold Conditions ===" -ForegroundColor Magenta

# Import utility module
. ".\disk_utils.ps1"

# Import main script with functions
. ".\log_manager.ps1"

# Global variables (should match main script)
$global:LogDrive = "L:"
$global:BackupDrive = "B:" 
$global:KeepLastNFiles = 5

# Test scenarios
$testScenarios = @(
    @{TargetUsage = 69; ExpectedAction = $false; Description = "Below threshold (69%) - backup should NOT run"}
    @{TargetUsage = 70; ExpectedAction = $true;  Description = "At threshold (70%) - backup SHOULD run"}
    @{TargetUsage = 85; ExpectedAction = $true;  Description = "Above threshold (85%) - backup SHOULD run"}
)

# Main test loop
foreach ($test in $testScenarios) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "SCENARIO: $($test.Description)" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    # Step 1: Fill disk to target percentage
    Write-Host "Step 1: Preparing disk..." -ForegroundColor Yellow
    $success = Set-DiskUsage -DriveLetter $LogDrive -TargetPercentage $test.TargetUsage
    if (-not $success) {
        Write-Host "❌ Failed to prepare disk for test" -ForegroundColor Red
        continue
    }
    
    # Step 2: Record initial state
    $initialFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $initialUsage = Get-DiskUsage -DriveLetter $LogDrive
    Write-Host "Initial state: $initialFiles files, $initialUsage% usage" -ForegroundColor White
    
    # Step 3: Set threshold and run check
    Write-Host "Step 2: Setting threshold and checking..." -ForegroundColor Yellow
    $global:Threshold = 70
    
    # Emulate main script logic
    $usage = Get-DiskUsage -DriveLetter $LogDrive
    Write-Host "Current usage: $usage%" -ForegroundColor White
    
    $backupTriggered = $false
    if ($usage -ge $Threshold) {
        Write-Host "Threshold $Threshold% exceeded! Starting backup..." -ForegroundColor Red
        Backup-OldFiles
        $backupTriggered = $true
    }
    else {
        Write-Host "Threshold $Threshold% not exceeded. Backup not required." -ForegroundColor Green
        $backupTriggered = $false
    }
    
    # Step 4: Check result
    Write-Host "Step 3: Checking result..." -ForegroundColor Yellow
    $finalFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $finalUsage = Get-DiskUsage -DriveLetter $LogDrive
    
    Write-Host "Final state: $finalFiles files, $finalUsage% usage" -ForegroundColor White
    
    # Determine test success
    $testPassed = $backupTriggered -eq $test.ExpectedAction
    
    if ($testPassed) {
        Write-Host "✅ TEST PASSED: Expected - $($test.ExpectedAction), Got - $backupTriggered" -ForegroundColor Green
    } else {
        Write-Host "❌ TEST FAILED: Expected - $($test.ExpectedAction), Got - $backupTriggered" -ForegroundColor Red
    }
    
    # Additional checks
    if ($backupTriggered) {
        $backupExists = (Get-ChildItem "$BackupDrive\*.zip" | Measure-Object).Count -gt 0
        if ($backupExists) {
            Write-Host "✅ Archive created successfully" -ForegroundColor Green
        } else {
            Write-Host "❌ Archive not created" -ForegroundColor Red
        }
        
        if ($finalFiles -le $KeepLastNFiles) {
            Write-Host "✅ Correct number of files remaining: $finalFiles" -ForegroundColor Green
        } else {
            Write-Host "⚠️  More files remaining than expected: $finalFiles (expected <= $KeepLastNFiles)" -ForegroundColor Yellow
        }
    }
    
    # Short pause between tests
    Start-Sleep -Seconds 2
}

Write-Host "`n" + "="*60 -ForegroundColor Magenta
Write-Host "TESTING COMPLETED" -ForegroundColor Magenta
Write-Host "="*60 -ForegroundColor Magenta

# Cleanup test data
Write-Host "`nCleaning test data..." -ForegroundColor Gray
Clear-TestFolder -Path $LogDrive
Clear-TestFolder -Path $BackupDrive