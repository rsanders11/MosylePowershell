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
    GetUsers(): Returns all users.  If synced with AD, google, Azure this may return many pages. 
    Todo:
    * User lists
    * Serial Search

    Possible Issues:
    May run into problems when 51 devices are added as there may be paging, not sure how the API will react to this. 
        -Paging has been added.  May need to watch this to be sure it is working as expected

    Type may not be loaded.  May need to run command below to add System.Web or it can be added the $PROFILE
    Add-Type -AssemblyName System.Web

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
        Write-Host $hash

        $this.headers = @{
            "Content-Type"="application/x-www-form-encoded";
            "accesstoken"=$token;
            "Authorization"="Basic $hash"
        }
    }

    [object]GetDevices(){
        if($null -ne $this.deviceList){
            return $this.deviceList
        }

        $buildResult = $this.BuildQuery("ios")
        <#
        $query = $buildResult.queryString
        #$query.add('options[specific_columns]', "device_name,asset_tag,serial_number")
        $url = $buildResult.url
        #>
        $response = $this.ExecuteAndHandlePaging($buildResult)
        $this.deviceList = $response
        return $response
    }

    [Object]GetDevices($employeeCode){
        if($null -eq $this.deviceList){
            $this.deviceList = $this.GetDevices()
        }

        return $this.deviceList | ? asset_tag -eq $employeeCode
    }

    [Object]GetUsers(){
        #response will come back with a users,rows,page, and page_size property 

        
        $buildResult = $this.BuildQuery("list_users")
        <#
        $response = $this.ExecuteWebRequest($buildresult.url, $buildresult.queryString)
        #>
        $response = $this.ExecuteAndHandlePaging($buildResult)
        return $response
    }

    [System.Object]BuildQuery($type){
        #Builds the basic query for specificed OS
        $queryString = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        $url = $this.uri
        $jsonObject = $null
        switch ($type) {
            "ios" { 
                $queryString.Add('operation', 'list')
                $queryString.add('options[os]', 'ios')
                $url = "$($url)/devices"
                $jsonObject = "devices"
             }
             "list_users" {
                $queryString.Add('operation', 'list_users')
                $url = "$($url)/users"
                $jsonObject = "users"
             }
             "update_user" {
                $queryString.Add('operation', 'update_user')
                $url = "$($url)/users"
                $jsonObject = "users"
             }
            Default {}
        }
        return [PSCustomObject]@{
            queryString = $queryString
            url = $url
            jsonObject = $jsonObject
        }
    }


    [Object]ExecuteWebRequest($url, $query){
        Write-Host $url.ToString()
        Write-Host $query
        $response = Invoke-WebRequest -Uri $url -Headers $this.headers -body $query.ToString() -Method Post -ContentType "application/x-www-form-urlencoded"
        $response = ConvertFrom-Json -InputObject $response
        return $response.response
    }


    SetToken($token){
        $this.token = $token
    }

    [Object]ExecuteAndHandlePaging($buildResult){
        #Push all pages together into one large object.  May not work out well for large datasets but will work for our current and near future device and user count
    
        <#
            Expected input: 
                * JSON object returned from API request.  Rows, page, and page_size should be exposed
                * Build Result.  An object containing the query that is editable and the url for the request to be made
            
            Requirements:
                *Access to ExecuteWebRequest method
    
            Process:
                * Pull new data for all available pages, add to $returnobject
        #>
        $response = $this.ExecuteWebRequest($buildresult.url, $buildresult.queryString)
        $returnObj = $response."$($buildResult.jsonObject)"
        
        $rows = $response.rows
        $pagesize = $response.page_size
        if($rows -lt $pagesize){
            #no need to handle paging.  Less rows than in a page. 
            return $returnObj
        }
    
        [int]$totalPages = [Math]::Ceiling($rows / $pagesize)

        for($i = 2; $i -le $totalPages; $i++){
            Write-Host "Page: $($i) / $($totalPages)"
            $buildresult.queryString.Add("options[page]", $i);
            $response = $this.ExecuteWebRequest($buildresult.url, $buildresult.queryString)

            $returnObj += $response."$($buildresult.jsonObject)"
        }
    
        return $returnObj
    }
}


