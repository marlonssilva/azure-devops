#variables
$Organizations = $env:ORG #Org Name
$AzureDevOpsPAT = $env:PAT #Pat Azure
$Tempo_Limit = (Get-Date).AddDays(-90).ToString("yyyy-MM-ddTHH:mm:ssZ") # No access timeout 90
$Tempo_Null = "0001-01-01T00:00:00Z" # Users without access
$LogFile = "$(Get-Location)\Usuarios_Devops$(Get-Date -Format 'yyyy-MM-dd').txt" #Log users
$Exit_LogFile | Out-File -FilePath $LogFile -Encoding utf8

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

#Api Acess Devops

function Invoke-AzDOApi {
    param ([string]$Method)

    $Uri =  "https://vsaex.dev.azure.com/" + $Organizations + "/_apis/userentitlements?top=1000&api-version=5.1-preview.2"
   
    $Headers = @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AzureDevOpsPAT"))}


    try {
        return Invoke-RestMethod -Uri $Uri -Headers $Headers -Method $Method -ContentType "application/json"
    } catch {
        Write-Log "Error calling API $Uri - $_"
        return $null
    }
}

#Function access api and remove users

function Remove-Users {

    param ([string]$Method, [string]$userId, [string]$email) 

    $Uri =  "https://vsaex.dev.azure.com/$Organizations/_apis/userentitlements/"+ $userId+ "?api-version=7.1"
   
    $Headers = @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AzureDevOpsPAT"))}

    try {
       
        $response = Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers 
        Write-Log "User successfully deleted $email"

    } 
    
    catch {
        
        Write-Log "Error deleting user : $email"
         
     }
}



function Get-InactiveUsers {

    param (
            [Parameter(Mandatory)]
            [array]$Organizations
            )
   
    
    $loopmensagem_null = $false
    $loopmensagem_90 = $false
    $condicao_null =$false
    $condicao_90 =$false

    #Acess APi
    $Users = Invoke-AzDOApi -Method "GET"

    
    foreach ($Org in $Organizations) {

      if (-not $Users -or -not $Users.items) {
            Write-Output "No users found or API call failed for $Org."   
          
        }
 
       foreach ($User in $Users.items) {
            #Variaveis
            $email = $User.user.mailAddress
            $lastAccess = $User.lastAccessedDate
            $userId = $User.id
            $nome = $User.user.displayName

                                                     
         if ($lastAccess -le $Tempo_Null) {

            if (-not $loopmensagem_null) {
                    $loopmensagem_null = $true
                    Write-Log "Users without access record"
                }
                    Write-Log "$nome  $email  $lastAccess $userId"                   
                    Remove-Users -userId $userId $email -email $email -info $info -Method "DELETE" 
                    $condicao_null = $true

        }
          
        if ($lastAccess -le $Tempo_Limit -and $lastAccess -gt $Tempo_Null) {
                                    
            if(-not $loopmensagem_90){
                    $loopmensagem_90 = $true
                    Write-Log "Users Registered Access for more than 90 days"
                }

                    Write-Log "$nome  $email  $lastAccess $userId"
                    Remove-Users -userId $userId -email $email -info $info -Method "DELETE" 
                    $condicao_90 = $true           
            }
                  
                               
}
  
    }


    if (-not $condicao_null) {
        Write-Log "No Users Found Without Access Records"
    }

    if (-not $condicao_90) {
        Write-Log "No Users Found Without Access for More Than 90 Days"
    }


}

# Call function 
Get-InactiveUsers -Organizations $Organizations 

