$path = Join-Path (Get-Location) "Export-Bitwarden.psd1"
$contentToAppend = "`n`$ExportBitwardenScriptPath = ""$path""
if (Test-Path(`$ExportBitwardenScriptPath)) { Import-Module `$ExportBitwardenScriptPath }"

if (!(Test-Path -Path $PROFILE)) {
	New-Item -Path $PROFILE -ItemType File -Force
	Add-Content -Path $filePath -Value $contentToAppend -Encoding UTF8
}
else {
	$file_contents = Get-Content -Path $PROFILE -Raw

	if ($file_contents.Contains("Export-Bitwarden.psd1")) { Write-Host "Module already installed." }
	else {
		Write-Host "Installing module..." -NoNewLine
		Add-Content -Path $PROFILE -Value $contentToAppend -Encoding UTF8
		Write-Host " Done."
	}
}