<#
    .Iterates through all mailboxes in an existing Exchange Online tenant, adding a new alias to all mailboxes as defined in $NewAliasSuffix
    .Author: github.com/chloebergen
#>
function Add-NewAlias {
    param(
        [Parameter(Mandatory=$true)]
        [string]$NewAliasSuffix
    )

    # Loop through each mailbox, extract the username from the existing primary SMTP address, then combine the username with the new domain suffix. 
    $Mailboxes = Get-Mailbox -ResultSize Unlimited
    foreach ($Mailbox in $Mailboxes) {
        $PrimarySMTP = $Mailbox.PrimarySmtpAddress.ToString()
        $Username = $PrimarySMTP.Split("@")[0]
        $NewAlias = "$Username@$NewAliasSuffix"

        # Get existing email addresses and check if the alias already exists; if it doesn't - add the new aliases 
        $EmailAddresses = $Mailbox.EmailAddresses
        if ($EmailAddresses -notcontains "smtp:$NewAlias") {
            $EmailAddresses += "smtp:$NewAlias"
            Set-Mailbox -Identity $Mailbox.Alias -EmailAddresses $EmailAddresses
            Write-Host "Added alias $NewAlias to $PrimarySMTP" -ForegroundColor Green
        } else {
            Write-Host "Alias $NewAlias already exists for $PrimarySMTP" -ForegroundColor Yellow
        }
    }

    # Disconnect from Exchange Online
    Disconnect-ExchangeOnline -Confirm:$false
}
