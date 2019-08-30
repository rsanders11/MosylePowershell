<#
    This class is used to interact with the Mosyle API.  
    Requirements: 
    * Mosyle Business API key
    * Mosyle Business User/Pass
    * Powershell v5+

    Notes: Username and password stored in xml file after first run.  Password stored as secure string.  

    Strongly suggested to initiate garbage collection when the API isn't used anymore as passwords will be stored in memory as base64 string until GC is completed.   
    **This still may not release all strings in memory**
    [System.GC]::Collect()

    USAGE: 
    Intialize MosyleApi: [MosyleApi]::new($MosyleToken)

    GetDevices(): Return all devices
    GetDevices($employeeCode): Return Devices where asset tags match employee code

#>


class MosyleApi {
    $token
    $headers
    $uri = "https://businessapi.mosyle.com/v1/"
    $deviceList = $null


    MosyleApi($token){
        #Initialize.  Gather credentials and create the headers variable.  
        $this.token = $token

        if(Test-Path "$PSScriptRoot\cred\MosyleCred.xml"){
            #Credential Exists, use
            $credential = Import-Clixml -Path "$PSScriptRoot\cred\MosyleCred.xml"
            $Cred = $credential
        }else{
            #Credential doesn't exist, prompt, store, then return credential.
            Write-Host "Please enter credentials to access Mosyle: "
            $credential = (Get-Credential)
            New-Item -Path "$PSScriptRoot\cred\MosyleCred.xml" -Force
            $credential | Export-Clixml -Path "$PSScriptRoot\cred\MosyleCred.xml" -Force
            $Cred = $credential
        }

        $username = $Cred.UserName
        $password = $Cred.GetNetworkCredential().Password
        $hash = "$($username):$($password)"
        $hash = [System.Text.Encoding]::UTF8.GetBytes($hash)
        $hash = [Convert]::ToBase64String($hash)

        $this.headers = @{
            "Content-Type"="application/x-www-form-encoded";
            "accesstoken"=$token;
            "Authorization"="Basic $hash"
        }
        Write-Host $hash
    }

    [object]GetDevices(){
        $query = $this.BuildQuery("ios")
        #$query.add('options[specific_columns]', "device_name,asset_tag,serial_number")
        $url = "$($this.uri)/devices"
        $response = $this.ExecuteWebRequest($url, $query)
        $this.deviceList = $response.devices
        return $response.devices
    }

    [Object]GetDevices($employeeCode){
        if($null -eq $this.deviceList){
            $this.deviceList = $this.GetDevices()
        }

        return $this.deviceList | ? asset_tag -eq $employeeCode
    }




    [System.Object]BuildQuery($os){
        #Builds the basic query for specificed OS
        if($os -eq "ios"){
            $queryString = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
            $queryString.Add('operation', 'list')
            $queryString.add('options[os]', 'ios')
        }else{
            $queryString = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        }
        return $queryString
    }


    [Object]ExecuteWebRequest($url, $query){
        Write-Host $query.ToString()
        $response = Invoke-WebRequest -Uri $url -Headers $this.headers -body $query.ToString() -Method Post -ContentType "application/x-www-form-urlencoded"
        $response = ConvertFrom-Json -InputObject $response
        return $response.response
    }


    SetToken($token){
        $this.token = $token
    }
}
