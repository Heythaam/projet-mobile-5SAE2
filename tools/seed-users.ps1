# Registers 20 sample players on the running backend (http://127.0.0.1:8080).
# Every account has the password  Passw0rd!  and the email  <name>@kickoff.test
# Usage:  .\tools\seed-users.ps1
$base = 'http://127.0.0.1:8080'
Write-Host "Seeding $base ..."
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

# A stadium owner with 6 stadiums (they show up when creating a match).
$ownerBody = @{ username = 'demo_owner'; email = 'owner@kickoff.test'; password = 'Passw0rd!' } | ConvertTo-Json
try { Invoke-RestMethod -Method Post -Uri "$base/auth/register" -ContentType 'application/json' -Body $ownerBody | Out-Null } catch { }
try {
  $login = @{ email = 'owner@kickoff.test'; password = 'Passw0rd!' } | ConvertTo-Json
  $session = Invoke-RestMethod -Method Post -Uri "$base/auth/login" -ContentType 'application/json' -Body $login
  $headers = @{ Authorization = "Bearer $($session.token)" }
} catch {
  Write-Host "Could not log in the stadium owner: $($_.Exception.Message)"
  return
}
$stadiums = @(
  @{ name = 'Arena Lac';       address = 'Les Berges du Lac, Tunis';  sizes = '5v5','7v7';          price = 60 },
  @{ name = 'Carthage Five';   address = 'Carthage, Tunis';           sizes = '5v5','5v5';          price = 50 },
  @{ name = 'La Marsa Turf';   address = 'La Marsa, Tunis';           sizes = '7v7','11v11';        price = 80 },
  @{ name = 'Menzah Sports';   address = 'El Menzah 6, Tunis';        sizes = '5v5','5v5','7v7';    price = 45 },
  @{ name = 'Ariana Indoor';   address = 'Ariana ville';              sizes = '5v5','5v5';          price = 55 },
  @{ name = 'Ben Arous Arena'; address = 'Ben Arous';                 sizes = '7v7','11v11';        price = 70 }
)
foreach ($s in $stadiums) {
  $pitches = @()
  foreach ($size in $s.sizes) { $pitches += @{ size = $size; surface = 'turf' } }
  $body = @{
    name = $s.name; phone = '+216 20123456'; address = $s.address
    features = @('lights', 'parking', 'showers'); openDays = 127
    openMinute = 480; closeMinute = 1380; slotMinutes = 60
    pricePerHour = $s.price; eveningSurcharge = 20; pitches = $pitches
  } | ConvertTo-Json -Depth 5
  try {
    Invoke-RestMethod -Method Post -Uri "$base/owner/stadiums" -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
    Write-Host "stadium $($s.name)"
  } catch {
    Write-Host "stadium $($s.name) skipped: $($_.Exception.Message)"
  }
}
