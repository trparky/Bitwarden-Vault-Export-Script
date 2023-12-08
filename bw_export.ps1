# Bitwarden Vault Export Script
# Author: David H (@dh024)
#  
# This script will backup the following:
#   - personal vault contents, password encrypted (or unencrypted)
#   - organizational vault contents (passwd encrypted or unencrypted)
#   - file attachments
# It will also report on whether there were items in the Trash that
# could not be exported.
#
# Converted to a PowerShell Script by Thomas Parkison.

# Set locations to save export files
$saveFolder = "C:\bw_export" # No leading slash

# Set Organization ID (if applicable)
$orgId = ""
# To obtain your organization_id value, open a terminal and type:
# bw.exe login #(follow the prompts); bw.exe list organizations | ConvertFrom-Json | Select-Object -ExpandProperty Id

# ====================================================
# == WARNING!!! DO NOT TOUCH ANYTHING BELOW THIS!!! ==
# ====================================================

Write-Host -ForegroundColor Green "========================================================================================"
Write-Host -ForegroundColor Green "==                        Bitwarden Vault Export Script v1.07                         =="
Write-Host -ForegroundColor Green "== Originally created by David H, converted to a Powershell Script by Thomas Parkison =="
Write-Host -ForegroundColor Green "========================================================================================"
Write-Host ""

# Prompt user for their Bitwarden username
$userEmail = Read-Host "Enter your Bitwarden Username"

$saveFolder = [System.IO.Path]::Combine($saveFolder, $userEmail)
$saveFolderAttachments = [System.IO.Path]::Combine($saveFolder, "attachments")
$saveFolder = $saveFolder + "\"

if (!(Test-Path -Path $saveFolder)) { New-Item -ItemType Directory -Path $saveFolder | Out-Null }

function ConvertSecureString {
	param (
		[System.Security.SecureString]$String
	)

	#return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($String)) // Old way

	if ($String.Length -eq 0) { return "" }
	else {
		$output = ConvertFrom-SecureString -SecureString $String -AsPlainText
		return $output.Trim()
	}
}

function AskYesNoQuestion {
	param (
		[String]$prompt
	)

	$answer = ""
	do {
		$answer = (Read-Host $prompt).ToLower().Trim()
	} while ($answer -ne 'y' -and $answer -ne 'n')

	return $answer
}

function LockAndLogout {
      	.\bw.exe lock
      	Write-Host ""

      	.\bw.exe logout
      	Write-Host ""
}

# Prompt user for their Bitwarden password
$bwPassword = Read-Host "Enter your Bitwarden Password" -AsSecureString

# Login user if not already authenticated
if ((.\bw.exe status | ConvertFrom-Json).status -eq "unauthenticated") {
	Write-Host "Performing login..."
	$bwPasswordText = ConvertSecureString -String $bwPassword
	.\bw.exe login $userEmail $bwPasswordText --method 0 --quiet
}

if ((.\bw.exe status | ConvertFrom-Json).status -eq "unauthenticated") {
	Write-Host -ForegroundColor Red "Error:" -NoNewLine
	Write-Host " Failed to authenticate."
	exit 1
}

# Unlock the vault
$bwPasswordText = ConvertSecureString -String $bwPassword
$sessionKey = (.\bw.exe unlock "$bwPasswordText" --raw) | Out-String

# Verify that unlock succeeded
if ([String]::IsNullOrWhiteSpace($sessionKey)) {
	Write-Host -ForegroundColor Red "Error:" -NoNewLine
	Write-Host " Failed to authenticate."
	exit 1
}
else { Write-Host "Login successful." }

# Export the session key as an env variable (needed by bw.exe CLI)
$env:BW_SESSION = $sessionKey

# Prompt the user for an encryption password
$password1 = Read-Host "Enter a password to encrypt your vault (or press ENTER for an unencrypted export)" -AsSecureString

# Convert the SecureString to plain text
$password1Text = ConvertSecureString -String $password1

$encryptedDataBackup = $false

# Check if the user has decided to enter a password or save unencrypted
if ([String]::IsNullOrWhiteSpace($password1Text)) {
	Write-Host -ForegroundColor Yellow "WARNING!" -NoNewLine
	Write-Host " Your vault contents will be saved to an unencrypted file."

	if ((AskYesNoQuestion -prompt "Continue? [y/n]") -eq "n") {
		LockAndLogout
		Write-Host "Exiting script."
		exit 1
	}
}
else {
	$password2 = Read-Host "Enter the same password for verification" -AsSecureString
	$password2Text = ConvertSecureString -String $password2
	
	if ($password1Text -ne $password2Text) {
		Write-Host -ForegroundColor Red "Error:" -NoNewLine
		Write-Host " The passwords did not match."
		LockAndLogout
		exit 1
	}
	else {
		Write-Host "Password verified. Be sure to save your password in a safe place!"
		$encryptedDataBackup = $true
	}
}

Write-Host ""
Write-Host "Performing vault exports..."
Write-Host ""

# 1. Export the personal vault 
if (!(Test-Path $saveFolder)) {
	LockAndLogout
	Write-Host -ForegroundColor Red "Error:" -NoNewLine
	Write-Host " Could not find the folder in which to save the files."
	exit 1
}

if (!$encryptedDataBackup) {
	Write-Host "Exporting personal vault to an unencrypted file..."
	.\bw.exe export --format json --output $saveFolder
	Write-Host ""
}
else {
	Write-Host "Exporting personal vault to a password-encrypted file..."
	.\bw.exe export --format encrypted_json --password $password1Text --output $saveFolder
	Write-Host ""
}

# 2. Export the organization vault (if specified) 
if (!([string]::IsNullOrEmpty($orgId))) {
	if (!$encryptedDataBackup) {
		Write-Host "Exporting organization vault to an unencrypted file..."
		.\bw.exe export --organizationid $orgId --format json --output $saveFolder
		Write-Host ""
	}
	else {
		Write-Host "Exporting organization vault to a password-encrypted file..."
		.\bw.exe export --organizationid $orgId --format encrypted_json --password $password1Text --output $saveFolder
		Write-Host ""
	}
}
else { Write-Host "No organizational vault exists, so nothing to export." }

# 3. Download all attachments (file backup)
# First download attachments in vault
$itemsWithAttachments = (.\bw.exe list items | ConvertFrom-Json | Where-Object { $_.attachments -ne $null })

if ($itemsWithAttachments.Count -gt 0) {
	Write-Host "Saving attachments..."

	foreach ($item in $itemsWithAttachments) {
		foreach ($attachment in $item.attachments) {
			.\bw.exe get attachment "$($attachment.fileName)" --itemid $item.id --output "$saveFolderAttachments\$($item.name)\"
			Write-Host ""
		}
	}
}
else { Write-Host "No attachments exist, so nothing to export." }

Write-Host -ForegroundColor Green "Vault export complete."

# 4. Report items in the Trash (cannot be exported)
$trashCount = (.\bw.exe list items --trash | ConvertFrom-Json).Count

if ($trashCount -gt 0) {
	Write-Host -ForegroundColor Yellow "Note:" -NoNewLine
	Write-Host " You have $trashCount items in the trash that cannot be exported."
}

LockAndLogout

if ((AskYesNoQuestion -prompt "Compress? [y/n]") -eq "y") {
	Write-Host "Compressing backup..."
	Set-Location $saveFolder
	Compress-Archive -Path * -DestinationPath "$userEmail.zip" -Force
	Move-Item "$userEmail.zip" ../
	Set-Location ../
	Remove-Item $saveFolder -Recurse -Force
}

Write-Host -ForegroundColor Green "Script completed."