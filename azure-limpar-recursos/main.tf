terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

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
  timezone                = "America/Sao_Paulo"
}

resource "azurerm_automation_job_schedule" "link_schedule" {
  resource_group_name     = azurerm_resource_group.automation.name
  automation_account_name = azurerm_automation_account.automation.name
  schedule_name           = azurerm_automation_schedule.daily_3am.name
  runbook_name            = azurerm_automation_runbook.delete_rgs.name
}
