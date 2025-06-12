<#
    .GET request for Meraki device data
#>

# API Setup
$secureApiKey = Import-Clixml -Path "C:\REDACTED\meraki_api.xml"
$apiKey = [System.Net.NetworkCredential]::new("", $secureApiKey).Password
$orgId = "REDACTED"
$networkId = "REDACTED"
$url_base = "https://api.meraki.com/api/v1/"
$url_endpoint = "networks/$networkId/devices"
$url = $url_base + $url_endpoint


# GET request for MT11 device data
$response = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/networks/$networkId/devices" -Headers $headers
$sensors = $response | Where-Object { $_.model -eq "MT11" }

# Pulls temp data for each sensor and organizes it into a custom object
$reportObjects = @()

foreach ($sensor in $sensors) {
    $serial = $sensor.serial
    $name = if ($sensor.name) { $sensor.name } else { $sensor.serial }

    # Pulls the latest sensor reading
    $sensorData = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/organizations/$orgId/sensor/readings/latest?serials[]=$serial" -Headers $headers
    $reading = $sensorData.readings[0]

    if ($reading) {
        $reportObjects += [PSCustomObject]@{
            Name      = $name
            Serial    = $serial
            TempC     = $reading.temperature.celsius
            TempF     = $reading.temperature.fahrenheit
            Timestamp = $reading.ts
        }
    } else {
        $reportObjects += [PSCustomObject]@{
            Name      = $name
            Serial    = $serial
            TempC     = "N/A"
            TempF     = "N/A"
            Timestamp = "No recent reading"
        }
    }
}

# Convert to HTML
function ConvertTo-HtmlTable {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Objects
    )
    
    $htmlTable = $Objects | ConvertTo-Html -Fragment -PreContent "<h3>Meraki Sensor API Report</h3>" -PostContent "<hr>" -Property Name, Serial, TempC, TempF, Timestamp

    # CSS
    $style = @"
<style>
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; font-family: Arial, sans-serif; font-size: 14px; }
    th { background-color: #0078D7; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@

    return $style + $htmlTable
}

# Usage
$bodyContent = ConvertTo-HtmlTable -Objects $reportObjects

<##
    .Email via Azure app registration
#>

# Config values
$tenantId     = "REDACTED"
$clientId     = "REDACTED"
$secureSecret = Import-Clixml -Path "C:\REDACTED\azure_app_powershell_smtp.xml"
$clientSecret = [System.Net.NetworkCredential]::new("", $secureSecret).Password
$fromAddress  = "REDACTED@REDACTED.REDACTED"
$toAddress    = "REDACTED@REDACTED.REDACTED"

# API access token
$body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$accessToken = $tokenResponse.access_token

# Email payload
$emailPayload = @{
    message = @{
        subject = "Meraki API Automation Test"
        body = @{
            contentType = "HTML"
            content     = "$bodyContent"
        }
        toRecipients = @(@{ emailAddress = @{ address = $toAddress } })
        from = @{ emailAddress = @{ address = $fromAddress } }
    }
    saveToSentItems = "false"
} | ConvertTo-Json -Depth 10

# Send email
Invoke-RestMethod -Method Post `
    -Uri "https://graph.microsoft.com/v1.0/users/$fromAddress/sendMail" `
    -Headers @{ Authorization = "Bearer $accessToken" } `
    -ContentType "application/json" `
    -Body $emailPayload


 