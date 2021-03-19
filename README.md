Switch an Azure Function App between a consumption and a premium app service plan
=========================================

# DESCRIPTION
This PowerShell Runbook (compatible with PowerShell Core) connects to Azure using an Automation Run As account and switches the specified Azure Function from a consumption app service plan to a premium app service plan or vice versa. You can attach a recurring schedule to this runbook to run it at a specific times. So the most cost effective solution can be set for short bursts of (planned) high demanding (but cost aware) function execution loads.

# PREREQUISITE
The modules "Az.Accounts", "Az.Resources", "Az.Functions" have to be imported into the automation account. They can be imported from
the Module Gallery. See https://docs.microsoft.com/en-us/azure/automation/automation-runbook-gallery#import-a-module-from-the-module-gallery-with-the-azure-portal
for more information.

This script wil not provide the consumption app service plan, when it's not available. Currently the used Az.Functions module does not support this (yet).
Create the consumption app service plan using this (https://github.com/equalizer999/switch-azure-function-between-consumption-and-premium-app-plan/blob/main/azuredeploy.json) template if necessary.

# AUTHOR
Cuno Reijman
https://blog.codespeedlane.com

# LAST EDIT
2021-19-03

# RELEASE NOTES
2021-19-03 First release
