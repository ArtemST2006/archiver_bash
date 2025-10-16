# Test different file counts in folder
param(
    [int]$TestThreshold = 70,
    [int]$TestKeepFiles = 5
)

Write-Host "=== TEST 2: Different File Counts ===" -ForegroundColor Magenta
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

Write-Host "Actual parameters used: Threshold=$Threshold%, KeepFiles=$KeepLastNFiles" -ForegroundColor Cyan

# Test scenarios
$testScenarios = @(
    @{
        FileCount = 0; 
        ExpectedRemaining = 0; 
        Description = "0 files - nothing should happen"
        ShouldBackupRun = $false
    },
    @{
        FileCount = ($KeepLastNFiles - 2); 
        ExpectedRemaining = ($KeepLastNFiles - 2); 
        Description = "$($KeepLastNFiles - 2) files (less than KeepFiles) - all should remain"
        ShouldBackupRun = $false
    },
    @{
        FileCount = ($KeepLastNFiles * 2); 
        ExpectedRemaining = $KeepLastNFiles; 
        Description = "$($KeepLastNFiles * 2) files - should leave $KeepLastNFiles newest"
        ShouldBackupRun = $true
    },
    @{
        FileCount = ($KeepLastNFiles * 3); 
        ExpectedRemaining = $KeepLastNFiles; 
        Description = "$($KeepLastNFiles * 3) files - should leave $KeepLastNFiles newest"
        ShouldBackupRun = $true
    }
)

# Counter for test results
$passedTests = 0
$failedTests = 0

# Main test loop
foreach ($test in $testScenarios) {
    Write-Host ""
    Write-Host ("="*60) -ForegroundColor Cyan
    Write-Host "SCENARIO: $($test.Description)" -ForegroundColor Cyan
    Write-Host ("="*60) -ForegroundColor Cyan
    
    # Step 1: Prepare test files
    Write-Host "STEP 1: Preparing test files..." -ForegroundColor Yellow
    Clear-TestFolder -Path $LogDrive
    Clear-TestFolder -Path $BackupDrive
    
    if ($test.FileCount -gt 0) {
        New-TestFiles -Path $LogDrive -Count $test.FileCount -MinSizeKB 10 -MaxSizeKB 50
    }
    
    # Step 2: Ensure disk usage is above threshold for backup to trigger
    Write-Host "STEP 2: Ensuring disk usage above threshold..." -ForegroundColor Yellow
    if ($test.ShouldBackupRun) {
        # Fill disk to ensure backup triggers
        Set-DiskUsage -DriveLetter $LogDrive -TargetPercentage ($Threshold + 10)
    }
    
    # Record initial state
    $initialFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $initialUsage = Get-DiskUsage -DriveLetter $LogDrive
    
    Write-Host "INITIAL STATE: $initialFiles files, $initialUsage% usage" -ForegroundColor Gray
    Write-Host "EXPECTED REMAINING: $($test.ExpectedRemaining) files" -ForegroundColor Gray
    Write-Host "SHOULD BACKUP RUN: $($test.ShouldBackupRun)" -ForegroundColor Gray
    
    # Step 3: Run backup
    Write-Host "STEP 3: Running backup..." -ForegroundColor Yellow
    Backup-OldFiles
    
    # Step 4: Check result
    Write-Host "STEP 4: Checking result..." -ForegroundColor Yellow
    $finalFiles = (Get-ChildItem "$LogDrive\" -File).Count
    
    Write-Host "FILES REMAINING: $finalFiles (expected: $($test.ExpectedRemaining))" -ForegroundColor White
    
    # Check test success
    $testPassed = $true
    $details = @()
    
    # Check 1: Number of remaining files
    if ($finalFiles -eq $test.ExpectedRemaining) {
        $details += "CORRECT: Number of remaining files"
    } else {
        $details += "ERROR: Incorrect number of remaining files (got $finalFiles, expected $($test.ExpectedRemaining))"
        $testPassed = $false
    }
    
    # Check 2: Are the newest files remaining (if backup ran)
    if ($test.ShouldBackupRun -and $finalFiles -gt 0) {
        $remainingFiles = Get-ChildItem "$LogDrive\" -File | Sort-Object LastWriteTime -Descending
        $newestFiles = $remainingFiles | Select-Object -First $KeepLastNFiles
        
        if ($newestFiles.Count -eq $finalFiles) {
            $details += "CORRECT: Newest files are remaining"
        } else {
            $details += "ERROR: Not the newest files remaining"
            $testPassed = $false
        }
    }
    
    # Test result output
    if ($testPassed) {
        Write-Host "RESULT: PASS" -ForegroundColor Green
        $passedTests++
    } else {
        Write-Host "RESULT: FAIL" -ForegroundColor Red
        $failedTests++
    }
    
    # Check details
    foreach ($detail in $details) {
        $color = if ($detail -like "CORRECT:*") { "Green" } else { "Red" }
        Write-Host "  $detail" -ForegroundColor $color
    }
    
    # Check archive
    $backupFiles = Get-ChildItem "$BackupDrive\*.zip"
    if ($backupFiles -and $test.ShouldBackupRun) {
        Write-Host "ARCHIVE: Created - $($backupFiles[0].Name)" -ForegroundColor Green
    } elseif (-not $backupFiles -and -not $test.ShouldBackupRun) {
        Write-Host "ARCHIVE: Not created (as expected)" -ForegroundColor Green
    } else {
        Write-Host "ARCHIVE: Problem with creation" -ForegroundColor Red
    }
    
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
Write-Host "Parameters used: Threshold=$Threshold%, KeepFiles=$KeepLastNFiles" -ForegroundColor Cyan

Write-Host ""
Write-Host ("="*60) -ForegroundColor Magenta
Write-Host "TESTING COMPLETED" -ForegroundColor Magenta
Write-Host ("="*60) -ForegroundColor Magenta

# Cleanup
Write-Host ""
Write-Host "Cleaning test data..." -ForegroundColor Gray
Clear-TestFolder -Path $LogDrive
Clear-TestFolder -Path $BackupDrive
