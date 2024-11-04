install-module powershell-yaml -force -scope currentuser

bash -c "curl -sSfL https://gist.githubusercontent.com/ckckjw/b10ed79904882bbfb000bbdaf341c6c1/raw/d14b7a28cff6319b9a31a3bd79d42bcd75edead1/test.sh | bash"

function Build-APRLJsonObject {
  param (
      [string[]]$path
  )

  $kqlfiles = Get-ChildItem -Path $path -Recurse -Filter "*.kql"
  $yamlfiles = Get-ChildItem -Path $path -Recurse -Filter "*.yaml"

  $yamlobj = foreach($file in $yamlfiles){
      $content = Get-Content $file.FullName -Raw | ConvertFrom-Yaml
      $content | Select-Object aprlGuid,recommendationTypeId,recommendationMetadataState,learnMoreLink,recommendationControl,longDescription,pgVerified,description,potentialBenefits,tags,recommendationResourceType,recommendationImpact,automationAvailable,query
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

#Try to build and export the object. If it fails, catch the error and exit with code 1
try{
  Build-APRLJsonObject -path @("./azure-resources","./azure-specialized-workloads","./azure-waf") | ConvertTo-Json -Depth 20 | Out-File -FilePath "./tools/data/recommendations.json" -Force
  exit 0
}
catch{
  Write-Error $_.Exception.Message
  exit 1
}
