# Test different file counts in folder
Write-Host "=== TEST 2: Different File Counts ===" -ForegroundColor Magenta

# Import modules
. ".\disk_utils.ps1"
. ".\log_manager.ps1"

# Global variables
$global:LogDrive = "L:"
$global:BackupDrive = "B:"
$global:Threshold = 70  # Set threshold so backup always triggers

# Test scenarios
$testScenarios = @(
    @{FileCount = 0;  KeepCount = 5; ExpectedArchived = 0; Description = "0 files, keep 5 - nothing should happen"}
    @{FileCount = 3;  KeepCount = 5; ExpectedArchived = 0; Description = "3 files, keep 5 - backup should NOT run"}
    @{FileCount = 10; KeepCount = 5; ExpectedArchived = 5; Description = "10 files, keep 5 - should archive 5 oldest"}
    @{FileCount = 20; KeepCount = 8; ExpectedArchived = 12; Description = "20 files, keep 8 - should archive 12 oldest"}
)

# Main test loop
foreach ($test in $testScenarios) {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "SCENARIO: $($test.Description)" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    # Step 1: Prepare test files
    Write-Host "Step 1: Preparing test files..." -ForegroundColor Yellow
    Clear-TestFolder -Path $LogDrive
    Clear-TestFolder -Path $BackupDrive
    
    if ($test.FileCount -gt 0) {
        New-TestFiles -Path $LogDrive -Count $test.FileCount -MinSizeKB 10 -MaxSizeKB 50
    }
    
    # Step 2: Set parameters
    Write-Host "Step 2: Setting parameters..." -ForegroundColor Yellow
    $global:KeepLastNFiles = $test.KeepCount
    
    # Record initial state
    $initialFiles = (Get-ChildItem "$LogDrive\" -File).Count
    
    Write-Host "Initial state: $initialFiles files" -ForegroundColor White
    Write-Host "Expected archived: $($test.ExpectedArchived) files" -ForegroundColor White
    
    # Step 3: Run backup
    Write-Host "Step 3: Running backup..." -ForegroundColor Yellow
    Backup-OldFiles
    
    # Step 4: Check result
    Write-Host "Step 4: Checking result..." -ForegroundColor Yellow
    $finalFiles = (Get-ChildItem "$LogDrive\" -File).Count
    $archivedFiles = $initialFiles - $finalFiles
    
    Write-Host "Files remaining: $finalFiles (expected: $($test.KeepCount))" -ForegroundColor White
    Write-Host "Files archived: $archivedFiles (expected: $($test.ExpectedArchived))" -ForegroundColor White
    
    # Check test success
    $testPassed = $true
    $details = @()
    
    # Check 1: Number of remaining files
    if ($finalFiles -le $test.KeepCount) {
        $details += "✅ Correct number of remaining files"
    } else {
        $details += "❌ Too many files remaining"
        $testPassed = $false
    }
    
    # Check 2: Number of archived files
    if ($archivedFiles -eq $test.ExpectedArchived) {
        $details += "✅ Correct number of archived files"
    } else {
        $details += "❌ Incorrect number of archived files"
        $testPassed = $false
    }
    
    # Check 3: Are the newest files remaining
    if ($finalFiles -gt 0) {
        $remainingFiles = Get-ChildItem "$LogDrive\" -File | Sort-Object LastWriteTime -Descending
        $newestFiles = $remainingFiles | Select-Object -First $test.KeepCount
        
        if ($newestFiles.Count -eq $finalFiles) {
            $details += "✅ Newest files are remaining"
        } else {
            $details += "❌ Not the newest files remaining"
            $testPassed = $false
        }
    }
    
    # Test result output
    if ($testPassed) {
        Write-Host "✅ TEST PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ TEST FAILED" -ForegroundColor Red
    }
    
    # Check details
    foreach ($detail in $details) {
        Write-Host "  $detail" -ForegroundColor $(if ($detail -like "✅*") { "Green" } else { "Red" })
    }
    
    # Check archive
    $backupFiles = Get-ChildItem "$BackupDrive\*.zip"
    if ($backupFiles -and $test.ExpectedArchived -gt 0) {
        Write-Host "Archive created: $($backupFiles[0].Name)" -ForegroundColor Green
    } elseif (-not $backupFiles -and $test.ExpectedArchived -eq 0) {
        Write-Host "No archive created (as expected)" -ForegroundColor Green
    } else {
        Write-Host "Problem with archive creation" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 1
}

Write-Host "`n" + "="*60 -ForegroundColor Magenta
Write-Host "TESTING COMPLETED" -ForegroundColor Magenta
Write-Host "="*60 -ForegroundColor Magenta

# Cleanup
Write-Host "`nCleaning test data..." -ForegroundColor Gray
Clear-TestFolder -Path $LogDrive
Clear-TestFolder -Path $BackupDrive