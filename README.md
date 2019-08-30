# MosylePowershell
Mosyle Powershell API   

This class is used to interact with the Mosyle API.  
    Requirements: 
    - Mosyle Business API key
    - Mosyle Business User/Pass
    - Powershell v5+
    
    
    Notes: Username and password stored in xml file after first run.  Password stored as secure string.  
    Strongly suggested to initiate garbage collection when the API isn't used anymore as passwords will be stored in memory as base64 string until GC is completed.    
    
    
    **This still may not release all strings in memory**
    [System.GC]::Collect()   
    
    USAGE: 
    Intialize MosyleApi: [MosyleApi]::new($MosyleToken)
    GetDevices(): Return all devices
    GetDevices($employeeCode): Return Devices where asset tags match employee code   
    
    Todo:
    - User lists
    - Serial Search
       
    Possible Issues:
    May run into problems when 51 devices are added as there may be paging, not sure how the API will react to this. 
    Type may not be loaded.  
       
    May need to run command below to add System.Web or it can be added the $PROFILE
    Add-Type -AssemblyName System.Web
