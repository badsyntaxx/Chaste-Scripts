if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $PSCommandArgs" -WorkingDirectory $pwd -Verb RunAs
    Exit
}

function Remove-File {
    try {
        $scriptDescription = @"
 This function forcefully deletes a file.
"@
        Write-Welcome  -Title "Remove File v0315241122" -Description $scriptDescription

        Write-Text -Type 'header' -Text 'Enter or paste the path and file' -LineBefore -LineAfter
        $filepath = Get-Input -Prompt "" -LineAfter

        Get-Item $filepath -ErrorAction SilentlyContinue | Remove-Item -Force 

        $file = Get-Item $filepath -ErrorAction SilentlyContinue
        if (!$file) { Write-Exit -Message "File successfully deleted." }
    } catch {
        Write-Text -Type "error" -Text "Remove file error: $($_.Exception.Message)"
        Write-Exit
    }
}
