<#
.SYNOPSIS
  Connects to Azure and add a new data disk to an existing virtual machine (ARM only) in a resource group.

.DESCRIPTION
  This runbook connects to Azure and performs the following tasks :
  	- Stops the specified virtual machine
  	- Creates an empty data disk under the "vhds" blob of the specified storage account
	- Attaches this data disk to the specified virtual machine
	- Updates the specified virtual machine
	- Starts the specified virtual machine
  You can attach a schedule to this runbook to run it at a specific timer or modifiy it to remediate to an OMS alert.

.PARAMETER AzureCredentialAssetName
   Optional with default of "AzureCredential".
   The name of an Automation credential asset that contains the Azure AD user credential with authorization for this subscription. 
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.

.PARAMETER AzureSubscriptionIdAssetName  
   Optional with default of "SubscriptionId".  
   The name of An Automation variable asset that contains the GUID for this Azure subscription.  
   To use an asset with a different name you can pass the asset name as a runbook input parameter or change the default value for the input parameter.  

.PARAMETER VMName
   Mandatory with no default.
   The name of the virtual machine which you want to add a new data disk.
   It must be the name of an ARM virtual machine.

.PARAMETER ResourceGroupName
   Mandatory with no default.
   The name of the resource group which contains the targeted virtual machine. 
 
.PARAMETER StorageAccountName  
   Mandatory with no default.
   The name of the storage account which will contains the new data disk.
   It must be the name of an ARM storage account. 
   
.PARAMETER DataDiskName
   Optinal with default of "ExternalStorage".
   The name of the data disk you want to add to the targeted virtual machine.
   Ensure the name is not used before running this runbook.
   
.PARAMETER DataDiskSizeInGB
   Optional with default of "1023".
   The size in gigabytes of the data disk you want to create.
   To know more about maximum data disks you can add to a virtual machine, see this link https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-size-specs/ 
   
.NOTES
   LASTEDIT: January 30, 2016
#>

param (
    [Parameter(Mandatory=$false)] 
    [String] $AzureCredentialAssetName = 'AzureCredential',
	
    [Parameter(Mandatory=$false)] 
    [String] $AzureSubscriptionIdAssetName = 'AzureSubscriptionId',
             
    [parameter(Mandatory=$true)] 
    [String] $VMName,
	
    [parameter(Mandatory=$true)] 
    [String] $ResourceGroupName,
	
    [parameter(Mandatory=$true)] 
    [String] $StorageAccountName,  

    [parameter(Mandatory=$false)] 
    [string] $DataDiskName = 'ExternalStorage',
	
    [parameter(Mandatory=$false)] 
    [int] $DataDiskSizeInGB = '1023'
) 
	    
# Getting automation assets
$AzureCred = Get-AutomationPSCredential -Name $AzureCredentialAssetName -ErrorAction Stop
$SubId = Get-AutomationVariable -Name $AzureSubscriptionIdAssetName -ErrorAction Stop

# Connecting to Azure
$null = Add-AzureRmAccount -Credential $AzureCred -ErrorAction Stop
$null = Select-AzureRmSubscription -SubscriptionId $SubId -ErrorAction Stop

# Getting the virtual machine
$VM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction Stop

# Generating a LUN number
$Lun = $VM.DataDiskNames.Count + 1

"Shutting down the virtual machine ..."
$RmPState = (Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).Statuses.Code[1]

if ($RmPState -eq 'PowerState/deallocated')
{
    "$VMName is already shut down."
}
else
{
    $StopSts = $VM | Stop-AzureRmVM -Force -ErrorAction Stop
    "The virtual machine has been stopped."
}

"Adding an empty data disk to the virtual machine ..."
$VHDUri = "https://$StorageAccountName.blob.core.windows.net/vhds/$DataDiskName.vhd"
$null = Add-AzureRmVMDataDisk -VM $VM -Name $DataDiskName -VhdUri $VHDUri -LUN $Lun -Caching ReadOnly -DiskSizeinGB $DataDiskSizeInGB -CreateOption Empty -ErrorAction Stop
$UpdateSts = $VM | Update-AzureRmVM -ErrorAction Stop

"`tStatus : Success"
"`tLUN : $Lun"
"`tName : $DataDiskName"
"`tSize : $DataDiskSizeInGB"
"`tUri : $VHDUri"
"`tCaching : ReadOnly"
"`tOption : Empty"
"`tImage : Null"
"`tStorage account : $StorageAccountName"
"`tVirtual machine : $VMName"

"Starting the virtual machine ..."
$StartSts = $VM | Start-AzureRmVM -ErrorAction Stop
"The virtual machine has been started."