<# 
    .This tool is used to migrate a tenants user, group, and mail objects from an old domain suffix to a new one
    .Migrates Microsoft Graph users UserPrincipalNames 
        .Graph users will be migrated via group, typically you'll stage batches of 100-200+ users in a 365 group (or go by location if the client has location-based groups).
    .Migrates Exchange Online mailboxes, distribution groups, dynamic distribution groups, unified groups
        .Exchange Online mailboxes will have their primary SMTP address updated to the new suffix, and the old primary SMTP will be added as an alias.
    .USAGE: Update-ExchangeOnlineObjects -oldSuffix "olddomain.com" -newSuffix "newdomain.com" -MigrateMailboxes -MigrateUnifiedGroups -MigrateDistributionGroups -MigrateDynamicDistributionGroups
    .USAGE: Update-CloudUsers -oldSuffix "olddomain.com" -newSuffix "newdomain.com" -groupId "00000000-0000-0000-0000-000000000000" -MigrateCloudUsers
#>

Import-Module Microsoft.Graph.Users 
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.SignIns
Import-Module Microsoft.Graph.Beta.Identity.SignIns
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All","AuditLog.Read.All"

function Update-ExchangeOnlineObjects {
    param(
        [Parameter(Mandatory=$true)]
        [string]$oldSuffix,
        [Parameter(Mandatory=$true)]
        [string]$newSuffix,
        [Switch]$MigrateDistributionGroups,
        [Switch]$MigrateDynamicDistributionGroups,
        [Switch]$MigrateUnifiedGroups,
        [Switch]$MigrateMailboxes
    )

# Banner
Write-Host "EMAIL DOMAIN Migration: $oldSuffix → $newSuffix" -ForegroundColor Cyan
Write-Host "Starting migration process..." -ForegroundColor Magenta

### Migrate Distribution Groups
if ($MigrateDistributionGroups) {
    $updatedDistributionGroups = @() # tracking stats
    ## List all DGs in tenant
    $distributionGroupList = Get-DistributionGroup -ResultSize Unlimited

    ## Iterate through DG list and change Primary SMTP address from old suffix to new suffix
    foreach ($group in $distributionGroupList) {
        if ($group.PrimarySmtpAddress -like "*$oldSuffix"){
            try {
                $newPrimarySmtpAddress = $group.PrimarySmtpAddress -replace "$oldsuffix","$newSuffix"
                Set-DistributionGroup -Identity $group.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress 
                # Add to our array of successes
                $updatedDistributionGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Success"
                    TimeUpdated = Get-Date
                }
                Write-Host "Updated Distribution Group suffix for $($group.DisplayName) to $newPrimarySmtpAddress" -ForegroundColor Green
            } catch {
                Write-Error "$_. | on $($group.DisplayName)." -ForegroundColor Red
                # Add to our array of failures
                $updatedDistributionGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Failed: $_"
                    TimeUpdated = Get-Date
                }
            }
        }
    }

    # Success & failure count
    $successCount = ($updatedDistributionGroups | Where-Object { $_.Status -eq "Success" }).Count
    $failCount = ($updatedDistributionGroups | Where-Object { $_.Status -ne "Success" }).Count
    $totalCount = $successCount + $failCount

    Write-Host "DISTRIBUTION GROUP MIGRATION REPORT" -ForegroundColor Cyan
    Write-Host "Total accounts processed: $totalCount" -ForegroundColor White
    Write-Host "Successful migrations: $successCount" -ForegroundColor Green
    Write-Host "Failed migrations: $failCount" -ForegroundColor Red

    # Write results to window
    $updatedDistributionGroups | Format-Table -AutoSize

    # Export results to a CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = ".\distributiongroup_migration_results_$timestamp.csv"
    $updatedDistributionGroups | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results saved to $csvPath" -ForegroundColor Green
}

