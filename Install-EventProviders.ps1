<#
.SYNOPSIS
    Registers ETW providers given a valid manifest xml file.
.DESCRIPTION
    Registers ETW providers as defined in a valid manifest xml file.
    Optionally allows to set the resourceFileName and messageFileName attributes before calling wevtutil.exe.
    This script needs to be run as admin as the providers are registered system wide.
    If the script is called in a non-elevated session wevtutil will be run as admin.
    Note that in this case the output of wevtutil hidden and user input is required!
.PARAMETER ManifestFile
    The path to the manifest file to register.
.PARAMETER ProviderBinaryFile
    If not null the resourceFileName and messageFileName attributes 
    of the manifest xml file are set to this path.
    This is usually the exe or dll containing the resource files genereted by mc.exe.
    The new manifest file will be written to ManifestFile.mod.
.PARAMETER OverwriteManifest
    Use this switch in combination with the ProviderBinaryFile parameter.
    If Overwrite is set the original provided manifest file will be overwritten with the modified XML.
.PARAMETER PrintInfo
    Use this switch to query providers metadata after installation.
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({
        if( -Not ($_ | Test-Path -PathType Leaf) ){
            throw "Manifest file not found"
        }
        return $true
    })]
    [System.IO.FileInfo]
    $ManifestFile,

    [Parameter(Mandatory=$false)]
    [ValidateScript({
        if( -Not ($_ | Test-Path -PathType Leaf) ){
            throw "Provider binary file not found"
        }
        return $true
    })]
    [System.IO.FileInfo]
    $ProviderBinaryFile,

    [Switch]
    $PrintInfo = $false,
    [Switch]
    $OverwriteManifest = $false
)

$IsElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$ProviderList = New-Object Collections.Generic.List[String]

if(!$IsElevated) {
    Write-Warning "The script is called in a non-elevated session. The output of wevtutil will be hidden and user input is required!"
}

# Make paths absolute
$ManifestFile = (Resolve-Path -Path $ManifestFile).Path
$ProviderBinaryFile = (Resolve-Path -Path $ProviderBinaryFile).Path

# Load XML
[xml]$manifest = Get-Content -Path $ManifestFile

$ns = new-object Xml.XmlNamespaceManager $manifest.NameTable
$ns.AddNamespace("ns", "http://schemas.microsoft.com/win/2004/08/events")

foreach ($provNode in $manifest.SelectNodes('//ns:events/ns:provider', $ns)) {
    Write-Host "Provider:" $provNode.GetAttribute("name")
    Write-Host "  resourceFileName ="  $provNode.GetAttribute("resourceFileName")
    Write-Host "  messageFileName  ="  $provNode.GetAttribute("messageFileName")

    if($ProviderBinaryFile) {
        Write-Host "  Updating resource and message filename attributes"
        $provNode.SetAttribute("resourceFileName", $ProviderBinaryFile)
        $provNode.SetAttribute("messageFileName", $ProviderBinaryFile)
    }

    if($PrintInfo) {
        $ProviderList.Add($provNode.GetAttribute("name"))
    }
}

if($ProviderBinaryFile) {
  if($OverwriteManifest) {
    Write-Host "Override manifest file with new attributes."
    $outfile = $ManifestFile    
  } else {
    Write-Host "Copy of manifest file with new attributes: $outfile"  
    $outfile = "$ManifestFile.tmp"
    $ManifestFileCopy = $outfile
  }
  
  $manifest.Save($outfile)
  $ManifestFile = $outfile
}

Write-Host "Installing $ManifestFile..."

if (!$IsElevated) {
    Write-Host "Uninstall existing provider"
    Start-Process -FilePath wevtutil.exe -ArgumentList "uninstall-manifest $ManifestFile" -Verb RunAs -Wait

    Write-Host "Install existing provider"
    Start-Process -FilePath wevtutil.exe -ArgumentList "install-manifest $ManifestFile" -Verb RunAs -Wait    
} else {
    Write-Host "Uninstall existing provider"
    wevtutil uninstall-manifest $ManifestFile
    Write-Host "Install provider"
    wevtutil install-manifest $ManifestFile    
}


if ($PrintInfo) {
    Write-Host "Query provider information..."
    foreach ($provName in $providerList) {
        Write-Host "$provName info:"
        wevtutil get-publisher $provName /ge:true
        Write-Host `r`n`r`n
    }    
}

if($ManifestFileCopy) {
    Write-Host "Removing temporary file $ManifestFileCopy." 
    Remove-Item $ManifestFileCopy
}