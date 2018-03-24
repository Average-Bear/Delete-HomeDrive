<#
.SYNOPSIS
    If user account no longer exists in Active Directory, delete Home Drive for associated user. 

.DESCRIPTION
    If user account no longer exists in Active Directory, delete Home Drive for associated user. 

.DESCRIPTION
    Script assists SysAdmins with the deletion of End-User home drives and to mitigate the Human Error factor; providing the checks and balances to maintain a clean enviroment.

.NOTES
    Author: JBear 11/2/2016
    Edited: JBear 3/24/2018
#>

[Cmdletbinding(SupportsShouldProcess)]
param(

    [Parameter(DontShow)]
    [String[]]$Servers = @(
    
        '\\ACMESERVER\Repository\Test'#,
        #'\\ACMESERVER\Students$'
    ),
    
    [Parameter(DontShow)]
    $LogDate = (Get-Date -Format yyyyMMdd),
    
    [Parameter(DontShow)]
    $CsvPath = "\\ACMESHARE\IT\Reports\HomeDrive\Deleted-HomeDrives$($LogDate).csv",
    
    [Parameter(DontShow)]
    $TxtPath = "\\ACMESHARE\IT\Reports\HomeDrive\Log-RoboCopy$($LogDate).txt"
)

Try {

    Import-Module ActiveDirectory -ErrorAction Stop
    $SAMAccountNames = (Get-ADUser -Filter * -EA Stop | Sort SAMAccountName).SAMAccountName
}

Catch {

    Write-Host -ForegroundColor Yellow "`nUnable to reach Active Directory Module."
    Break
}

if($SAMAccountNames -eq $null) {

    Break
    Write-Host "You Broke it"
}

function DeleteDrive {
[Cmdletbinding(SupportsShouldProcess)]Param()

    New-Item -ItemType Directory -Path "$HomeDrive\RoboTemp" | Out-Null
    
    #Robocopy $RoboTemp directory to all child folders; Log file generated for all entries
    Robocopy "$HomeDrive\RoboTemp" $HomeDrive /MIR /LOG+:$txtPath

    #Delete user $HomeDrive
    Remove-Item $HomeDrive -Recurse -Confirm:$false
}

function DriveUtilization {

    ForEach($Server in $Servers) {

        #Retrieve object 'name' from each $Server path
        $Names = Get-ChildItem -LiteralPath $Server -Directory | Select-Object Name

        ForEach($Name in $Names) {

            $User = $SAMAccountNames -Contains $Name.name

            #If user object still exists, do nothing
            #If user DOES NOT exist, start deletion and reporting process
            If($User -eq $false) {

                $Script:HomeDrive = "$Server\$($Name.name)"
                $HomeDriveRecurse = Get-ChildItem $HomeDrive -Recurse -ErrorAction "SilentlyContinue"

                #Measure file lengths (bytes) for each $HomeDrive recursively to retrieve full directory size
                $MeasureDir = ($HomeDriveRecurse | Where {-NOT $_.PSIsContainer} | Measure-Object -Property Length -Sum)

                #Divide value of $MeasureDir (bytes) by MegaBytes (MB)
                $SumSize = $MeasureDir.Sum/1MB
                $Results = @(
                
                    if(Test-Path $HomeDrive) {
                    
                        $true 
                    }

                    else {
                    
                        $false
                    }
                )

                #Call delete function
                DeleteDrive

                [PSCustomObject] @{

                    HomeDrive = $HomeDrive
                    DriveUtilization = "{0:N2}" -f $SumSize + " MB"
                    Removed = "$Results"
                } 
            }
        }
    }
}

#Call main function
DriveUtilization | Select HomeDrive, DriveUtilization, Removed | Export-CSV -Path $CsvPath -NoTypeInformation
