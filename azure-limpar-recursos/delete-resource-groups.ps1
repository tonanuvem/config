# RG que nao serao excluidos
$excluded = @("fiapvm", "rg-automation", "cloud-shell-storage-eastus")

$resourceGroups = Get-AzResourceGroup

foreach ($rg in $resourceGroups) {
    if ($rg.ResourceGroupName -ne $excluded) {
        Write-Output "Deleting resource group: $($rg.ResourceGroupName)"
        Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force
    } else {
        Write-Output "Skipping resource group: $($rg.ResourceGroupName)"
    }
}
