# Get API key from here: https://ipgeolocation.io/
$API_KEY = "YOUR_IPGEOLOCATION_API_KEY"
$LOGFILE_NAME = "rdp_logs.txt"
$LOGFILE_PATH = "C:\Logs\$LOGFILE_NAME"

# This filter will be used to filter failed RDP events from Windows Event Viewer
$XMLFilter = @'
<QueryList> 
    <Query Id="0" Path="Security">
        <Select Path="Security">
            *[System[(EventID='4625')]]
        </Select>
    </Query>
</QueryList> 
'@

Function Write-SampleLog {
    "latitude:47.91542,longitude:-120.60306,destinationhost:samplehost,username:fakeuser,sourcehost:24.16.97.222,state:Washington,country:United States,label:US - 24.16.97.222,timestamp:2021-10-26 03:28:29" | Out-File $LOGFILE_PATH -Append -Encoding utf8
    "latitude:-22.90906,longitude:-47.06455,destinationhost:samplehost,username:lnwbaq,sourcehost:20.195.228.49,state:Sao Paulo,country:Brazil,label:Brazil - 20.195.228.49,timestamp:2021-10-26 05:46:20" | Out-File $LOGFILE_PATH -Append -Encoding utf8
    "latitude:52.37022,longitude:4.89517,destinationhost:samplehost,username:CSNYDER,sourcehost:89.248.165.74,state:North Holland,country:Netherlands,label:Netherlands - 89.248.165.74,timestamp:2021-10-26 06:12:56" | Out-File $LOGFILE_PATH -Append -Encoding utf8
}

If (!(Test-Path $LOGFILE_PATH)) {
    New-Item -ItemType File -Path $LOGFILE_PATH | Out-Null
    Write-SampleLog
}

While ($true) {
    Start-Sleep -Seconds 1
    $events = Get-WinEvent -FilterXml $XMLFilter -ErrorAction SilentlyContinue

    If ($Error) {
        #Write-Host "No failed logons found. Re-run the script when a login has failed."
    }

    Foreach ($event in $events) {
        If ($event.Properties[19].Value.Length -ge 5) {
            $timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $destinationHost = $event.MachineName
            $username = $event.Properties[5].Value
            $sourceHost = $event.Properties[11].Value
            $sourceIp = $event.Properties[19].Value

            $logContents = Get-Content -Path $LOGFILE_PATH

            If (-Not ($logContents -match $timestamp) -or ($logContents.Length -eq 0)) {
                Start-Sleep -Seconds 1

                $apiEndpoint = "https://api.ipgeolocation.io/ipgeo?apiKey=$API_KEY&ip=$sourceIp"
                $response = Invoke-WebRequest -UseBasicParsing -Uri $apiEndpoint

                $responseData = $response.Content | ConvertFrom-Json
                $latitude = $responseData.latitude
                $longitude = $responseData.longitude
                $stateProv = $responseData.state_prov
                $country = $responseData.country_name

                "latitude:$latitude,longitude:$longitude,destinationhost:$destinationHost,username:$username,sourcehost:$sourceIp,state:$stateProv,country:$country,label:$country - $sourceIp,timestamp:$timestamp" | Out-File $LOGFILE_PATH -Append -Encoding utf8

                Write-Host "Latitude:$latitude, Longitude:$longitude, Destination Host:$destinationHost, Username:$username, Source Host:$sourceIp, State:$stateProv, Country:$country, Label:$country - $sourceIp, Timestamp:$timestamp"
            }
        }
    }
}
