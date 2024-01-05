#!/usr/bin/pwsh

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

# This tells the script if it should automatically check for an update of the Bitwarden CLI executable that's actually responsible for backing up your Bitwarden vault.
# It does this by taking the version of your currently existing Bitwarden CLI and comparing it to the version that's contained in a small text file that's on my GitHub
# page. Now, if you don't want this to happen, you can disable this kind of functionality in the script by setting the value of the $checkForBWCliUpdate to $false.
# However, it's highly recommended that you do keep this setting enabled since keeping your Bitwarden CLI up to date is obviously a good thing to do.
$checkForBWCliUpdate = $true

try {
	# ====================================================
	# == WARNING!!! DO NOT TOUCH ANYTHING BELOW THIS!!! ==
	# ====================================================

	Write-Host -ForegroundColor Green "========================================================================================"
	Write-Host -ForegroundColor Green "==                        Bitwarden Vault Export Script v1.23                         =="
	Write-Host -ForegroundColor Green "== Originally created by David H, converted to a Powershell Script by Thomas Parkison =="
	Write-Host -ForegroundColor Green "==              https://github.com/trparky/Bitwarden-Vault-Export-Script              =="
	Write-Host -ForegroundColor Green "========================================================================================"
	Write-Host ""

	function DownloadBWCli {
		$zipFilePath = (Join-Path (Get-Location) "bw.zip")

		if ($IsWindows) { Invoke-WebRequest -Uri "https://vault.bitwarden.com/download/?app=cli&platform=windows" -OutFile $zipFilePath }
		elseif ($IsLinux) { Invoke-WebRequest -Uri "https://vault.bitwarden.com/download/?app=cli&platform=linux" -OutFile $zipFilePath }
		elseif ($IsMacOS) { Invoke-WebRequest -Uri "https://vault.bitwarden.com/download/?app=cli&platform=macos" -OutFile $zipFilePath }

		Expand-Archive -Path $zipFilePath

		if ($IsLinux || $IsMacOS) {
			Move-Item -Path (Join-Path (Get-Location) "bw" "bw") -Destination (Join-Path (Get-Location) "bw.tmp")
			Remove-Item -Force (Join-Path (Get-Location) "bw")
			Move-Item -Path (Join-Path (Get-Location) "bw.tmp") -Destination (Join-Path (Get-Location) "bw")
			chmod 755 (Join-Path (Get-Location) "bw")
		}

		Remove-Item -Path $zipFilePath

		Write-Host " Done."
		Write-Host ""
	}

	function ValidateEmailAddress {
		param (
			[string]$email
		)

		$emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
		$regex = New-Object System.Text.RegularExpressions.Regex $emailPattern

		return $regex.IsMatch($email)
	}

	function ShouldWeCheckForABWCLIUpdate {
		$currentDate = Get-Date
		$checkForLastUpdateFile = Join-Path (Get-Location) "lastcheckforupdate.txt"

		if (!(Test-Path -Path $checkForLastUpdateFile)) {
			$currentDate | Out-File -FilePath $checkForLastUpdateFile -NoNewline
			return $true
		}
		else {
			$storedDate = Get-Content -Path $checkForLastUpdateFile

			try {
				$storedDateTime = [DateTime]::Parse($storedDate)
				$daysDifference = (Get-Date) - $storedDateTime

				if ($daysDifference.Days -gt 10) {
					$currentDate | Out-File -FilePath $checkForLastUpdateFile -NoNewline
					return $true
				}
				else { return $false }
			}
			catch {
				$currentDate | Out-File -FilePath $checkForLastUpdateFile
				return $true
			}
		}
	}

	function ConvertSecureString {
		param (
			[System.Security.SecureString]$String
		)

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
	      	./bw lock
	      	Write-Host ""

	      	./bw logout
	      	Write-Host ""
	}

	if ($IsWindows) { $bwCliBinName = (Join-Path (Get-Location) "bw.exe") }
	else { $bwCliBinName = (Join-Path (Get-Location) "bw") }

	if (!(Test-Path -Path $bwCliBinName)) {
		Write-Host "Bitwarden CLI application not found, downloading... Please Wait." -NoNewLine
		DownloadBWCli
		Get-Date | Out-File -FilePath (Join-Path (Get-Location) "lastcheckforupdate.txt") -NoNewline
	}
	else {
		if (($checkForBWCliUpdate) -and (ShouldWeCheckForABWCLIUpdate)) {
			$localBWCliVersion = ((./bw --version) | Out-String).Trim()
      			$remoteBWCliVersion = (Invoke-WebRequest -Uri "https://trparky.github.io/bwcliversion.txt").Content.Trim()

      			if ($localBWCliVersion -ne $remoteBWCliVersion) {
      				Write-Host "Bitwarden CLI application update found, downloading... Please Wait." -NoNewLine
      				Remove-Item -Path $bwCliBinName
      				DownloadBWCli
      			}
		}
	}

	if ((./bw status | ConvertFrom-Json).status -eq "unlocked") {
		Write-Host -ForegroundColor Green "Notice:" -NoNewLine
		Write-Host " Active Bitwarden CLI login session detected, using existing login session."
		Write-Host "The next step will ask for your Bitwarden username but only for the sake of knowing where to save your exported data."
		Write-Host ""
	}

	# Prompt user for their Bitwarden username
	$userEmail = Read-Host "Enter your Bitwarden Username"

	if (!(ValidateEmailAddress -email $userEmail)) {
		Write-Host -ForegroundColor Red "ERROR:" -NoNewline
		Write-Host " Invalid email address. Script halted."
		exit 1
	}

	$saveFolder = Join-Path (Get-Location) $userEmail

	if ($IsWindows) { $saveFolder = $saveFolder + "\" }
	else { $saveFolder = $saveFolder + "/" }

	$saveFolderAttachments = Join-Path $saveFolder "attachments"

	if (!(Test-Path -Path $saveFolder)) { New-Item -ItemType Directory -Path $saveFolder | Out-Null }

	if ((./bw status | ConvertFrom-Json).status -ne "unlocked") {
		# Prompt user for their Bitwarden password
		$bwPasswordEncrypted = Read-Host "Enter your Bitwarden Password" -AsSecureString

		Write-Host ""

		# Login user if not already authenticated
		if ((./bw status | ConvertFrom-Json).status -eq "unauthenticated") {
			Write-Host "Performing login..."
			$bwPasswordPlainText = ConvertSecureString -String $bwPasswordEncrypted
			./bw login "$userEmail" "$bwPasswordPlainText" --quiet
		}

		if ((./bw status | ConvertFrom-Json).status -eq "unauthenticated") {
			Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
			Write-Host " Failed to authenticate."
			exit 1
		}

		# Unlock the vault
		$bwPasswordPlainText = ConvertSecureString -String $bwPasswordEncrypted
		$sessionKey = (./bw unlock "$bwPasswordPlainText" --raw) | Out-String

		# Verify that unlock succeeded
		if ([String]::IsNullOrWhiteSpace($sessionKey)) {
			Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
			Write-Host " Failed to authenticate."
			exit 1
		}
		else { Write-Host "Login successful." }

		# Export the session key as an env variable (needed by bw.exe CLI)
		$env:BW_SESSION = $sessionKey
	}

	$encryptedDataBackup = $false

	Write-Host ""

	if ((AskYesNoQuestion -prompt "Do you want to encrypt your backup? [y/n]") -eq "y") {
		# Prompt the user for an encryption password
		$password1Encrypted = Read-Host "Enter a password to encrypt your vault" -AsSecureString
		$password1PlainText = ConvertSecureString -String $password1Encrypted

		$password2Encrypted = Read-Host "Enter the same password for verification" -AsSecureString
		$password2PlainText = ConvertSecureString -String $password2Encrypted

		if ($password1PlainText -ne $password2PlainText) {
			Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
			Write-Host " The passwords did not match."
			LockAndLogout
			$env:BW_SESSION = ""
			$bwPasswordEncrypted = ""
			$bwPasswordPlainText = ""
			$password1Encrypted = ""
			$password1PlainText = ""
			$password2Encrypted = ""
			$password2PlainText = ""
			exit 1
		}
		else {
			Write-Host "Password verified. Be sure to save your password in a safe place!"
			$encryptedDataBackup = $true
		}
	}
	else {
		Write-Host -ForegroundColor Yellow "WARNING!" -NoNewLine
		Write-Host " Your vault contents will be saved to an unencrypted file."

		if ((AskYesNoQuestion -prompt "Continue? [y/n]") -eq "n") {
			LockAndLogout
			Write-Host "Exiting script."
			$env:BW_SESSION = ""
			$bwPasswordEncrypted = ""
			$bwPasswordPlainText = ""
			$password1Encrypted = ""
			$password1PlainText = ""
			$password2Encrypted = ""
			$password2PlainText = ""
			exit 1
		}
	}

	Write-Host ""
	Write-Host "Performing vault exports..."
	Write-Host ""

	if (!$encryptedDataBackup) {
		Write-Host "Exporting personal vault to an unencrypted file..."
		./bw export --format json --output $saveFolder
		Write-Host ""
	}
	else {
		Write-Host "Exporting personal vault to a password-encrypted file..."
		./bw export --format encrypted_json --password "$password1PlainText" --output $saveFolder
		Write-Host ""
	}

  	$organizations = (./bw list organizations | ConvertFrom-Json)

  	if ($organizations.Count -gt 0) {
  		foreach ($organization in $organizations) {
  			$organizationID = $organization.id
  			$organizationName = $organization.name

  			if (!$encryptedDataBackup) {
  				Write-Host "Exporting organization vault for organization ""$organizationName"" to an unencrypted file..."
  				./bw export --organizationid $organizationID --format json --output $saveFolder
  				Write-Host ""
  			}
  			else {
  				Write-Host "Exporting organization vault for organization ""$organizationName"" to a password-encrypted file..."
  				./bw export --organizationid $organizationID --format encrypted_json --password "$password1PlainText" --output $saveFolder
  				Write-Host ""
  			}
  		}
  	}
	else { Write-Host "No organizational vault exists, so nothing to export." }

	# 3. Download all attachments (file backup)
	# First download attachments in vault
	$itemsWithAttachments = (./bw list items | ConvertFrom-Json | Where-Object { $_.attachments -ne $null })

	if ($itemsWithAttachments.Count -gt 0) {
		Write-Host "Saving attachments..."

		foreach ($item in $itemsWithAttachments) {
			foreach ($attachment in $item.attachments) {
				$filePath = Join-Path $saveFolderAttachments $item.name

				if ($IsWindows) { $filePath = $filePath + "\" }
				else { $filePath = $filePath + "/" }

				./bw get attachment "$($attachment.fileName)" --itemid $item.id --output $filePath
				if ($IsWindows) { Write-Host "" }
			}
		}
	}
	else { Write-Host "No attachments exist, so nothing to export." }

	Write-Host -ForegroundColor Green "Vault export complete."

	# 4. Report items in the Trash (cannot be exported)
	$trashCount = (./bw list items --trash | ConvertFrom-Json).Count

	if ($trashCount -gt 0) {
		Write-Host -ForegroundColor Yellow "Note:" -NoNewLine
		Write-Host " You have $trashCount items in the trash that cannot be exported."
	}

	LockAndLogout

	if ((AskYesNoQuestion -prompt "Compress? [y/n]") -eq "y") {
		Write-Host "Compressing backup..." -NoNewLine
		Set-Location -Path $saveFolder

		$zipFileTestPath = Join-Path ".." "$userEmail.zip"
		if (Test-Path $zipFileTestPath) { Remove-Item -Path $zipFileTestPath }

		Compress-Archive -Path * -DestinationPath "$userEmail.zip" -Force
		Move-Item -Path "$userEmail.zip" -Destination ..
		Set-Location -Path ..
		Remove-Item -Path $saveFolder -Recurse -Force

		Write-Host " Done."
	}

	Write-Host -ForegroundColor Green "Script completed."
}
finally {
	$env:BW_SESSION = ""
	$bwPasswordEncrypted = ""
	$bwPasswordPlainText = ""
	$password1Encrypted = ""
	$password1PlainText = ""
	$password2Encrypted = ""
	$password2PlainText = ""
}