<#
    .SYNOPSIS
        Switches an Azure Function to a premium or consumption app service plan for running the most cost effective solution.

    .DESCRIPTION
        This runbook is designed to be used for (periodically) switching Azure Functions from a consumption app service plan to a premium app service plan or vice versa.
        So the most cost effective solution can be set for short bursts of (planned) high demanding (but cost aware) function execution loads.

        PREREQUISITE
        The modules "Az.Accounts", "Az.Resources", "Az.Functions" have to be imported into the automation account. They can be imported from
        the Module Gallery. See https://docs.microsoft.com/en-us/azure/automation/automation-runbook-gallery#import-a-module-from-the-module-gallery-with-the-azure-portal
        for more information.

    .PARAMETER UseAutomationConnection
        Optional. Indicates if automation connection (name) should be used. Default is True.

    .PARAMETER AutomationConnectionName
        Optional. The automation connection name. Default is 'AzureRunAsConnection'.

    .PARAMETER UseAutomationCredential
        Optional. Indicates if automation credential (name) should be used. Default is False.

    .PARAMETER AutomationCredentialName
        Optional. The automation credential name. Default is 'admin-user'.

    .PARAMETER ResourceGroupName
        Required. The resource group name. No default is set.

    .PARAMETER FunctionAppName
        Required. The Azure Function name. No default is set.

    .PARAMETER ConsumptionAppPlanName
        Required. The consumption function app service plan name. No default is set.

    .PARAMETER PremiumAppPlanName
        Required. The premium function app service plan name. No default is set.
    
    .PARAMETER PremiumAppPlanSku
        Optional. The premium function app service plan sku. Valid values are: 'EP1', 'EP2', 'EP3'. Default is 'EP1'.

    .PARAMETER PremiumAppPlanWorkType
        Optional. The premium function app service plan worktype. Valid values are: 'Windows', 'Linux'. Default is 'Windows'.

    .PARAMETER PremiumAppPlanMinimumWorkerCount
        Optional. The premium function app service plan minimum worker count. Default is 1.

    .PARAMETER PremiumAppPlanMaximumWorkerCount
        Optional. The premium function app service plan maximum worker count. This value should be bigger then 'PremiumAppPlanMinimumWorkerCount'. Default is 10.

    .PARAMETER UsePremiumPlan
        Optional. Indicates if the premium plan must be set for the specified function app. Default is True.

    .PARAMETER CleanupPremiumPlan
        Optional. Indicates if the premium function app service plan needs to be cleaned up when all conditions are met. Default is True.

    .EXAMPLE
        .\Set-FunctionAppAppServicePlan -ResourceGroupName 'myFunctionApp-rg-prd' -FunctionAppName 'myFunctionApp-prd' `
                -ConsumptionAppPlanName 'myFunctionApp-asp-cons-prd' -PremiumAppPlanName 'myFunctionApp-asp-prem-prd'

    .EXAMPLE
        .\Set-FunctionAppAppServicePlan -UseUseAutomationConnection $True -AutomationConnectionName 'AzureConnection-Prd' `
                -UseAutomationCredential $False -AutomationCredentialName "my-admin-user" `
                -ResourceGroupName 'myFunctionApp-rg-prd' `
                -FunctionAppName 'myFunctionApp-prd' -ConsumptionAppPlanName 'myFunctionApp-asp-cons-prd'  `
                -PremiumAppPlanName 'myFunctionApp-asp-prem-prd' -PremiumAppPlanSku 'EP2' `
                -PremiumAppPlanWorkType 'Windows' -PremiumAppPlanMinimumWorkerCount 2 `
                -PremiumAppPlanMaximumWorkerCount 8 -UsePremiumPlan $True `
                -CleanupPremiumPlan $False

    .EXAMPLE
        .\Set-FunctionAppAppServicePlan -ResourceGroupName 'myFunctionApp-rg-prd' -FunctionAppName 'myFunctionApp-prd' `
                -ConsumptionAppPlanName 'myFunctionApp-asp-cons-prd' -PremiumAppPlanName 'myFunctionApp-asp-prem-prd' `
                -PremiumAppPlanSku 'EP1' -PremiumAppPlanWorkType 'Windows' PremiumAppPlanMaximumWorkerCount 4

    .NOTES
        AUTHOR: Cuno Reijman
        LASTEDIT: Mar 30, 2021
        BLOG: https://blog.codespeedlane.com
        
#>

#Requires -Modules Az.Accounts, Az.Resources, Az.Functions

