param(
    [Parameter(Mandatory = $true)][string]$ApkPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-fA-F0-9]{40}$')][string]$TargetCommit,
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version = '1.0.0',
    [ValidateRange(1, 2147483647)][int]$BuildNumber = 2
)
$ErrorActionPreference = 'Stop'
$releaseRepo = 'GuzmanAlv/Plataforma-Concilio-JNI'
$releaseFile = Get-Item -LiteralPath $ApkPath
$releaseName = "concilio-jni-dreamrs-v$Version.apk"
$releaseDigest = (Get-FileHash -LiteralPath $releaseFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$releaseDirectory = Join-Path (Get-Location) 'build/deployment'
New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
$checksumPath = Join-Path $releaseDirectory "$releaseName.sha256"
[IO.File]::WriteAllText($checksumPath, "$releaseDigest  $releaseName`n")

# Use the credential already authorized for this repository; never echo or save it.
$env:GCM_INTERACTIVE = 'never'
$credentialLines = "protocol=https`nhost=github.com`n`n" | git -c credential.interactive=false credential fill
if ($LASTEXITCODE -ne 0) { throw 'Se necesita autorización de GitHub para publicar el APK.' }
$credentialValue = $credentialLines | Where-Object { $_.StartsWith('password=') } | Select-Object -First 1
if (-not $credentialValue) { throw 'GitHub no devolvió una credencial autorizada.' }
$releaseHeaders = @{
    Authorization = 'Bearer ' + $credentialValue.Substring(9)
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'JNI-Dreamrs-Deploy'
    Accept = 'application/vnd.github+json'
}
try {
    $baseUrl = "https://api.github.com/repos/$releaseRepo"
    $existing = @(Invoke-RestMethod -Uri "$baseUrl/releases?per_page=100" -Headers $releaseHeaders)
    $release = $existing | Where-Object { $_.tag_name -eq "v$Version" } | Select-Object -First 1
    if (-not $release) {
        $payload = @{
            tag_name = "v$Version"; target_commitish = $TargetCommit
            name = "Concilio JNI Dreamrs $Version"; draft = $true; prerelease = $false
            body = "Versión Android $Version (compilación $BuildNumber). APK de producción firmado, conectado a Supabase. Incluye asistencia, integrantes, tesorería con cierre mensual e inventario."
        } | ConvertTo-Json
        $release = Invoke-RestMethod -Uri "$baseUrl/releases" -Method Post -Headers $releaseHeaders -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
    }
    if (-not $release.draft) {
        throw 'La versión ya está publicada. No se reemplazarán sus archivos; usa una versión nueva.'
    }
    $uploads = @(
        @{ Name = $releaseName; Path = $releaseFile.FullName; Type = 'application/vnd.android.package-archive' },
        @{ Name = "$releaseName.sha256"; Path = $checksumPath; Type = 'text/plain' }
    )
    foreach ($upload in $uploads) {
        $asset = @($release.assets) | Where-Object { $_.name -eq $upload.Name } | Select-Object -First 1
        if ($asset) { throw "El borrador ya contiene $($upload.Name); revisa su estado antes de continuar." }
        $uploadUrl = "https://uploads.github.com/repos/$releaseRepo/releases/$($release.id)/assets?name=$([Uri]::EscapeDataString($upload.Name))"
        $asset = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $releaseHeaders -ContentType $upload.Type -InFile $upload.Path
        if ($asset.size -ne (Get-Item -LiteralPath $upload.Path).Length) { throw 'El archivo cargado tiene un tamaño incorrecto.' }
        if ($upload.Name -eq $releaseName -and $asset.digest -and $asset.digest -ne "sha256:$releaseDigest") { throw 'El resumen del APK cargado no coincide.' }
    }
    $release = Invoke-RestMethod -Uri "$baseUrl/releases/$($release.id)" -Method Patch -Headers $releaseHeaders -ContentType 'application/json' -Body '{"draft":false}'
    $downloadUrl = "https://github.com/$releaseRepo/releases/download/v$Version/$releaseName"
    $verificationFile = Join-Path $releaseDirectory 'download-verification.apk'
    Invoke-WebRequest -Uri $downloadUrl -OutFile $verificationFile
    if ((Get-FileHash -LiteralPath $verificationFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $releaseDigest) { throw 'La descarga publicada no coincide con el APK firmado.' }
    $metadata = @{
        version = $Version; build = $BuildNumber; commit = $TargetCommit
        apk_url = $downloadUrl; sha256 = $releaseDigest; bytes = $releaseFile.Length
        release_url = $release.html_url
    }
    $metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $releaseDirectory 'release.json') -Encoding utf8
    $metadata | ConvertTo-Json
} finally {
    $releaseHeaders = $null
    $credentialValue = $null
    $credentialLines = $null
}