### Migrate Dynamic Distribution Groups
if ($MigrateDynamicDistributionGroups) {
    $updatedDynamicDistributionGroups = @() # tracking stats
    ## List all DGs in tenant
    $dynamicDistributionGroupList = Get-DynamicDistributionGroup -ResultSize Unlimited

    ## Iterate through DDG list and change Primary SMTP address from old suffix to new suffix
    foreach ($dynamicDistributionGroup in $dynamicDistributionGroupList) {
        if ($dynamicDistributionGroup.PrimarySmtpAddress -like "*$oldSuffix"){
            try {
                $newPrimarySmtpAddress = $dynamicDistributionGroup.PrimarySmtpAddress -replace "$oldsuffix","$newSuffix"
                Set-DynamicDistributionGroup -Identity $dynamicDistributionGroup.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress
                
                # Add to our array of successes
                $updatedDynamicDistributionGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Success"
                    TimeUpdated = Get-Date
                }                
                
                Write-Host "Updated Distribution Group suffix for $($dynamicDistributionGroup.DisplayName) to $newPrimarySmtpAddress" -ForegroundColor Green
            } catch {
                Write-Error "$_. | on $($dynamicDistributionGroup.DisplayName)." -ForegroundColor Red

                # Add to our array of failures
                $updatedDynamicDistributionGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Failed: $_"
                    TimeUpdated = Get-Date
                }
            }
        }
    }

    # Success & failure count
    $successCount = ($updatedDynamicDistributionGroups | Where-Object { $_.Status -eq "Success" }).Count
    $failCount = ($updatedDynamicDistributionGroups | Where-Object { $_.Status -ne "Success" }).Count
    $totalCount = $successCount + $failCount

    Write-Host "DYNAMIC DISTRIBUTION GROUP MIGRATION REPORT" -ForegroundColor Cyan
    Write-Host "Total accounts processed: $totalCount" -ForegroundColor White
    Write-Host "Successful migrations: $successCount" -ForegroundColor Green
    Write-Host "Failed migrations: $failCount" -ForegroundColor Red

    # Write results to window
    $updatedDynamicDistributionGroups | Format-Table -AutoSize

    # Export results to a CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = ".\dynamicdistributiongroup_migration_results_$timestamp.csv"
    $updatedDynamicDistributionGroups | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results saved to $csvPath" -ForegroundColor Green
}

### Migrate Unified Groups
if ($MigrateUnifiedGroups) {
    $updatedUnifiedGroups = @() # tracking stats
    ## List all Unified Groups in tenant
    $unifiedGroupList = Get-UnifiedGroup -ResultSize Unlimited

    ## Iterate through unified groups list and change Primary SMTP address from old suffix to new suffix
    foreach ($unifiedGroup in $unifiedGroupList) {
        if ($unifiedGroup.PrimarySmtpAddress -like "*$oldSuffix"){
            try {
                $newPrimarySmtpAddress = $unifiedGroup.PrimarySmtpAddress -replace "$oldsuffix","$newSuffix"
                Set-UnifiedGroup -Identity $unifiedGroup.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress

                # Add to our array of successes
                $updatedUnifiedGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Success"
                    TimeUpdated = Get-Date
                }

                Write-Host "Updated Microsoft 365 Group suffix for $($unifiedGroup.DisplayName) to $newPrimarySmtpAddress" -ForegroundColor Green
            } catch {
                Write-Error "$_. | on $($unifiedGroup.DisplayName)." -ForegroundColor Red
                $updatedUnifiedGroups += [PSCustomObject]@{
                    DisplayName = $cloudUser.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Failed: $_"
                    TimeUpdated = Get-Date
                }
            }
        }
    }
    # Success & failure count
    $successCount = ($updatedUnifiedGroups | Where-Object { $_.Status -eq "Success" }).Count
    $failCount = ($updatedUnifiedGroups | Where-Object { $_.Status -ne "Success" }).Count
    $totalCount = $successCount + $failCount

    Write-Host "UNIFIED GROUP MIGRATION REPORT" -ForegroundColor Cyan
    Write-Host "Total accounts processed: $totalCount" -ForegroundColor White
    Write-Host "Successful migrations: $successCount" -ForegroundColor Green
    Write-Host "Failed migrations: $failCount" -ForegroundColor Red

    # Write results to window
    $updatedUnifiedGroups | Format-Table -AutoSize

    # Export results to a CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = ".\unifiedgroup_migration_results_$timestamp.csv"
    $updatedUnifiedGroups | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results saved to $csvPath" -ForegroundColor Green
}



