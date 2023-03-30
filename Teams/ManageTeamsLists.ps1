if (Get-Module -ListAvailable -Name PnP.PowerShell) {
    Write-Host "Module [PnP.PowerShell] exists"
} 
else {
    Write-Host "Module [PnP.PowerShell] does not exist. Installing Module..."
    Install-Module PnP.PowerShell -Force
}

##List Available Lists
#Get-PnPList | Out-GridView -PassThru 

function New-ListEntry {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        [Parameter(Mandatory = $true)]
        [string]$Value1,
        [string]$SiteUrl = "https://xxTenantxx.sharepoint.com/sites/xxSiteNamexx"
    )
    $ListName = "ListName"
    Connect-PnPOnline -Url $SiteUrl -Interactive
    $List = Get-PnPList -Identity $ListName
    ##Get Fieldnames
    #$Item = Get-PnPListItem -List $List  | Select-Object -First 1 
    #$Item.Fieldvalues | ft
    $Values = @{
        "Title"  = $HostName
        "Value1" = $Value1
    }
    Add-PnPListItem -List $List -Values $Values -Verbose
}


function Get-ListEntryByValue {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Value1,
        [string]$SiteUrl = "https://xxTenantxx.sharepoint.com/sites/xxSiteNamexx"
    )
    $ListName = "Emergency CHG list - $Environment"
    Connect-PnPOnline -Url $SiteUrl -Interactive
    $List = Get-PnPList -Identity $ListName
    $Items = Get-PnPListItem -List $List -Query "<View><Query><Where><Eq><FieldRef Name='Value1'/><Value Type='Text'>$Value1</Value></Eq></Where></Query></View>"
    #$Items = Get-PnPListItem -List $List
    $objList = @()
    
    foreach ($item in $Items) {
        $myObject = [PSCustomObject]@{
            ID       = $item.FieldValues["ID"]
            HostName = $item.FieldValues["Title"]
            Value1   = $item.FieldValues["Value1"]
         
        }
        $objList += $myObject
        
    }

    $objList
}

function Update-ListEntry {
    param
    (
  
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        [string]$Value1,
       
        [string]$SiteUrl = "https://xxTenantxx.sharepoint.com/sites/xxSiteNamexx"
    )
    $ListName = "ListName"
    Connect-PnPOnline -Url $SiteUrl -Interactive
    $List = Get-PnPList -Identity $ListName
	
    ##Get Fieldnames
    #$Item = Get-PnPListItem -List $List  | Select-Object -First 1 
    #$Item.Fieldvalues | ft
	
    $Item = Get-PnPListItem -List $List -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$Hostname</Value></Eq></Where></Query></View>"
    $Values = @{
        "Value1" = $Value1
    }
    Set-PnPListItem -List $List -Identity $Item -Values $Values

}





