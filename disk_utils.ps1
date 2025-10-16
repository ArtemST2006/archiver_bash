# Utility module for disk and file operations

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

function Set-DiskUsage {
    param(
        [string]$DriveLetter,
        [int]$TargetPercentage
    )
    
    # Clear disk before filling
    Clear-TestFolder -Path $DriveLetter
    
    # Get disk information
    $disk = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq $DriveLetter}
    if ($null -eq $disk) {
        Write-Host "Error: Disk $DriveLetter not found!" -ForegroundColor Red
        return $false
    }
    
    $totalSize = $disk.Size
    $currentUsed = $totalSize - $disk.FreeSpace
    $targetUsed = $totalSize * $TargetPercentage / 100
    $spaceToAdd = $targetUsed - $currentUsed
    
    Write-Host "Need to add: $([math]::Round($spaceToAdd/1MB, 2)) MB to reach $TargetPercentage%" -ForegroundColor Gray
    
    if ($spaceToAdd -le 0) {
        Write-Host "Disk already filled above $TargetPercentage%" -ForegroundColor Yellow
        return $true
    }
    
    # Create files for filling
    $fileCounter = 1
    $addedSpace = 0
    
    while ($addedSpace -lt $spaceToAdd -and $fileCounter -le 500) {
        $fileSize = [math]::Min(5MB, $spaceToAdd - $addedSpace)
        if ($fileSize -lt 1KB) { $fileSize = 1KB }
        
        $fileName = "test_fill_$fileCounter.log"
        $filePath = "$DriveLetter\$fileName"
        
        # Create file with content
        $content = "Test file $fileCounter " + ("X" * ($fileSize - 50))
        [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::ASCII)
        
        # Set old date so files get archived
        (Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-$fileCounter)
        
        $addedSpace += $fileSize
        $fileCounter++
        
        if ($fileCounter % 50 -eq 0) {
            Write-Host "Created $fileCounter files..." -ForegroundColor Gray
        }
    }
    
    Write-Host "Created $($fileCounter-1) files, added $([math]::Round($addedSpace/1MB, 2)) MB" -ForegroundColor Green
    
    # Check result
    $currentUsage = Get-DiskUsage -DriveLetter $DriveLetter
    Write-Host "Current usage: $currentUsage% (target: $TargetPercentage%)" -ForegroundColor $(
        if ([math]::Abs($currentUsage - $TargetPercentage) -le 5) { "Green" } else { "Yellow" }
    )
    
    return $true
}

function Clear-TestFolder {
    param([string]$Path)
    
    if (Test-Path $Path) {
        Remove-Item "$Path\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "Folder $Path cleared" -ForegroundColor Green
    }
}

function New-TestFiles {
    param(
        [string]$Path,
        [int]$Count,
        [int]$MinSizeKB = 1,
        [int]$MaxSizeKB = 100
    )
    
    Clear-TestFolder -Path $Path
    
    for ($i = 1; $i -le $Count; $i++) {
        $fileSize = Get-Random -Minimum $MinSizeKB -Maximum $MaxSizeKB
        $content = "Test file $i " + ("X" * ($fileSize * 1024 - 30))
        $filePath = "$Path\testfile_$i.log"
        
        [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::ASCII)
        
        # Set different creation times
        (Get-Item $filePath).LastWriteTime = (Get-Date).AddDays(-$i)
        
        if ($i % 10 -eq 0) {
            Write-Host "Created $i files..." -ForegroundColor Gray
        }
    }
    
    Write-Host "Created $Count test files in $Path" -ForegroundColor Green
}

# Export functions for use in other scripts
# Export-ModuleMember -Function Get-DiskUsage, Set-DiskUsage, Clear-TestFolder, New-TestFiles
