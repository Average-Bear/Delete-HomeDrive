<#
.SYNOPSIS
Written by:
JBear 11/2/2016

Last Edit:
2/17/2017 JBear

Requires PowerShell Version 3 or higher.
Requires ActiveDirectory module.

If user account no longer exists in Active Directory, delete Home Drive for associated user. 

.DESCRIPTION
Purpose of script to assist SysAdmins with the deletion of End-User home Drives and to mitigate the Human Error factor. Providing
the checks and balances to maintain a clean enviroment.

This script is meant to be set as a scheduled task and run on all servers listed in the $ServerBase array.

Reports are output to \\Server\DIR\DeletedHomeDrives*.csv
#>

#Load Visual Basic .NET Framework
[Void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

Try {

    Import-Module ActiveDirectory -ErrorAction Stop
}

Catch {

    Write-Host -ForegroundColor Yellow "`nUnable to load Active Directory Module is required to run this script. Please, install RSAT and configure this server properly."
    Break
}

#Empty arrays for later use
$FileSize = @()
$TotalOutput = @()
$ErrorCheck = @()
$SAMAccountNames = @()

#Check for Active Directory
Try {

    $ADUsers = Get-ADUser -Filter * -EA Stop | Sort SAMAccountName | Select SAMAccountName
    $SAMAccountNames += $ADUsers.SAMAccountName
}

Catch {

    $SAMError = [Microsoft.VisualBasic.Interaction]::MsgBox("Unable to reach Active Directory. Please check your connection...", "OKOnly,SystemModal", "Error")
    Break;
}

if($SAMAccountNames -eq $NULL){

    Break;
    Write-Host "You Broke it"

}

#Array of Home Drive paths

$Servers = @(

    '\\Server\Home$',
    '\\Server\Students$'
)

#Out-File creation path
$prevFiles = Get-ChildItem '\\Server\DIR\DeletedHomeDrives*.csv'
$prevVersion = ($prevFiles.Name -replace '[^\d]' | foreach { [int]$_ } | sort | select -last 1) + 1
$OutPath = ('\\Server\DIR\DeletedHomeDrives{0:D3}.csv' -f $prevVersion)

#Robo Out-File creation path
$RoboPrevFiles = Get-ChildItem '\\Server\DIR\RobocopyLog*.txt'
$RoboPrevVersion = ($RoboPrevFiles.Name -replace '[^\d]' | foreach { [int]$_ } | sort | select -last 1) + 1
$RoboOutPath = ('\\Server\DIR\RobocopyLog{0:D3}.txt' -f $RoboPrevVersion)

#Get All Active Directory Users by SAMAccountName
ForEach($Server in $Servers) {

    #Retrieve object 'name' from each $Server path
    $Names = Get-ChildItem -LiteralPath $Server -Directory | Select-Object Name

    ForEach($Name in $Names) {

        $User = $SAMAccountNames -contains $Name.name

        #If user object still exists, do nothing
        #If user DOES NOT exist, start deletion and reporting process
        If($User -eq $false) {

            $HomeDrive = "$Server" + "\" + $Name.name
            $Robo = New-Item -ItemType Directory -Path "$HomeDrive\RoboTemp" | Out-Null
            $HomeDriveRecurse = Get-ChildItem $HomeDrive -Recurse -ErrorAction "SilentlyContinue"

            #Measure file lengths (bytes) for each $HomeDrive recursively to retrieve full directory size
            $MeasureDir = ($HomeDriveRecurse | Where {-NOT $_.PSIscontainer} | Measure-Object -Property Length -Sum)

            #Divide value of $MeasureDir (bytes) by MegaBytes (MB)
            $SumSize = $MeasureDir.Sum/1MB

            #Add $SumSize values to $FileSize array
            $FileSize += $SumSize
            $ErrorCheck += $HomeDrive

            $props = @{

                HomeDriveDeleted = $HomeDrive
                DriveUtilization = "{0:N2}" -f $SumSize + " MB"
            }

            New-Object PsObject -Property $props | Select HomeDriveDeleted, DriveUtilization | Export-CSV -Path $Outpath -Append -NoTypeInformation

            #Robocopy $RoboTemp directory to all child folders; Log file generated for all entries
            Robocopy "$HomeDrive\RoboTemp" $HomeDrive /MIR /LOG+:$RoboOutPath

            #Delete user $HomeDrive
            Remove-Item $HomeDrive -Recurse -Confirm:$false
        }#If
    }#ForEach($Name)

#Invoke math operations on $FileSize array
$TotalFileSize = $FileSize -Join '+'
$InvokeSum = Invoke-Expression $TotalFileSize

#Add $InvokeSum values to $TotalOutput array
$TotalOutput += $InvokeSum

#Invoke math operations on $FileSize array
$ServerSum = $TotalOutput -Join '+'
$InvokeFinal = Invoke-Expression $ServerSum

}