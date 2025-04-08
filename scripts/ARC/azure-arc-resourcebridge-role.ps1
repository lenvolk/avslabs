# ------------------------ azure-arc-resourcebridge-role.ps1 ------------------------

# Ref: https://learn.microsoft.com/en-us/azure/azure-arc/resource-bridge/troubleshoot-resource-bridge#azure-arc-enabled-vmware-vcenter-issues
# Azure Arc Resource Bridge Required vSphere Role Creation Script
# Requires VMware PowerCLI
# Usage:
# - Update the variables below before running
# - Connect to vCenter: Connect-VIServer your-vcenter-server
# - Run script: .\azure-arc-resourcebridge-role.ps1

# ======== USER CONFIGURATION ==========
# Desired name for custom role
$RoleName = "AzureArc_ResourceBridgeRole"

# Account (user or group) that Arc should use, e.g. domain\arcsvc or just svcaccount
$UserAccount = "yourdomain\your_arc_account_here"

========================
try {
$entity = Get-Folder -Id 'Folder-group-d1' -ErrorAction Stop
} catch {
Write-Host "Could not find root folder 'Folder-group-d1'. Using root folder by name..." -ForegroundColor Yellow
$entity = Get-Folder -Name 'Datacenters'
}

Write-Host "Using root folder: $($entity.Name)"

List of required privilege IDs
$Privileges = @(
# Datastore
"Datastore.AllocateSpace"
"Datastore.Browse"
"Datastore.LowLevelFileOperations"
# Folder
"Folder.Create"
# vSphere Tagging
"InventoryService.Tagging.AssignTag"
# Network
"Network.Assign"
# Resource
"Resource.AssignVMToPool"
"Resource.MigratePoweredOffVM"
"Resource.MigratePoweredOnVM"
# Sessions
"Sessions.ValidateSession"
# vApp
"VApp.AssignResourcePool"
"VApp.Import"
# Virtual Machine Config
"VirtualMachine.Config.AddExistingDisk"
"VirtualMachine.Config.AddNewDisk"
"VirtualMachine.Config.AdvancedConfig"
"VirtualMachine.Config.ChangeCPUCount"
"VirtualMachine.Config.ChangeMemory"
"VirtualMachine.Config.ChangeSettings"
"VirtualMachine.Config.Copy"
"VirtualMachine.Config.EditDevice"
"VirtualMachine.Config.QueryUnownedFiles"
"VirtualMachine.Config.ReloadFromPath"
"VirtualMachine.Config.RemoveDisk"
"VirtualMachine.Config.Rename"
"VirtualMachine.Config.ResetGuestInfo"
"VirtualMachine.Config.Resource"
"VirtualMachine.Config.ManagedBy"
"VirtualMachine.Config.SetAnnotation"
"VirtualMachine.Config.UpgradeVirtualHardware"
"VirtualMachine.Config.ToggleForkParent"
"VirtualMachine.Config.ToggleDiskChangeTracking"
"VirtualMachine.Config.ExtendDisk"
"VirtualMachine.Config.QueryFTCompatibility"
"VirtualMachine.Config.AcquireDiskLease"
# Interaction
"VirtualMachine.Interact.PowerOn"
"VirtualMachine.Interact.PowerOff"
"VirtualMachine.Interact.Reset"
"VirtualMachine.Interact.Suspend"
"VirtualMachine.Interact.ConsoleInteract"
"VirtualMachine.Interact.DeviceConnection"
"VirtualMachine.Interact.GuestControl"
"VirtualMachine.Interact.InstallTools"
# Provisioning
"VirtualMachine.Provisioning.Clone"
"VirtualMachine.Provisioning.DeployTemplate"
"VirtualMachine.Provisioning.DiskRandomRead"
"VirtualMachine.Provisioning.DiskRandomReadWrite"
"VirtualMachine.Provisioning.DiskRead"
"VirtualMachine.Provisioning.DiskWrite"
"VirtualMachine.Provisioning.FileRead"
"VirtualMachine.Provisioning.FileWrite"
"VirtualMachine.Provisioning.MarkAsTemplate"
"VirtualMachine.Provisioning.MarkAsVM"
"VirtualMachine.Provisioning.ModifyCustSpecs"
"VirtualMachine.Provisioning.ReadCustSpecs"
# Guest operations
"VirtualMachine.GuestOperations.Modify"
"VirtualMachine.GuestOperations.ModifyAliases"
"VirtualMachine.GuestOperations.Query"
"VirtualMachine.GuestOperations.Execute"
# Snapshot
"VirtualMachine.State.CreateSnapshot"
"VirtualMachine.State.RemoveSnapshot"
"VirtualMachine.State.RevertToSnapshot"
# Inventory
"System.Anonymous"
"System.Read"
"System.View"
"System.Assign"
"VirtualMachine.Inventory.Create"
"VirtualMachine.Inventory.CreateFromExisting"
"VirtualMachine.Inventory.Delete"
"VirtualMachine.Inventory.Register"
"VirtualMachine.Inventory.Unregister"
)

$role = Get-VIRole -Name $RoleName -ErrorAction SilentlyContinue

if ($role) {
Write-Host "Role '$RoleName' already exists. Updating privileges..." -ForegroundColor Cyan
Set-VIRole -Role $role -Privilege $Privileges -Confirm:$false
} else {
Write-Host "Creating role '$RoleName'..." -ForegroundColor Cyan
$role = New-VIRole -Name $RoleName -Privilege $Privileges
}

# Assign to the user / group on the root folder
Write-Host "Assigning role '$RoleName' to '$UserAccount' on folder '$($entity.Name)'..." -ForegroundColor Cyan

New-VIPermission -Entity $entity -Principal $UserAccount -Role $role -Propagate:$true -Confirm:$false

Write-Host "`nCompleted Azure Arc Resource Bridge Role and Permission assignment." -ForegroundColor Green

# How to use:

# Connect to your vCenter: Connect-VIServer your-vcenter-server

# Edit the script: open it in a text editor (e.g., Visual Studio Code, PowerShell ISE), update: $UserAccount to the domain\username you want to assign rights to (Optionally) $RoleName if you'd like a custom name

# Save as azure-arc-resourcebridge-role.ps1

# Run: .\azure-arc-resourcebridge-role.ps1 This script creates or updates the AzureArc_ResourceBridgeRole role, adds all required permissions, and assigns it on the root folder to your service account, so the resource bridge will have the access it needs.