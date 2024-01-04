# Bitwarden Vault Export Script
As stated in the script file, the script is based upon another (Bash) script created by "David H". I took his script, added much more functionality, and eventually converted it over to a Powershell script.

Starting with Version 1.17 it's even easier to use this script. The script does everything for you. All you have to do is run it, it will download the Bitwarden CLI program (if it needs to). There's so many new improvements to the code from the original version that makes this script surpass the original script written by David H by leaps and bounds.

# Advanced Environment Setup
Drop the files into a folder of your choosing and then open up your "Microsoft.PowerShell_profile.ps1" that can be found in the "Powershell" folder in your Documents folder and add the following line...
Import-Module "Path\To\Export-Bitwarden.psd1"

Once this is complete, you can then execute Export-Bitwarden anywhere you want instead of being confined to a specific folder on your system. For backwards compatibility and ease of use, the bw_export.ps1 script still exists and functions much like it did before except it references Export-Bitwarden.psm1.

# Dev Branch
All active development will now take place in the dev branch.

# Open Source!!!
Yes, this is open source and licensed under the MIT license. What does this mean? It means that you, the user, can fork this project, make your additions, and create a pull request for me to include your additions and improvements back to the original script. Isn't open source cool? I think so!
