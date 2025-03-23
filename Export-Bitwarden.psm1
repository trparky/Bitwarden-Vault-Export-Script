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

function Export-Bitwarden { # Don't touch this line!
	param (
		[switch]$forcebwcliupdate,
		[switch]$forcelogout,
		[switch]$compress,
		[switch]$encrypt,
		[switch]$continue
	)

	# This tells the script if it should automatically check for an update of the Bitwarden CLI executable that's actually responsible for backing up your Bitwarden vault.
	# It does this by taking the version of your currently existing Bitwarden CLI and comparing it to the version that's contained in a small text file that's on my GitHub
	# page. Now, if you don't want this to happen, you can disable this kind of functionality in the script by setting the value of the $checkForBWCliUpdate to $false.
	# However, it's highly recommended that you do keep this setting enabled since keeping your Bitwarden CLI up to date is obviously a good thing to do.
	$checkForBWCliUpdate = $true
	if ($forcebwcliupdate) { $checkForBWCliUpdate = $true }

	$currentLocation = Get-Location

	try {
		# ====================================================
		# == WARNING!!! DO NOT TOUCH ANYTHING BELOW THIS!!! ==
		# ====================================================

		$ver = "1.50"

		Write-Host -ForegroundColor Green "========================================================================================"
		Write-Host -ForegroundColor Green "==                        Bitwarden Vault Export Script v$ver                         =="
		Write-Host -ForegroundColor Green "== Originally created by David H, converted to a Powershell Script by Thomas Parkison =="
		Write-Host -ForegroundColor Green "==              https://github.com/trparky/Bitwarden-Vault-Export-Script              =="
		Write-Host -ForegroundColor Green "========================================================================================"
		Write-Host ""

		try {
			$jsonData = (Invoke-WebRequest -Uri "https://api.github.com/repos/trparky/Bitwarden-Vault-Export-Script/releases/latest").Content | ConvertFrom-Json
			$scriptVersionFromWeb = ($jsonData.tag_name) -replace "v", ""
		}
		catch { $scriptVersionFromWeb = $ver }

		if ($scriptVersionFromWeb -ne $ver) {
			Write-Host -ForegroundColor Green "Notice:" -NoNewline

			if ($PSScriptRoot -Match "powershell/Modules" || $PSScriptRoot -Match "powershell\\Modules") {
				Write-Host " There is an update to this script, please execute Update-Module at the Powershell prompt."
			}
			else {
				Write-Host " There is an update to this script, please go to https://github.com/trparky/Bitwarden-Vault-Export-Script and download the new version."
			}

			Write-Host ""
		}

		function DownloadBWCli {
			$zipFilePath = (Join-Path $PSScriptRoot "bw.zip")

			$baseDownloadURL = "https://vault.bitwarden.com/download/?app=cli&platform="

			if ($IsWindows) { Invoke-WebRequest -Uri ($baseDownloadURL + "windows") -OutFile $zipFilePath }
			elseif ($IsLinux) { Invoke-WebRequest -Uri ($baseDownloadURL + "linux") -OutFile $zipFilePath }
			elseif ($IsMacOS) { Invoke-WebRequest -Uri ($baseDownloadURL + "macos") -OutFile $zipFilePath }

			Set-Location -Path $PSScriptRoot
			Expand-Archive -Path $zipFilePath

			if ($IsLinux || $IsMacOS) {
				Move-Item -Path (Join-Path $PSScriptRoot "bw" "bw") -Destination (Join-Path $PSScriptRoot "bw.tmp")
				Remove-Item -Force (Join-Path $PSScriptRoot "bw")
				Move-Item -Path (Join-Path $PSScriptRoot "bw.tmp") -Destination (Join-Path $PSScriptRoot "bw")
				chmod 755 (Join-Path $PSScriptRoot "bw")
			}
			elseif ($IsWindows) {
				if (Test-Path -Path (Join-Path $PSScriptRoot "bw" "bw.exe")) {
					Move-Item -Path (Join-Path $PSScriptRoot "bw" "bw.exe") -Destination (Join-Path $PSScriptRoot "bw.exe")
					Remove-Item -Force (Join-Path $PSScriptRoot "bw")
				}
			}

			Remove-Item -Path $zipFilePath

			Write-Host " Done."
			Write-Host ""
		}

		function ValidateEmailAddress {
			param (
				[string]$email
			)

			# Pattern comes from https://emailregex.com/index.html
			$emailPattern = '\A(?:(?:[a-z0-9!#$%&''*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&''*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\]))\Z'
			$regex = New-Object System.Text.RegularExpressions.Regex $emailPattern

			return $regex.IsMatch($email)
		}

		function ShouldWeCheckForABWCLIUpdate {
			$currentDate = Get-Date
			$checkForLastUpdateFile = Join-Path $PSScriptRoot "lastcheckforupdate.txt"

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

		function LockAndLogout {
		      	& $bwCliBinName lock
		      	Write-Host ""

		      	& $bwCliBinName logout
		      	Write-Host ""
		}

		if ($IsWindows) { $bwCliBinName = (Join-Path $PSScriptRoot "bw.exe") }
		else { $bwCliBinName = (Join-Path $PSScriptRoot "bw") }

		if (!(Test-Path -Path $bwCliBinName)) {
			Write-Host "Bitwarden CLI application not found, downloading... Please Wait." -NoNewLine
			DownloadBWCli
			Get-Date | Out-File -FilePath (Join-Path $PSScriptRoot "lastcheckforupdate.txt") -NoNewline
			Set-Location -Path $currentLocation
		}
		else {
			if (($checkForBWCliUpdate) -and (($forcebwcliupdate) -or (ShouldWeCheckForABWCLIUpdate))) {
				if ($forcebwcliupdate) {
					Write-Host -ForegroundColor Green "Notice:" -NoNewLine
					Write-Host " Script executed with ForceBWCliUpdate flag." -NoNewLine
				}

				$localBWCliVersion = ((& $bwCliBinName --version) | Out-String).Trim()
				$remoteBWCliVersion = (Invoke-WebRequest -Uri "https://trparky.github.io/bwcliversion.txt").Content.Trim()

				if ($localBWCliVersion -ne $remoteBWCliVersion) {
					Write-Host ""
					Write-Host ""
					Write-Host "Bitwarden CLI application update found, downloading... Please Wait." -NoNewLine
					Remove-Item -Path $bwCliBinName
					DownloadBWCli
					Set-Location -Path $currentLocation
				}
				else {
					Write-Host " No update found."
					Write-Host ""
				}
			}
		}

		if ((& $bwCliBinName status | ConvertFrom-Json).status -eq "unlocked") {
			Write-Host -ForegroundColor Green "Notice:" -NoNewLine
			Write-Host " Active Bitwarden CLI login session detected, using existing login session."
			Write-Host "The next step will ask for your Bitwarden username but only for the sake of knowing where to save your exported data."
			Write-Host ""
		}

		if ($forcelogout) {
      			LockAndLogout
      			Write-Host "Exiting script."
      			$env:BW_SESSION = ""
      			$bwPasswordEncrypted = ""
      			$bwPasswordPlainText = ""
      			$password1Encrypted = ""
      			$password1PlainText = ""
      			$password2Encrypted = ""
      			$password2PlainText = ""
      			return
		}

		# Prompt user for their Bitwarden username
		if ($userEmail -eq $null) {
			$userEmail = Read-Host "Enter your Bitwarden Username"
		}

		if (!(ValidateEmailAddress -email $userEmail)) {
			Write-Host -ForegroundColor Red "ERROR:" -NoNewline
			Write-Host " Invalid email address. Script halted."
			return
		}

		$saveFolder = Join-Path $currentLocation $userEmail

		if ($IsWindows) { $saveFolder = $saveFolder + "\" }
		else { $saveFolder = $saveFolder + "/" }

		$saveFolderAttachments = Join-Path $saveFolder "attachments"

		if ($userPassword) {
			$bwPasswordEncrypted = ConvertTo-SecureString $userPassword -AsPlainText -Force
		}

		if ((& $bwCliBinName status | ConvertFrom-Json).status -ne "unlocked") {
			if ($bwPasswordEncrypted -eq $null) {
				# Prompt user for their Bitwarden password
				$bwPasswordEncrypted = Read-Host "Enter your Bitwarden Password" -AsSecureString
			}
			Write-Host ""

			# Login user if not already authenticated
			if ((& $bwCliBinName status | ConvertFrom-Json).status -eq "unauthenticated") {
				Write-Host "Performing login..."
				$bwPasswordPlainText = ConvertSecureString -String $bwPasswordEncrypted
				& $bwCliBinName login "$userEmail" "$bwPasswordPlainText" --quiet
			}

			if ((& $bwCliBinName status | ConvertFrom-Json).status -eq "unauthenticated") {
				Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
				Write-Host " Failed to authenticate."
				return
			}

			# Unlock the vault
			$bwPasswordPlainText = ConvertSecureString -String $bwPasswordEncrypted
			$sessionKey = (& $bwCliBinName unlock "$bwPasswordPlainText" --raw) | Out-String

			# Verify that unlock succeeded
			if ([String]::IsNullOrWhiteSpace($sessionKey)) {
				Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
				Write-Host " Failed to authenticate."
				return
			}
			else { Write-Host "Login successful." }

			# Export the session key as an env variable (needed by bw.exe CLI)
			$env:BW_SESSION = $sessionKey
		}

		$encryptedDataBackup = $false

		Write-Host ""
		if ($encrypt) {
			if($encryptPassword -eq $null) {
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
					return
				}
				else {
					Write-Host "Password verified. Be sure to save your password in a safe place!"
					$encryptedDataBackup = $true
				}
			}
			else {
				$password1Encrypted = ConvertTo-SecureString $encryptPassword -AsPlainText -Force
			}
		}
		else {
			Write-Host -ForegroundColor Yellow "WARNING!" -NoNewLine
			Write-Host " Your vault contents will be saved to an unencrypted file."

			if (!$continue) {
				Write-Host -ForegroundColor Red "ERROR:" -NoNewLine
				Write-Host " Rerun the script with the -continue option."
				LockAndLogout
				Write-Host "Exiting script."
				$env:BW_SESSION = ""
				$bwPasswordEncrypted = ""
				$bwPasswordPlainText = ""
				$password1Encrypted = ""
				$password1PlainText = ""
				$password2Encrypted = ""
				$password2PlainText = ""
				return
			}
		}

		Write-Host ""
		Write-Host "Performing vault exports..."
		Write-Host ""

		if (!(Test-Path -Path $saveFolder)) { New-Item -ItemType Directory -Path $saveFolder | Out-Null }

		if (!$encryptedDataBackup) {
			Write-Host "Exporting personal vault to an unencrypted file..."
			& $bwCliBinName export --format json --output $saveFolder
			Write-Host ""
		}
		else {
			Write-Host "Exporting personal vault to a password-encrypted file..."
			& $bwCliBinName export --format encrypted_json --password "$password1PlainText" --output $saveFolder
			Write-Host ""
		}

	  	$organizations = (& $bwCliBinName list organizations | ConvertFrom-Json)

	  	if ($organizations.Count -gt 0) {
	  		foreach ($organization in $organizations) {
	  			$organizationID = $organization.id
	  			$organizationName = $organization.name

	  			if (!$encryptedDataBackup) {
	  				Write-Host "Exporting organization vault for organization ""$organizationName"" to an unencrypted file..."
	  				& $bwCliBinName export --organizationid $organizationID --format json --output $saveFolder
	  				Write-Host ""
	  			}
	  			else {
	  				Write-Host "Exporting organization vault for organization ""$organizationName"" to a password-encrypted file..."
	  				& $bwCliBinName export --organizationid $organizationID --format encrypted_json --password "$password1PlainText" --output $saveFolder
	  				Write-Host ""
	  			}
	  		}
	  	}
		else { Write-Host "No organizational vault exists, so nothing to export." }

		# 3. Download all attachments (file backup)
		# First download attachments in vault
		$itemsWithAttachments = (& $bwCliBinName list items | ConvertFrom-Json | Where-Object { $null -ne $_.attachments })

		if ($itemsWithAttachments.Count -gt 0) {
			Write-Host "Saving attachments..."

			foreach ($item in $itemsWithAttachments) {
				foreach ($attachment in $item.attachments) {
					$filePath = Join-Path $saveFolderAttachments $item.name

					if ($IsWindows) { $filePath = $filePath + "\" }
					else { $filePath = $filePath + "/" }

					& $bwCliBinName get attachment "$($attachment.fileName)" --itemid $item.id --output $filePath

					if ($IsWindows) { Write-Host "" }
				}
			}
		}
		else { Write-Host "No attachments exist, so nothing to export." }

		Write-Host -ForegroundColor Green "Vault export complete."

		# 4. Report items in the Trash (cannot be exported)
		$trashCount = (& $bwCliBinName list items --trash | ConvertFrom-Json).Count

		if ($trashCount -gt 0) {
			Write-Host -ForegroundColor Yellow "Note:" -NoNewLine
			Write-Host " You have $trashCount items in the trash that cannot be exported."
		}

		LockAndLogout

		if ($compress) {
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
		Set-Location -Path $currentLocation
	}
}