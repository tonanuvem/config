$excluded = "rg-automation" # Nome do resource group onde o Automation Account está

$resourceGroups = Get-AzResourceGroup

foreach ($rg in $resourceGroups) {
    if ($rg.ResourceGroupName -ne $excluded) {
        Write-Output "Deleting resource group: $($rg.ResourceGroupName)"
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
    } else {
        Write-Output "Skipping resource group: $($rg.ResourceGroupName)"
    }
}
