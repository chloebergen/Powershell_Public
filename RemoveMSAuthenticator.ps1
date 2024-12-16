<#
    .Iterates through a list of members of a specific group and removes Microsoft Authenticator from their user via Graph
    .Requires these permissions: UserAuthenticationMethod.ReadWrite.All, User.ReadWrite.All, AuditLog.Read.All
    .Example usage: Remove-MSAuthenticator -groupId 00000000-0000-0000-0000-000000000000
#>

## Modules
Import-Module Microsoft.Graph.Users 
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.SignIns

## Function 
function Remove-MSAuthenticator {
    param(
        [Parameter(Mandatory=$true)]
        [string]$groupId
    )

    try {
        Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All","User.ReadWrite.All","AuditLog.Read.All"
        $userList = Get-MgGroupMemberAsUser -GroupID $groupId | Select-Object DisplayName,UserPrincipalName,Mail,Id
        foreach ($user in $userList) {
            $userPrincipalName = $user.userPrincipalName   
            $methodExpanded = Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -userId $userPrincipalName
            $methodIds = $methodExpanded.Id
                if ($methodIds.count -gt 0) {
                    foreach ($authId in $methodIds) {
                        Write-Host "Removing $($authId) from $($userPrincipalName)" -ForegroundColor Green
                        Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -MicrosoftAuthenticatorAuthenticationMethodId $authId -userId $userPrincipalName
                    }
                } else {
                    Write-Host "User $($userPrincipalName) does not have Microsoft Authenticator configured." -ForegroundColor Yellow
                }
        }
    } 
    catch {
        Write-Error "An error occurred: $_"
    }
}