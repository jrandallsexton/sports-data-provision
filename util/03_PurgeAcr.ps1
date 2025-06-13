$registryName = 'sportDeets'
$doNotDeleteTags = ''
$skipLastTags = 2

$repoArray = (az acr repository list --name $registryName --output json | ConvertFrom-Json)

foreach ($repo in $repoArray)
{
    $tagsArray = (az acr repository show-tags --name $registryName --repository $repo --orderby time_asc --output json | ConvertFrom-Json ) | Select-Object -SkipLast $skipLastTags

    foreach($tag in $tagsArray)
    {

        if ($donotdeletetags -contains $tag)
        {
            Write-Output ("This tag is not deleted $tag")
        }
        else
        {
            az acr repository delete --name $registryName --image $repo":"$tag --yes
        }
 
    }
}