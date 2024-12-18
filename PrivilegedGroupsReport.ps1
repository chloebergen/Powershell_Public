<#
    .Iterates through a list of privileged access groups in AD and prints out a report of their current members as a CSV.
#>

function Get-PrivilegedGroupsReport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$domain
    )
    ## Outfile & initial empty array
    $time = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $output = "PrivilegedGroupsReport_" + $domain + "_" + $time + ".csv"
    $results = @()

    ## Privileged group list ->
    $privilegedGroups = @(
        "Domain Admins",
        "Enterprise Admins",
        "Schema Admins",
        "Administrators",
        "DHCP Administrators",
        "WSUS Administrators",
        "Key Admins",
        "DnsAdmins",
        "Account Operators",
        "Backup Operators",
        "Server Operators",
        "Print Operators",
        "Cert Publishers",
        "Group Policy Creator Owners",
        "Hyper-V Administrators",
        "Cryptographic Operators",
        "Storage Replica Administrators"
    )

    # Iterate through each group defined earlier and add the results to our array
    foreach ($group in $privilegedGroups) {
        try {
            $members = Get-ADGroupMember -Identity $group -Server $domain -Recursive | Select-Object Name, SamAccountName, ObjectClass
            foreach ($member in $members) {
                $results += [PSCustomObject]@{
                    GroupName = $group
                    MemberName = $member.Name
                    SamAccountName = $member.SamAccountName
                    ObjectType = $member.ObjectClass
                }
            }
        } catch {
            Write-Warning "Failed to retrieve members for group '$group'. Error: $_"
        }
    }
    $results | Export-Csv -Path $output -NoTypeInformation -Encoding UTF8
}