Param (
    [Parameter (Mandatory = $false)]
    [Boolean] $UseAutomationConnection = $true,

    [Parameter (Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String] $AutomationConnectionName = "AzureRunAsConnection",
   
    [Parameter (Mandatory = $false)]
    [Boolean] $UseAutomationCredential = $false,

    [Parameter (Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [String] $AutomationCredentialName = "admin-user",

    [Parameter (Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String] $ResourceGroupName,

    [Parameter (Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String] $FunctionAppName,

    [Parameter (Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String] $ConsumptionAppPlanName,

    [Parameter (Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String] $PremiumAppPlanName,

    [Parameter (Mandatory = $false)]
    [ValidateSet('EP1', 'EP2', 'EP3', ignorecase=$False)]
    [String] $PremiumAppPlanSku = "EP1",

    [Parameter (Mandatory = $false)]
    [ValidateSet('Windows', 'Linux', ignorecase=$False)]
    [String] $PremiumAppPlanWorkType = "Windows",

    [Parameter (Mandatory = $false)]
    [ValidateRange(1,10)]
    [Int] $PremiumAppPlanMinimumWorkerCount = 1,

    [Parameter (Mandatory = $false)]
    [ValidateRange(1,10)]
    [Int] $PremiumAppPlanMaximumWorkerCount = 10,

    [Parameter (Mandatory = $false)]
    [Boolean] $UsePremiumPlan = $true,

    [Parameter (Mandatory = $false)]
    [Boolean] $CleanupPremiumPlan = $true
)

## Login
if ($UseAutomationConnection -eq $true) {
    try {
        $loginBaseLogMessage = "Logging in to Azure using automation connection"
        Write-Output $loginBaseLogMessage
        
        $servicePrincipalConnection = Get-AutomationConnection -Name $AutomationConnectionName         
    
        Connect-AzAccount `
            -ServicePrincipal `
            -Tenant $servicePrincipalConnection.TenantID `
            -ApplicationId $servicePrincipalConnection.ApplicationID `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
    
        Write-Output "$loginBaseLogMessage [Success]"
    }
    catch {
        if (!$servicePrincipalConnection) {
            throw "Connection $AutomationConnectionName not found."
        } else {
            Write-Error -Message $_.Exception
    
            throw $_.Exception
        }
    }
}

if ($UseAutomationCredential -eq $true) {
    try {
        $loginBaseLogMessage = "Logging in to Azure using automation credential"
        Write-Output $loginBaseLogMessage

        $myCred = Get-AutomationPSCredential -Name $AutomationCredentialName
        $userName = $myCred.UserName
        $securePassword = $myCred.Password
        $myPsCred = New-Object System.Management.Automation.PSCredential ($userName,$securePassword)
        
        Connect-AzAccount -Credential $myPsCred | Out-Null

        Write-Output "$loginBaseLogMessage [Success]"
    }
    catch {
        if (!$servicePrincipalConnection) {
            throw "Credentials $AutomationCredentialName not found."
        } else {
            Write-Error -Message $_.Exception
    
            throw $_.Exception
        }
    }
}

## Check prerequisites
$checkPrerequisitesBaseLogMessage = "Checking requirements and resources"
Write-Output $checkPrerequisitesBaseLogMessage

if ($ConsumptionAppPlanName -eq $PremiumAppPlanName) {
    $errorMessage = "Consumption plan name and premium plan name must be different ('$ConsumptionAppPlanName' <> '$premiumPlanName')"
    Write-Error -Message $errorMessage

    throw $errorMessage
}

$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName
if ($null -eq $resourceGroup) {
    $errorMessage = "Cannot find resourcegroup '$ResourceGroupName', make sure it exists."
    Write-Error -Message $errorMessage

    throw $errorMessage
}

$functionApp = Get-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName
if ($null -eq $functionApp) {
    $errorMessage = "Cannot find function app '$FunctionAppName' in resourcegroup '$ResourceGroupName', make sure it exists."
    Write-Error $errorMessage

    throw $errorMessage
}

$newAppPlanName = $null

$functionAppPremiumPlan = Get-AzFunctionAppPlan -Name $PremiumAppPlanName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if ($UsePremiumPlan -eq $true) {
    Write-Output "-Use premium app plan '$PremiumAppPlanName'"

    if ($null -eq $functionAppPremiumPlan) {

        $baseCreatePremiumAppPlanLogMessage = "-Creating premium function app plan '$PremiumAppPlanName'"
        Write-Output $baseCreatePremiumAppPlanLogMessage

        $functionAppPremiumPlan = New-AzFunctionAppPlan -Name $PremiumAppPlanName `
                                    -ResourceGroupName $ResourceGroupName `
                                    -Location $resourceGroup.Location `
                                    -Sku $PremiumAppPlanSku `
                                    -WorkerType $PremiumAppPlanWorkType `
                                    -MinimumWorkerCount $PremiumAppPlanMinimumWorkerCount `
                                    -MaximumWorkerCount $PremiumAppPlanMaximumWorkerCount

        Write-Output "$baseCreatePremiumAppPlanLogMessage [Success]"
    }

    $newAppPlanName = $PremiumAppPlanName
} else {
    Write-Output "-Use consumption app plan '$ConsumptionAppPlanName'"

    $functionAppConsumptionPlan = Get-AzFunctionAppPlan -Name $ConsumptionAppPlanName -ResourceGroupName $ResourceGroupName
    if ($null -eq $functionAppConsumptionPlan) {
        throw "Cannot find consumption function app plan '$ConsumptionAppPlanName' in resourcegroup '$ResourceGroupName', make sure it exists."
    }

    $newAppPlanName = $ConsumptionAppPlanName
}

Write-Output "$checkPrerequisitesBaseLogMessage [Success]"

## Persist
$persistBaseLogMessage = "Updating function app '$FunctionAppName' with app service plan '$newAppPlanName'"
Write-Output $persistBaseLogMessage

if ($functionApp.AppServicePlan -ne $newAppPlanName) {
    Update-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName -PlanName $newAppPlanName | Out-Null

    Write-Output "$persistBaseLogMessage [Success]"
} else {
    Write-Output "$persistBaseLogMessage [Skipped] Already set"
}

## Cleanup
$cleanupBaseLogMessage = "Cleaning up resources"
Write-Output $cleanupBaseLogMessage

$functionAppPremiumPlan = Get-AzFunctionAppPlan -Name $PremiumAppPlanName -ResourceGroupName $ResourceGroupName
if ($UsePremiumPlan -eq $false -and
        $null -ne $functionAppPremiumPlan -and
        $CleanupPremiumPlan -eq $true -and
        $functionAppPremiumPlan.NumberOfSite -eq 0) {
    Remove-AzFunctionAppPlan -Name $PremiumAppPlanName -ResourceGroupName $ResourceGroupName -Force | Out-Null

    Write-Output "$cleanupBaseLogMessage [Success]"
} else {
    Write-Output "$cleanupBaseLogMessage [Skipped] Conditions not met"
}
