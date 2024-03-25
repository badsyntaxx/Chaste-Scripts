if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Remove-File {
    try {
        Write-Welcome  -Title "Force Delete File" -Description "Forcefully delete a file." -Command "remove file"

        Write-Text -Type 'header' -Text 'Enter or paste the path and file' -LineBefore -LineAfter
        $filepath = Get-Input -Prompt "" -LineAfter

        Get-Item $filepath -ErrorAction SilentlyContinue | Remove-Item -Force 

        $file = Get-Item $filepath -ErrorAction SilentlyContinue
        if (!$file) { Write-Exit -Message "File successfully deleted." }
    } catch {
        Write-Text -Type "error" -Text "Remove file error: $($_.Exception.Message)"
        Write-Exit -Script "Remove-File"
    }
}

