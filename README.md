# Bitwarden Vault Export Script
As stated in the script file, the script is based upon another (Bash) script created by "David H". I took his script, added much more functionality, and eventually converted it over to a Powershell script.

Starting with Version 1.17 it's even easier to use this script. The script does everything for you. All you have to do is run it, it will download the Bitwarden CLI program (if it needs to). There's so many new improvements to the code from the original version that makes this script surpass the original script written by David H by leaps and bounds.

# Advanced Environment Setup
If you want to be able to execute this script from anywhere you want instead of being confined to a specific folder on your system, you can install this script as a module. Luckily, I've provided an easy way to do this. Simply execute the install-module.ps1 script and it will modify your Powershell user profile appropriately.

Once this is complete, you can then execute Export-Bitwarden. For backwards compatibility and ease of use, the bw_export.ps1 script still exists and functions much like it did before except it references Export-Bitwarden.psm1.

# Dev Branch
All active development will now take place in the dev branch.

# Open Source!!!
Yes, this is open source and licensed under the MIT license. What does this mean? It means that you, the user, can fork this project, make your additions, and create a pull request for me to include your additions and improvements back to the original script. Isn't open source cool? I think so!

# Install from the Powershell Gallery
Installing this module is now even easier, all you have to do is execute...
Install-Module -Name Export-Bitwarden
And away you go. So much easier.