### Migrate Mailboxes
if ($MigrateMailboxes) {
    $mailboxList = Get-ExoMailbox -ResultSize Unlimited

    $updatedUsers = @() # tracks completion

    $mailboxesWithOldEmail = @() # for troubleshooting if needed

    foreach ($user in $mailboxList) {
        # New array containing user emails
        $emailArray = @($user.EmailAddresses)
        
        # Picks out the primary SMTP & username 
        $primaryEmail = $emailArray | Where-Object { $_ -cmatch "^SMTP:.*@$oldSuffix$" }
        $username = ($primaryEmail -replace "^SMTP:|@$oldSuffix$", "")
        # Check for old domain suffix
        if ($primaryEmail) {
            Write-Host "Found old email for: $($user.DisplayName)" -ForegroundColor Cyan
            $mailboxesWithOldEmail += $user
            # Picks out the secondary SMTP
            $secondaryEmail = $emailArray | Where-Object { $_ -cmatch "^smtp:$username@$newSuffix$" }

            # Replace old suffix with new suffix
            $newPrimaryEmail = $primaryEmail -replace "@$oldSuffix", "@$newSuffix"
            
            # Remove the old primary and secondary
            $updatedEmailAddresses = $emailArray | Where-Object { $_ -ne $primaryEmail -and $_ -ne $secondaryEmail }

            # Add the new primary email
            $updatedEmailAddresses += $newPrimaryEmail
            
            # Demote the old address to secondary
            $oldSecondaryEmail = $primaryEmail -replace "SMTP:", "smtp:"
            $updatedEmailAddresses += $oldSecondaryEmail
            
            Write-Host "Updating $primaryEmail → $newPrimaryEmail" -ForegroundColor Magenta
            
            # Actually updating the user 
            try {
                Set-Mailbox -Identity $user.Identity -EmailAddresses $updatedEmailAddresses -ErrorAction Stop
                
                # Add to our collection of wins
                $updatedUsers += [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Success"
                    TimeUpdated = Get-Date
                }
                
                Write-Host "  Mailbox migration successful!" -ForegroundColor Green
            } catch {
                Write-Host "  Error: $_" -ForegroundColor Red
                
                # Track the fails too
                $updatedUsers += [PSCustomObject]@{
                    DisplayName = $user.DisplayName
                    OldPrimary = $primaryEmail
                    NewPrimary = $newPrimaryEmail
                    Status = "Failed: $_"
                    TimeUpdated = Get-Date
                }
            }
        }
    }

    # Success & failure count
    $successCount = ($updatedUsers | Where-Object { $_.Status -eq "Success" }).Count
    $failCount = ($updatedUsers | Where-Object { $_.Status -ne "Success" }).Count
    $totalCount = $successCount + $failCount

    Write-Host "MIGRATION REPORT" -ForegroundColor Cyan
    Write-Host "Total accounts processed: $totalCount" -ForegroundColor White
    Write-Host "Successful migrations: $successCount" -ForegroundColor Green
    Write-Host "Failed migrations: $failCount" -ForegroundColor Red

    # Write results to window
    $updatedUsers | Format-Table -AutoSize

    # Export results to a CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = ".\domain_migration_results_$timestamp.csv"
    $updatedUsers | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results saved to $csvPath" -ForegroundColor Green
    }
}

function Update-CloudUsers {
    param(
        [Parameter(Mandatory=$true)]
        [string]$oldSuffix,
        [Parameter(Mandatory=$true)]
        [string]$newSuffix,
        [Parameter(Mandatory=$true)]
        [string]$groupId,
        [Switch]$MigrateUsers
    )
    if ($MigrateUsers) {
        ## Pull all members of specified Graph group (i.e. migrate ALL users from "Phase 1 Migration" group to the new UPN suffix)
        $groupMembers = Get-MgGroupMember -GroupId $groupId
        $cloudArray = @()
        $updatedCloudUsers = @() # tracking stats
            foreach ($member in $groupMembers) {
                $cloudArray += Get-MgUser -UserId $member.Id | Select-Object DisplayName, Id, UserPrincipalName, Mail
            }

        ## Change UPN suffix of all users from previous group
        $cloudUserList = $cloudArray
        foreach ($cloudUser in $cloudUserList) {
            $existingCloudUser = Get-MgUser -UserId $cloudUser.Id
            if ($existingCloudUser.UserPrincipalName -like "*$oldSuffix"){
                try {
                    $newUPN = $existingCloudUser.UserPrincipalName -replace "$oldsuffix","$newSuffix"
                    Update-MgUser -UserId $existingCloudUser.Id -UserPrincipalName $newUPN

                     # Add to our array of successes
                        $updatedCloudUsers += [PSCustomObject]@{
                        DisplayName = $cloudUser.DisplayName
                        OldPrimary = $primaryEmail
                        NewPrimary = $newPrimaryEmail
                        Status = "Success"
                        TimeUpdated = Get-Date
                    }

                    Write-Host "Updated UPN suffix for $($existingCloudUser.DisplayName) to $newUPN" -ForegroundColor Green
                } catch {
                    Write-Host "  Error: $_" -ForegroundColor Red

                    # Add to our array of failures
                        $updatedCloudUsers += [PSCustomObject]@{
                        DisplayName = $cloudUser.DisplayName
                        OldPrimary = $primaryEmail
                        NewPrimary = $newPrimaryEmail
                        Status = "Failed: $_"
                        TimeUpdated = Get-Date
                    }
                }
            }
        }
    
    # Success & failure count
    $successCount = ($updatedCloudUsers | Where-Object { $_.Status -eq "Success" }).Count
    $failCount = ($updatedCloudUsers | Where-Object { $_.Status -ne "Success" }).Count
    $totalCount = $successCount + $failCount

    Write-Host "CLOUD USER MIGRATION REPORT" -ForegroundColor Cyan
    Write-Host "Total accounts processed: $totalCount" -ForegroundColor White
    Write-Host "Successful migrations: $successCount" -ForegroundColor Green
    Write-Host "Failed migrations: $failCount" -ForegroundColor Red

    # Write results to window
    $updatedCloudUsers | Format-Table -AutoSize

    # Export results to a CSV
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $csvPath = ".\clouduser_migration_results_$timestamp.csv"
    $updatedCloudUsers | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results saved to $csvPath" -ForegroundColor Green
    
    }
}