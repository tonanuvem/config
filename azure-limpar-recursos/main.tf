provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "automation" {
  name     = "rg-automation"
  location = "East US"
}

resource "azurerm_automation_account" "automation" {
  name                = "automation-account"
  location            = azurerm_resource_group.automation.location
  resource_group_name = azurerm_resource_group.automation.name
  sku_name            = "Free"
}

resource "azurerm_automation_runbook" "delete_rgs" {
  name                    = "Delete-ResourceGroups"
  location                = azurerm_resource_group.automation.location
  resource_group_name     = azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.automation.name
  log_verbose             = true
  log_progress            = true
  description             = "Deletes all resource groups except the one hosting this automation"
  runbook_type            = "PowerShell"
  content                 = file("${path.module}/delete-resource-groups.ps1")
}

resource "azurerm_automation_schedule" "daily_3am" {
  name                    = "Daily-3AM"
  resource_group_name     = azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.automation.name
  frequency               = "Day"
  interval                = 1
  timezone                = "E. South America Standard Time"
  start_time              = "2024-01-01T03:00:00Z"
}

resource "azurerm_automation_job_schedule" "link_schedule" {
  resource_group_name     = azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.automation.name
  schedule_name           = azurerm_automation_schedule.daily_3am.name
  runbook_name            = azurerm_automation_runbook.delete_rgs.name
}
