Function Initialize-Shell {
    Set-Variable -Name ErrorActionPreference -Value "Stop" -Scope global
}

Function Check-Login {
    Write-Host "Logging in..."
    If ((Get-AzContext) -eq $null) {Connect-AzAccount | Out-Null}
    Write-Host "Logged in"
}

Function Get-UnixTimeSeconds {
    [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

Export-ModuleMember -Function Initialize-Shell, Check-Login, Get-UnixTimeSeconds