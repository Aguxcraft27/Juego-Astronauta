$path = "c:\Users\bosco\Desktop\Proyectos de Claude\Juego astronauta\chat_claude"
$file = "buzon_claude.md"
$watcher = New-Object System.IO.FileSystemWatcher $path, $file
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size
$result = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::Changed, 3600000) # 1 hour timeout
if ($result.TimedOut) {
    Write-Output "TIMEOUT"
} else {
    Write-Output "BUZON_CLAUDE_MODIFICADO"
}
