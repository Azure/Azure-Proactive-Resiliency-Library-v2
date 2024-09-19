import-module powershell-yaml -force -scope CurrentUser

function Build-APRLJsonObject {
  param (
      [string]$path
  )

  $kqlfiles = Get-ChildItem -Path $path -Recurse -Filter "*.kql"
  $yamlfiles = Get-ChildItem -Path $path -Recurse -Filter "*.yaml"

  $yamlobj = foreach($file in $yamlfiles){
      $content = Get-Content $file.FullName -Raw | ConvertFrom-Yaml
      $content | Select-Object publishedToAdvisor,aprlGuid,recommendationTypeId,recommendationMetadataState,learnMoreLink,recommendationControl,longDescription,pgVerified,description,potentialBenefits,publishedToLearn,tags,recommendationResourceType,recommendationImpact,automationAvailable,query
  }

  $kqlobj = foreach($file in $kqlfiles){
      $content = Get-Content $file.FullName -Raw
      [PSCustomObject]@{
          AprlGUID = $file.Name -replace ".kql",""
          Query = $content
      }
  }

  $aprlobj = foreach($obj in $yamlobj){
      $obj.query = $($kqlobj.Where{$_.AprlGUID -eq $obj.aprlGuid}).Query
      $obj
  }
  return $aprlobj
}

try{
  Build-APRLJsonObject -path "./azure-resources" | ConvertTo-Json -Depth 10 | Out-File -FilePath "./tools/data/recommendations.json" -Force
  exit 0
}
catch{
  Write-Error $_.Exception.Message
  exit 1
}
