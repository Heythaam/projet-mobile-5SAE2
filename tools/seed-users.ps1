# Registers 20 sample players on the running backend (http://127.0.0.1:8080).
# Every account has the password  Passw0rd!  and the email  <name>@kickoff.test
# Usage:  .\tools\seed-users.ps1
$base = 'http://127.0.0.1:8080'
$names = 'sami','yassine','amine','karim','mehdi','nour','hatem','ali','rami','walid',
         'aymen','oussama','firas','skander','bilel','anis','hamza','zied','marwen','slim'
foreach ($n in $names) {
  $body = @{ username = "demo_$n"; email = "$n@kickoff.test"; password = 'Passw0rd!' } | ConvertTo-Json
  try {
    Invoke-RestMethod -Method Post -Uri "$base/auth/register" -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "created demo_$n"
  } catch {
    Write-Host "skipped demo_$n (already exists or error)"
  }
}
