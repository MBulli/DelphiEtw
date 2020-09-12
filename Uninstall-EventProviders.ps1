<#
.SYNOPSIS
    Uninstalls ETW providers given a valid manifest xml file.
.DESCRIPTION
    Uninstalls ETW providers as defined in a valid manifest xml file.
    This script needs to be run as admin as the providers are uninstalled system wide.
    If the script is called in a non-elevated session wevtutil will be run as admin.
    Note that in this case the output of wevtutil hidden and user input is required!
.PARAMETER ManifestFile
    The path to the manifest file to uninstall.
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
    $ManifestFile
)

$IsElevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if(!$IsElevated) {
    Write-Warning "The script is called in a non-elevated session. The output of wevtutil will be hidden and user input is required!"
}

# Make path absolute
$ManifestFile = (Resolve-Path -Path $ManifestFile).Path

Write-Host "Uninstalling $ManifestFile..."

if (!$IsElevated) {
    Start-Process -FilePath wevtutil.exe -ArgumentList "uninstall-manifest $ManifestFile" -Verb RunAs -Wait
} else {
    wevtutil uninstall-manifest $ManifestFile
}


