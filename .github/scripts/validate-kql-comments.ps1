#Functions
Function Validate-KqlComments([array]$filearray) {
$kqlresults = @()
ForEach($file in $filearray){

  #Test if the kql isn't actually part of the APRL recommendations and skip it.
  if($file.name -like "*replace*"){Continue}

  #Create psobject scaffolding
  $kqlresult = [PSCustomObject]@{
    FileName = $file.FullName
    Result = ""
    Description = ""
    CommentString = ""
  }

  #Get the first two lines of the kql file
  $content = Get-Content $file.FullName -TotalCount 2

  #if($content[0] -like "//*under*" -or $content[0] -like "//*cannot*" -or $content[0] -like "//*under-*" -or $content[0] -eq "// under-development")
  if ($content[0] -match "^//.*(under|cannot)" -or $content -match "^//.*(under|cannot)"){
    $kqlresult.Result = "N/A"
    $kqlresult.Description = "There is no query associated with this recommendation."
    $kqlresult.CommentString = $content
  }
  elseif($content[0] -ne "// Azure Resource Graph Query"){
    $kqlresult.Result = "FAIL"
    $kqlresult.Description = "The first line of the KQL file is not a comment with 'Azure Resource Graph Query'. It should be a comment with 'Azure Resource Graph Query'."
    $kqlresult.CommentString = $content
  }
  elseif ($content[1] -notlike "// *"){
    $kqlresult.Result = "FAIL"
    $kqlresult.Description = "The second line of the KQL file is not a comment. It should be a comment with a description of the query."
    $kqlresult.CommentString = $content
  }
  else{
    $kqlresult.Result = "PASS"
    $kqlresult.Description = "The first two lines of the KQL file are comments."
  }
  $kqlresults += $kqlresult
  }

  return $kqlresults
}



$kqlfiles = Get-ChildItem -Path . -Filter *.kql -Recurse

$test = Validate-KqlComments($kqlfiles)

$test | Where {$_.Result -eq "FAIL"}
