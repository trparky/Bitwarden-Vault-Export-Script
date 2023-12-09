# Bitwarden Vault Export Script
As stated in the script file, the script is based upon another (Bash) script created by "David H". I took his script, added much more functionality, and eventually converted it over to a Powershell script.

# Environment Setup
In order for this Powershell script to work and you know, export your Bitwarden Vault, you'll need the Bitwarden CLI executable. You can get it by going to https://bitwarden.com/download/ and scrolling down to the section that reads "Command Line Interface". In the case of this script, since it was built to run on Windows, you'll want to choose the Windows version.

Once you have the BW.EXE file, simply drop it into the same folder as you have this script.

**Note:** There's a possibility that this script *may* work on any operating system that Powershell can be installed on. So far, I've only tested on Ubuntu in WSL.

# Organization Configuration
$orgId, this is the variable that you need to set in order to export your organization data. In order to get your organization GUID, do the following...
bw.exe login
(follow the prompts)
bw.exe list organizations | ConvertFrom-Json | Select-Object -ExpandProperty Id

For example...
![image](https://github.com/trparky/Bitwarden-Vault-Export-Script/assets/32105035/8639888a-d1bd-4804-94bb-77dcd91499d7)

A GUID looks like this... 14fc2739-eb67-4e20-b39a-1c492e4fdaac

Copy that and put it into the $orgId variable and then execute ./bw_export.ps1 and follow the prompts.

That's all there is to it.

# Open Source!!!
Yes, this is open source and licensed under the MIT license. What does this mean? It means that you, the user, can fork this project, make your additions, and create a pull request for me to include your additions and improvements back to the original script. Isn't open source cool? I think so!
