$pathToPSD1File = Join-Path (Get-Location) "Export-Bitwarden.psd1"
$contentToAppend = "`n`$ExportBitwardenScriptPath = ""$pathToPSD1File""
if (Test-Path(`$ExportBitwardenScriptPath)) { Import-Module `$ExportBitwardenScriptPath }"

if (!(Test-Path -Path $PROFILE)) {
	Write-Host "Installing module..." -NoNewLine
	New-Item -Path $PROFILE -ItemType File -Force
	Add-Content -Path $filePath -Value $contentToAppend -Encoding UTF8
	Write-Host " Done."
}
else {
	$file_contents = Get-Content -Path $PROFILE -Raw

	if ($file_contents.Contains("Export-Bitwarden.psd1")) {
		if ($file_contents -cmatch '\$ExportBitwardenScriptPath = "([]\t !"#$%&''()*+,./0-9:;<=>?@A-Z[\\_`a-z{|}~^-]{10,}\.psd1)"') {
			$ExportBitwardenScriptPath = $matches[1]

			if ($ExportBitwardenScriptPath.ToLower().Trim() -eq $pathToPSD1File.ToLower()) {
				Write-Host "Module already installed."
			}
			else {
				Write-Host "Module path found, but not correct. Correcting path..." -NoNewline
				$file_contents = $file_contents -creplace '\$ExportBitwardenScriptPath = "([]\t !"#$%&''()*+,./0-9:;<=>?@A-Z[\\_`a-z{|}~^-]{10,}\.psd1)"', "`$ExportBitwardenScriptPath = ""$pathToPSD1File"""
				$file_contents | Out-File -FilePath $PROFILE -NoNewline
				Write-Host " Done. You will now have to restart the Powershell shell for the changes to take effect."
			}
		}
	}
	else {
		Write-Host "Installing module..." -NoNewLine
		Add-Content -Path $PROFILE -Value $contentToAppend -Encoding UTF8
		Write-Host " Done. You will now have to restart the Powershell shell for the changes to take effect."
	}
}