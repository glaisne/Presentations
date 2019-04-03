
Write-Verbose "[$(Get-Date -format G)] Install DSC requirements"
Write-Verbose "[$(Get-Date -format G)]  - Nuget"
$null = Install-PackageProvider -Name 'Nuget' -Force
$null = Set-PackageSource -Name psgallery -Trust
<#
* Fix pester not installing 
- The version '4.4.0' of the module 'Pester' being installed is not catalog signed. Ensure that the version '4.4.0' of the module 'Pester' has the catalog file 'Pester.cat' and signed with the same publisher 'CN=Microsoft Root Certificate Authority 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' as the previously-installed module '4.4.0' with version '3.4.0' under the directory 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0'. If you still want to install or update, use -SkipPublisherCheck parameter.
#>
Write-Verbose "[$(Get-Date -format G)]  - Pester"
$null = Install-Module -Name Pester -Repository PSGallery -AllowClobber -Force -SkipPublisherCheck

Write-Verbose "[$(Get-Date -format G)]  - PSDscResources"
$null = Install-Module -Name PSDscResources -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xActiveDirectory"
$null = Install-Module -Name xActiveDirectory -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xStorage"
$null = Install-Module -Name xStorage -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xRemoteDesktopAdmin"
$null = Install-Module -Name xRemoteDesktopAdmin -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xNetworking"
$null = Install-Module -Name xNetworking -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xComputerManagement"
$null = Install-Module -Name xComputerManagement -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - xPendingReboot"
$null = Install-Module -Name xPendingReboot -Repository PSGallery -AllowClobber -Force

Write-Verbose "[$(Get-Date -format G)]  - chocolatey"
$null = Find-PackageProvider chocolatey | Install-PackageProvider -Force
Set-PackageSource -Name chocolatey -Trusted
$null = Find-Package dotnet4.5.2 | Install-Package -Verbose
Set-PackageSource -Name chocolatey -Trusted:$false
