# Define the IIS website url and the application pool name
$IISWebsiteURL = "<website_url>"
$IISAppPoolName = "<application_pool_name>"

function Send-SendGridEmail {
    param(
        [Parameter(Mandatory = $true)]
        [String] $destEmailAddress,
        [Parameter(Mandatory = $true)]
        [String] $subject,
        [Parameter(Mandatory = $false)]
        [string]$contentType = 'text/plain',
        [Parameter(Mandatory = $true)]
        [String] $contentBody
    )

    $apiKey = "<sendgrid-apikey>"
    $fromEmailAddress = "<from-email-address>"
    $fromName = "App Monitor Script"
  
    $headers = @{
        'Authorization' = 'Bearer ' + $apiKey
        'Content-Type'  = 'application/json'
    }
  
    $body = @{
        personalizations = @(
            @{
                to = @(
                    @{
                        email = $destEmailAddress
                    }
                )
            }
        )
        from             = @{
            email = $fromEmailAddress
            name = $fromName
        }
        subject          = $subject
        content          = @(
            @{
                type  = $contentType
                value = $contentBody
            }
        )
    }
  
    try {
        $bodyJson = $body | ConvertTo-Json -Depth 4
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error converting body to json ' + $ErrorMessage)
        Break
    }
  
    try {
       Invoke-RestMethod -Uri https://api.sendgrid.com/v3/mail/send -Method Post -Headers $headers -Body $bodyJson 
    }
    catch {
        $ErrorMessage = $_.Exception.message
        write-error ('Error with Invoke-RestMethod ' + $ErrorMessage)
        Break
    }
}

function Test-WebsiteAndAppPoolAvailability {
    param (
        [string]$Url,
        [string]$AppPoolName
    )

    try {
        # Check if the website is accessible
        $websiteResponse = Invoke-WebRequest -Uri $Url -Method Get -ErrorAction Stop
        # Check if the application pool is running
        $appPoolStatus = Get-WebAppPoolState -Name $AppPoolName -ErrorAction Stop
        # Return true if both website and application pool are accessible
        return ($websiteResponse.StatusCode -eq 200 -and $appPoolStatus.Value -eq "Started")
    } catch {
        return $false
    }
}

if (-not (Test-WebsiteAndAppPoolAvailability -Url $IISWebsiteURL -AppPoolName $IISAppPoolName)) {
    $htmlBody = @"
<table>
        <tr>
            <header>
                <h1 align="center">IIS website or application pool is not accessible</h1>
            </header>
        <tr>
            <td align="center">The IIS website ($IISWebsiteURL) or its application pool ($IISAppPoolName) is not accessible. Please check.</td>
        </tr>
</table>
"@
    $splat = @{
        destEmailAddress = '<destination_email_address>'
        subject          = 'Website/App Pool Alert: IIS website or application pool is not accessible'
        contentType      = 'text/html'
        contentBody      = $htmlBody
    }
    Send-SendGridEmail @splat
    Write-Output "Email sent"
} else {
    Write-Output "Website and application pool are accessible"
}
