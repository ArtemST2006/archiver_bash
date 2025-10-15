# Log manager script
$LogDrive = "L:"
$BackupDrive = "B:"
$Threshold = Read-Host "Enter the limit percent"
$KeepLastNFiles = Read-Host "How much files to leave"

# Function to get disk usage
function Get-DiskUsage {
    param([string]$DriveLetter)
    
    $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $DriveLetter}
    if ($null -eq $disk) {
        return $null
    }
    $totalSize = $disk.Size
    $freeSpace = $disk.FreeSpace
    $usagePercent = [math]::Round((($totalSize - $freeSpace) / $totalSize) * 100, 2)
    return $usagePercent
}

# Function to backup old files
function Backup-OldFiles {
    Write-Host "Starting backup..." -ForegroundColor Yellow
    
    # Get all files sorted by date (oldest first)
    $allFiles = Get-ChildItem -Path "$LogDrive\" -File | Sort-Object LastWriteTime
    
    if ($allFiles.Count -le $KeepLastNFiles) {
        Write-Host "Not enough files to backup. Keeping all." -ForegroundColor Cyan
        return
    }
    
    # Exclude N newest files
    $filesToArchive = $allFiles | Select-Object -First ($allFiles.Count - $KeepLastNFiles)
    
    Write-Host "Files to archive: $($filesToArchive.Count)" -ForegroundColor Yellow
    Write-Host "Files to keep: $KeepLastNFiles" -ForegroundColor Green
    
    # Create backup filename
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFileName = "logs_backup_$timestamp.zip"
    $backupPath = Join-Path $BackupDrive $backupFileName
    
    # Create archive
    try {
        Compress-Archive -Path $filesToArchive.FullName -DestinationPath $backupPath -CompressionLevel Optimal
        Write-Host "Archive created: $backupFileName" -ForegroundColor Green
        
        # Remove archived files
        $filesToArchive | Remove-Item -Force
        Write-Host "Archived files removed from $LogDrive" -ForegroundColor Green
        
        # Show stats
        $freedSpace = ($filesToArchive | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "Freed space: $([math]::Round($freedSpace, 2)) MB" -ForegroundColor Green
    }
    catch {
        Write-Host "Backup error: $_" -ForegroundColor Red
    }
}

# Main script
Write-Host "=== LOG Folder Monitor ===" -ForegroundColor Cyan
Write-Host "Checking drive: $LogDrive" -ForegroundColor White

$usage = Get-DiskUsage -DriveLetter $LogDrive

if ($null -eq $usage) {
    Write-Host "Error: Disk $LogDrive not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Current disk usage: $usage%" -ForegroundColor White

if ($usage -ge $Threshold) {
    Write-Host "Threshold $Threshold% exceeded! Starting backup..." -ForegroundColor Red
    Backup-OldFiles
}
else {
    Write-Host "Threshold $Threshold% not exceeded. No backup needed." -ForegroundColor Green
}

Write-Host "=== Completed ===" -ForegroundColor Cyan
