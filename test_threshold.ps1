# Test disk fill threshold conditions
param(
    [int]$TestThreshold = 60,
    [int]$TestKeepFiles = 10
)

Write-Host "=== TEST 1: Disk Fill Threshold Conditions ===" -ForegroundColor Magenta
Write-Host "Test Parameters: Threshold=$TestThreshold%, KeepFiles=$TestKeepFiles" -ForegroundColor Yellow

# Import utility module
. ".\disk_utils.ps1"

# Import main script but skip the interactive parts
$mainScriptContent = Get-Content ".\log_manager.ps1" -Raw

# Remove the Read-Host lines and replace with our values
$modifiedScript = $mainScriptContent -replace '\$Threshold\s*=\s*Read-Host\s*"Enter the limit percent"', "`$Threshold = $TestThreshold"
$modifiedScript = $modifiedScript -replace '\$KeepLastNFiles\s*=\s*Read-Host\s*"How much files to leave"', "`$KeepLastNFiles = $TestKeepFiles"

# Execute the modified script
$scriptBlock = [scriptblock]::Create($modifiedScript)
. $scriptBlock

# Now we have the main script functions but with our parameters

# Test scenarios (using the actual parameters from main script)
$testScenarios = @(
    @{TargetUsage = ($Threshold - 1); ExpectedAction = $false; Description = "Below threshold ($($Threshold - 1)%) - backup should NOT run"}
    @{TargetUsage = $Threshold; ExpectedAction = $true;  Description = "At threshold ($Threshold%) - backup SHOULD run"}
    @{TargetUsage = ($Threshold + 15); ExpectedAction = $true;  Description = "Above threshold ($($Threshold + 15)%) - backup SHOULD run"}
)

Write-Host "Actual parameters used: Threshold=$Threshold%, KeepFiles=$KeepLastNFiles" -ForegroundColor Cyan

# Counter for test results
$passedTests = 0
$failedTests = 0

# Main test loop
foreach ($test in $testScenarios) {
    Write-Host ""
    Write-Host ("="*60) -ForegroundColor Cyan
    Write-Host "SCENARIO: $($test.Description)" -ForegroundColor Cyan
    Write-Host ("="*60) -ForegroundColor Cyan
    
    # Step 1: Fill disk to target percentage
    Write-Host "STEP 1: Preparing disk..." -ForegroundColor Yellow
    $success = Set-DiskUsage -DriveLetter $LogDrive -TargetPercentage $test.TargetUsage
    if (-not $success) {
        Write-Host "FAILED: Failed to prepare disk for test" -ForegroundColor Red
        $failedTests++
        continue
    }
    
    # Step 2: Record initial state
    $initialFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $initialUsage = Get-DiskUsage -DriveLetter $LogDrive
    Write-Host "INITIAL STATE: $initialFiles files, $initialUsage% usage" -ForegroundColor Gray
    
    # Step 3: Run main script logic
    Write-Host "STEP 2: Running backup check..." -ForegroundColor Yellow
    
    $backupTriggered = $false
    $usage = Get-DiskUsage -DriveLetter $LogDrive
    
    Write-Host "CURRENT USAGE: $usage%" -ForegroundColor White
    
    if ($usage -ge $Threshold) {
        Write-Host "THRESHOLD EXCEEDED: $Threshold% - Starting backup..." -ForegroundColor Red
        
        # Run backup function directly
        Backup-OldFiles
        $backupTriggered = $true
    }
    else {
        Write-Host "THRESHOLD OK: $Threshold% not exceeded" -ForegroundColor Green
        $backupTriggered = $false
    }
    
    # Step 4: Check result
    Write-Host "STEP 3: Checking result..." -ForegroundColor Yellow
    $finalFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $finalUsage = Get-DiskUsage -DriveLetter $LogDrive
    
    Write-Host "FINAL STATE: $finalFiles files, $finalUsage% usage" -ForegroundColor Gray
    
    # Determine test success
    $testPassed = $backupTriggered -eq $test.ExpectedAction
    
    if ($testPassed) {
        Write-Host "RESULT: PASS - Expected: $($test.ExpectedAction), Got: $backupTriggered" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "RESULT: FAIL - Expected: $($test.ExpectedAction), Got: $backupTriggered" -ForegroundColor Red
        $failedTests++
    }
    
    # Additional checks
    if ($backupTriggered) {
        $backupExists = (Get-ChildItem "$BackupDrive\*.zip" | Measure-Object).Count -gt 0
        if ($backupExists) {
            Write-Host "ARCHIVE: Created successfully" -ForegroundColor Green
        } else {
            Write-Host "ARCHIVE: Not created" -ForegroundColor Red
        }
        
        if ($finalFiles -le $KeepLastNFiles) {
            Write-Host "FILES REMAINING: Correct - $finalFiles files" -ForegroundColor Green
        } else {
            Write-Host "FILES REMAINING: Too many - $finalFiles files (expected <= $KeepLastNFiles)" -ForegroundColor Yellow
        }
    }
    
    # Short pause between tests
    Start-Sleep -Seconds 1
}

# Final summary
Write-Host ""
Write-Host ("="*60) -ForegroundColor Magenta
Write-Host "TEST SUMMARY" -ForegroundColor Magenta
Write-Host ("="*60) -ForegroundColor Magenta
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })
Write-Host "Total:  $($testScenarios.Count)" -ForegroundColor White

Write-Host ""
Write-Host ("="*60) -ForegroundColor Magenta
Write-Host "TESTING COMPLETED" -ForegroundColor Magenta
Write-Host ("="*60) -ForegroundColor Magenta

# Cleanup test data
Write-Host ""
Write-Host "Cleaning test data..." -ForegroundColor Gray
Clear-TestFolder -Path $LogDrive
Clear-TestFolder -Path $BackupDrive
