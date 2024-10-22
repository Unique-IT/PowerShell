<#
.SYNOPSIS
Retrieves user profiles from the ProfileList in the Windows Registry.
.DESCRIPTION
This function lists user profiles stored in the `ProfileList` registry key, with options to exclude system and local accounts.
.PARAM ExcludeSystemAccounts
A switch to exclude system and service accounts, which typically have well-known SID prefixes.
.PARAM ExcludeLocalAccounts
A switch to exclude local accounts such as Administrator and Guest.
.OUTPUTS
A list of custom objects representing the user profiles.
#>
function Get-UserProfiles {
    param (
        [switch]$ExcludeSystemAccounts,
        [switch]$ExcludeLocalAccounts
    )
    # Define the registry path for ProfileList
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    # Get all subkeys (representing user profiles)
    $profileKeys = Get-ChildItem -Path $regPath
    # Create a list to store profile information
    $profileList = @()
    # Loop through each profile key to extract details
    foreach ($profileKey in $profileKeys) {
        # Get the SID (key name)
        $sid = $profileKey.PSChildName
        # Exclude system and service accounts based on their SID prefix
        if ($ExcludeSystemAccounts) {
            if ($sid -match "^S-1-5-(18|19|20|80)") {
                continue
            }
        }
        # Exclude local accounts (usually have SID starting with S-1-5-21 but limited to built-in local accounts)
        if ($ExcludeLocalAccounts) {
            if ($sid -match "^S-1-5-21-.+-500$" -or $sid -match "^S-1-5-21-.+-501$") {
                continue
            }
        }
        # Get the profile path and other information from the registry
        $profilePath = (Get-ItemProperty -Path $profileKey.PSPath).ProfileImagePath
        $profileState = (Get-ItemProperty -Path $profileKey.PSPath).State
        # Add profile information to the list
        $profileList += [pscustomobject]@{
            SID          = $sid
            ProfilePath  = $profilePath
            ProfileState = $profileState
        }
    }
    $profileList
}
<#
.SYNOPSIS
Removes a user profile from the ProfileList in the Windows Registry.
.DESCRIPTION
This function removes a specified SID from the `ProfileList` registry key, effectively removing the user's profile from the registry.
.PARAM SID
The Security Identifier (SID) of the profile to remove.
.EXAMPLE
Remove-SIDFromProfileList -SID "S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX-XXXXX"
.OUTPUTS
This function does not return a value.
#>
function Remove-SIDFromProfileList {
    param (
        [string]$SID
    )
    # Define the registry path for ProfileList
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    # Define the full path for the SID in the registry
    $sidRegPath = "$regPath\$SID"
    try {
        # Check if the SID exists in the registry
        if (Test-Path -Path $sidRegPath) {
            # Remove the SID key from the registry
            Remove-Item -Path $sidRegPath -Recurse -Force
            Write-Host "Successfully removed SID $SID from ProfileList."
        } else {
            Write-Host "SID $SID not found in ProfileList."
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}
<#
.SYNOPSIS
Finds a user in Active Directory by SID.
.DESCRIPTION
This function looks up a user's account details in Active Directory based on their Security Identifier (SID). It retrieves properties such as the SAM account name.
.PARAM SID
The Security Identifier (SID) to search for in Active Directory.
.OUTPUTS
Custom object containing the SAM account name, display name, and distinguished name of the user.
.EXAMPLE
Get-ADUserFromSID -SID "S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX-XXXXX"
#>
function Get-ADUserFromSID {
    param (
        [string]$SID
    )
    try {
        # Convert the SID string to a SecurityIdentifier object
        $securityIdentifier = New-Object System.Security.Principal.SecurityIdentifier($SID)
        if (-not $securityIdentifier) {
            throw "Invalid SID format"
        }
        # Convert the SID to a byte array for LDAP query
        $sidBytes = New-Object byte[] ($securityIdentifier.BinaryLength)
        $securityIdentifier.GetBinaryForm($sidBytes, 0)
        $ldapSid = ""
        # Convert each byte to hex format and join with a backslash for LDAP filter
        foreach ($byte in $sidBytes) {
            $ldapSid += "\" + "{0:X2}" -f $byte
        }
        # Build the LDAP filter to search by objectSid
        $ldapFilter = "(objectSid=$ldapSid)"
        # Define the domain or search root (for a domain use the full distinguished name)
        $rootDSE = [ADSI]"LDAP://RootDSE"
        $domainDN = $rootDSE.defaultNamingContext
        # Perform the LDAP search
        $searcher = New-Object DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = "LDAP://$domainDN"
        $searcher.Filter = $ldapFilter
        $searcher.PropertiesToLoad.Add("samAccountName") | Out-Null
        # Execute the search
        $result = $searcher.FindOne()
        if ($result -ne $null) {
            $user = @{
                SAMAccountName    = $result.Properties["samAccountName"][0]
                DisplayName       = $result.Properties["displayName"][0]
                DistinguishedName = $result.Properties["distinguishedName"][0]
            }
            # Output the user information
            [pscustomobject]$user
        } else {
            #Write-Host "No user found for SID: $SID"
        }
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}
# Script to loop through profiles and remove profiles with no matching AD user
Get-UserProfiles -ExcludeSystemAccounts -ExcludeLocalAccounts | ForEach-Object {
    $CurrentProfile = $_
    $aduser = Get-ADUserFromSID -SID $CurrentProfile.SID
    if ($aduser -eq $null) {
        # If no AD user was found remove the profile
        Write-Host "User not found for SID: $($CurrentProfile.SID) - Removing Profile $($CurrentProfile.ProfilePath)" -ForegroundColor Red
        if (Test-Path -Path $CurrentProfile.ProfilePath) {
            Remove-Item -Path $CurrentProfile.ProfilePath -Recurse -Force
            Write-Host "Profile $($CurrentProfile.ProfilePath) removed" -ForegroundColor Green
        }
        Remove-SIDFromProfileList -SID $CurrentProfile.SID
        $CurrentProfile = $null
    }
}
