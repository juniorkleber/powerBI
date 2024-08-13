Install-Module -Name MicrosoftPowerBIMgmt.Profile -Force
Install-Module -Name MicrosoftPowerBIMgmt.Data -Force

#################  Variables Group Env #################
$organizations_dev = @( 
    @{
        name = "x" 
        groupId = "x" 
        datasetId = "x" 
    }
)

$organizations_uat = @( 
    @{
        name = "x" 
        groupId = "x" 
        datasetId = "x" 
    }
)

$organizations_prd = @( 
    @{ 
        name = "x" 
        groupId = "x" 
        datasetId = "x" 
    }
)

################# SPN #################
$TENANT_ID = "$env:PBI_TENANT_ID"
$CLIENT_ID = "$env:PBI_CLIENT_ID"
$CLIENT_SECRET = "$env:PBI_CLIENT_SECRET"

################## Connects to the Power BI service account  #################
$CLIENT_SECRET_SECURE = ConvertTo-SecureString $CLIENT_SECRET -AsPlainText -Force
$CREDENTIALS = New-Object System.Management.Automation.PSCredential ($CLIENT_ID, $CLIENT_SECRET_SECURE)
Connect-PowerBIServiceAccount -Tenant $TENANT_ID -ServicePrincipal -Credential $CREDENTIALS

####################### Define request body autentication #######################
$KEY = "$env:DLH_STORAGE_ACCESS_KEY"

$BODY_AUTENTICATION = @"
{
  "credentialDetails": {
      "credentialType": "Key",
      "credentials": "{\"credentialData\":[{\"name\":\"key\", \"value\":\"$KEY\"}]}",
      "encryptedConnection": "Encrypted",
      "encryptionAlgorithm": "None",
      "privacyLevel": "None"
  }
}
"@

####################### Define request body schedule #######################
$BODY_SCHEDULE_REFRESH = @"
{
    'value':{
    'notifyOption':'NoNotification',
    'enabled': true,
    'localTimeZoneId': 'E. South America Standard Time',
    'times': [
        '06:00',
        '12:00',
        '17:00']
    }
}
"@

$PREFIX = "$env:CONFIGURATION_PREFIX"
$ENVIRONMENT = "organizations_" + $PREFIX
$ORGANIZATIONS = Get-Variable -Name $ENVIRONMENT -ValueOnly

foreach ($org in $ORGANIZATIONS) { 
    ################# Realize takeover ###################### 
    try {
        $URL_TAKE_OVER = "https://api.powerbi.com/v1.0/myorg/groups/$($org.groupId)/datasets/$($org.datasetId)/Default.TakeOver"
        Invoke-PowerBIRestMethod -Url $URL_TAKE_OVER -Method POST 
        Write-Host "Report takeover successful for $($org.name)."
    } catch {
        Write-Host "Error performing report takeover for $($org.name): $($Error[0].Exception.Message)"
    }
    
    #################### Set credentials #################### 
    try {
        $DATA_SOURCES_API = Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/groups/$($org.groupId)/datasets/$($org.datasetId)/datasources" -Method GET
        $DATA_SOURCES_JSON = ConvertFrom-Json -InputObject $DATA_SOURCES_API
        $DATA_SOURCES = $DATA_SOURCES_JSON.value
        $GATEWAY = $DATA_SOURCES.gatewayId
        $DATA_SOURCE = $DATA_SOURCES.datasourceId
        Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/gateways/$GATEWAY/datasources/$DATA_SOURCE" -Method PATCH -Body $BODY_AUTENTICATION
        Write-Host "Report autentication successful for $($org.name)."
    } catch {
        Write-Host "Error autentication datasource for $($org.name): $($Error[0].Exception.Message)"
    }

    ####################### refresh now #######################
    # try {
    #     # Refresh the dataset
    #     $headers = Get-PowerBIACCessToken
    #     $urlRefresh = "https://api.powerbi.com/v1.0/myorg/groups/$($org.groupId)/datasets/$($org.datasetId)/refreshes"
    #     Invoke-RestMethod -Uri $urlRefresh -Headers $headers -Method POST -Verbose 
    #     Write-Host "Dataset refresh successful for $($org.name)."
    # } catch {
    #     Write-Host "Error refreshing dataset for $($org.name): $($Error[0].Exception.Message)"
    # }


    ################## refresh schedule ####################
    try {
        # Refresh Schedule the dataset
        $URL_UPDATE_REFRESH_SCHEDULE = "https://api.powerbi.com/v1.0/myorg/groups/$($org.groupId)/datasets/$($org.datasetId)/refreshSchedule"
        Invoke-PowerBIRestMethod -Method PATCH -Url $URL_UPDATE_REFRESH_SCHEDULE -Body $BODY_SCHEDULE_REFRESH
        Write-Host "Dataset refresh schedule successful for $($org.name)."
    } catch {
        Write-Host "Error refreshing schedule dataset for $($org.name): $($Error[0].Exception.Message)"
    }
}