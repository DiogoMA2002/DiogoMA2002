$ErrorActionPreference = 'Stop'

$login = 'DiogoMA2002'
$headers = @{ 'User-Agent' = 'DiogoMA2002-profile-assets' }
if ($env:GITHUB_TOKEN) {
    $headers.Authorization = "Bearer $env:GITHUB_TOKEN"
}

$calendar = (Invoke-WebRequest "https://github.com/users/$login/contributions").Content
$days = [regex]::Matches($calendar, 'id="contribution-day-component-(\d+)-(\d+)"\s+data-level="([0-4])"')
if ($days.Count -lt 350) {
    throw 'The GitHub contribution calendar is incomplete.'
}

$colours = @('#21261a', '#364b13', '#597716', '#8db711', '#c7ff18')
$cells = foreach ($day in $days) {
    $x = 26 + 7 * [int]$day.Groups[2].Value
    $y = 112 + 10 * [int]$day.Groups[1].Value
    $colour = $colours[[int]$day.Groups[3].Value]
    "<rect x='$x' y='$y' width='6' height='8' rx='1' fill='$colour'/>"
}

$totals = @{}
$page = 1
do {
    $repos = Invoke-RestMethod "https://api.github.com/users/$login/repos?type=owner&per_page=100&page=$page" -Headers $headers
    foreach ($repo in $repos) {
        if ($repo.fork -or -not $repo.language) { continue }
        $languages = Invoke-RestMethod $repo.languages_url -Headers $headers
        foreach ($language in $languages.PSObject.Properties) {
            $totals[$language.Name] += [long]$language.Value
        }
    }
    $page++
} while ($repos.Count -eq 100)

$total = ($totals.Values | Measure-Object -Sum).Sum
if (-not $total) { throw 'No language data returned by GitHub.' }
$top = @($totals.GetEnumerator() | Sort-Object -Property @{ Expression = 'Value'; Descending = $true }, Key | Select-Object -First 5)
$rows = for ($i = 0; $i -lt $top.Count; $i++) {
    $entry = $top[$i]
    $name = [System.Security.SecurityElement]::Escape($entry.Key)
    $share = $entry.Value / $total
    $label = $share.ToString('P1', [cultureinfo]::InvariantCulture)
    $y = 106 + 18 * $i
    $bar = [math]::Max(1, [math]::Round(150 * $share))
    "<text x='26' y='$y'>$name</text><rect x='178' y='$($y - 8)' width='$bar' height='7' rx='2' fill='#c7ff18'/><text x='396' y='$y' text-anchor='end'>$label</text>"
}

function Write-Card($file, $title, $command, $body) {
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="424" height="218" viewBox="0 0 424 218" role="img" aria-labelledby="title">
  <title id="title">$title</title>
  <rect x="1" y="1" width="422" height="216" rx="9" fill="#11110e" stroke="#34342e"/>
  <path d="M1 38H423" stroke="#34342e"/>
  <circle cx="17" cy="19" r="3" fill="#ff5c35"/>
  <circle cx="29" cy="19" r="3" fill="#98988e"/>
  <circle cx="41" cy="19" r="3" fill="#c7ff18"/>
  <g font-family="Consolas, monospace" font-size="12" fill="#f2f0e8">
    <text x="55" y="23" fill="#98988e">diogo@github: ~</text>
    <text x="26" y="65" fill="#c7ff18">$command</text>
    $body
  </g>
</svg>
"@
    [xml]$svg | Out-Null
    Set-Content -LiteralPath (Join-Path "$PSScriptRoot/../assets" $file) -Value $svg -Encoding utf8
}

Write-Card 'stats.svg' 'Public GitHub contributions over the past year' '$ gh activity' (
    "<text x='26' y='92' fill='#98988e'>PUBLIC CONTRIBUTIONS / PAST YEAR</text>" + ($cells -join "`n")
)
Write-Card 'languages.svg' 'Most-used languages by bytes in public repositories' '$ github linguist' (
    ($rows -join "`n") + "<text x='26' y='203' fill='#98988e'>BY BYTES / PUBLIC REPOSITORIES</text>"
)
