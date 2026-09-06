param(
    [int]$ChatInputFontSize = 17,
    [switch]$SkipChatFontFix,
    [switch]$Status,
    [switch]$Undo,
    [switch]$ForceClose
)

$ErrorActionPreference = "Stop"

function Get-VSCodeInstallRoot {
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd -and $codeCmd.Source) {
        $binDir = Split-Path $codeCmd.Source -Parent
        $candidate = Split-Path $binDir -Parent
        if (Test-Path (Join-Path $candidate "Code.exe")) {
            return $candidate
        }
    }

    $fallback = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code"
    if (Test-Path (Join-Path $fallback "Code.exe")) {
        return $fallback
    }

    throw "VS Code installation was not found."
}

function Get-CurrentVSCodeApp([string]$InstallRoot) {
    $directApp = Join-Path $InstallRoot "resources\app"
    $directWorkbench = Join-Path $directApp "out\vs\workbench\workbench.desktop.main.js"

    if (Test-Path $directWorkbench) {
        $commit = "unknown"
        $productJson = Join-Path $directApp "product.json"

        if (Test-Path $productJson) {
            try {
                $product = Get-Content $productJson -Raw | ConvertFrom-Json
                if ($product.commit) {
                    $commit = ([string]$product.commit).Trim()
                }
            } catch {
                # Commit is informational only.
            }
        }

        return [pscustomobject]@{
            Commit = $commit
            ShortCommit = if ($commit -ne "unknown" -and $commit.Length -ge 10) { $commit.Substring(0, 10) } else { "unknown" }
            App = $directApp
        }
    }

    $versionOutput = @()
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd -and $codeCmd.Source) {
        try {
            $versionOutput = @(& $codeCmd.Source --version 2>$null)
        } catch {
            $versionOutput = @()
        }
    }

    $commit = $null
    if ($versionOutput.Count -ge 2) {
        $candidateCommit = ([string]$versionOutput[1]).Trim()
        if ($candidateCommit.Length -ge 10) {
            $commit = $candidateCommit
        }
    }

    if ($commit) {
        $shortCommit = $commit.Substring(0, 10)
        $app = Join-Path $InstallRoot "$shortCommit\resources\app"
        if (Test-Path (Join-Path $app "out\vs\workbench\workbench.desktop.main.js")) {
            return [pscustomobject]@{
                Commit = $commit
                ShortCommit = $shortCommit
                App = $app
            }
        }

        $buildDir = Get-ChildItem $InstallRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $shortCommit -or $commit.StartsWith($_.Name) } |
            Select-Object -First 1

        if ($buildDir) {
            $app = Join-Path $buildDir.FullName "resources\app"
            if (Test-Path (Join-Path $app "out\vs\workbench\workbench.desktop.main.js")) {
                return [pscustomobject]@{
                    Commit = $commit
                    ShortCommit = $shortCommit
                    App = $app
                }
            }
        }
    }

    $buildCandidates = @(Get-ChildItem $InstallRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $app = Join-Path $_.FullName "resources\app"
            $workbench = Join-Path $app "out\vs\workbench\workbench.desktop.main.js"
            if (Test-Path $workbench) {
                [pscustomobject]@{
                    App = $app
                    Workbench = $workbench
                    BuildDir = $_
                }
            }
        } |
        Sort-Object { $_.BuildDir.LastWriteTime } -Descending)

    if ($buildCandidates.Count -gt 0) {
        $chosen = $buildCandidates[0]
        $name = $chosen.BuildDir.Name
        return [pscustomobject]@{
            Commit = if ($commit) { $commit } else { $name }
            ShortCommit = if ($name.Length -ge 10) { $name.Substring(0, 10) } else { $name }
            App = $chosen.App
        }
    }

    throw "Could not locate the active VS Code resources\app directory."
}

function Stop-VSCodeIfNeeded {
    $running = @(Get-Process Code -ErrorAction SilentlyContinue)
    if ($running.Count -eq 0) {
        return
    }

    if (-not $ForceClose) {
        throw "VS Code is running. Close all VS Code windows first, or run this script with -ForceClose."
    }

    Write-Host "Stopping VS Code..."
    $running | Stop-Process -Force
    Start-Sleep -Seconds 2

    if (Get-Process Code -ErrorAction SilentlyContinue) {
        throw "Some VS Code processes are still running."
    }
}

$installRoot = Get-VSCodeInstallRoot
$build = Get-CurrentVSCodeApp $installRoot
$workbench = Join-Path $build.App "out\vs\workbench\workbench.desktop.main.js"

if (-not (Test-Path $workbench)) {
    throw "workbench.desktop.main.js was not found: $workbench"
}

$text = [IO.File]::ReadAllText($workbench)

# v5 is server-agnostic. It captures the current VS Code window's Remote-SSH
# authority at runtime, then maps local Agent Host POSIX file: URIs into that
# current vscode-remote authority. No host alias or project path is hardcoded.
$runtimeMarker = "codex-remote-authority-runtime-v5"
$remoteMarker = "codex-remote-path-fix-v5"
$runtimeVariable = "__codexRemoteAuthority"

$runtimeCapturePatched =
    $text.Contains($runtimeMarker) -and
    $text.Contains("globalThis.$runtimeVariable")

$remotePatched =
    $text.Contains($remoteMarker) -and
    $text.Contains("authority:globalThis.$runtimeVariable") -and
    $text.Contains('path.startsWith("/")')

# Detect the old v3/v4 server-specific inner rule so it can be migrated in-place.
$legacyRemotePatchPattern =
    'if\(!(?<content>[A-Za-z_$][A-Za-z0-9_$]*)&&(?<uri>[A-Za-z_$][A-Za-z0-9_$]*)\.path\.startsWith\((?<prefix>"(?:\\.|[^"\\])*")\)\)' +
    'return (?<ctor>[A-Za-z_$][A-Za-z0-9_$]*)\.from\(\{scheme:"vscode-remote",authority:(?<authority>"(?:\\.|[^"\\])*"),' +
    'path:\k<uri>\.path,query:\k<uri>\.query,fragment:\k<uri>\.fragment\}\);' +
    '(?:/\*codex-remote-path-fix\*/)?'

$legacyRemotePatchMatches = [regex]::Matches($text, $legacyRemotePatchPattern)

# NativeWorkbenchEnvironmentService has the actual window remoteAuthority.
# This getter is used early in workbench startup; the side effect records it
# in globalThis for the low-level Agent Host URI mapper.
$runtimeGetterPattern = 'get remoteAuthority\(\)\{return this\.configuration\.remoteAuthority\}'
$runtimeGetterMatches = [regex]::Matches($text, $runtimeGetterPattern)

# Pristine wrapAgentHostUri() candidate.
$remoteFunctionPattern =
    'function\s+(?<fn>[A-Za-z_$][A-Za-z0-9_$]*)\((?<uri>[A-Za-z_$][A-Za-z0-9_$]*),(?<auth>[A-Za-z_$][A-Za-z0-9_$]*),(?<content>[A-Za-z_$][A-Za-z0-9_$]*)\)\{' +
    'if\(\k<auth>==="local"&&\k<uri>\.scheme===(?<schemas>[A-Za-z_$][A-Za-z0-9_$]*)\.file\)return \k<uri>;'

# Chat input font fix retained from v4, but can now be skipped independently.
$chatFontTargetPattern =
    '(?<obj>[A-Za-z_$][A-Za-z0-9_$]*)\.fontFamily=[^,;]+[,;]\k<obj>\.fontSize=' +
    [regex]::Escape([string]$ChatInputFontSize) +
    '[,;]\k<obj>\.lineHeight='

$chatFontDefaultPattern =
    '(?<obj>[A-Za-z_$][A-Za-z0-9_$]*)\.fontFamily=[^,;]+[,;]\k<obj>\.fontSize=13[,;]\k<obj>\.lineHeight='

$chatFontTargetMatches = [regex]::Matches($text, $chatFontTargetPattern)
$chatFontPatched = $chatFontTargetMatches.Count -eq 1

Write-Host "VS Code commit         :" $build.Commit
Write-Host "Workbench              :" $workbench
Write-Host "Runtime authority hook :" $runtimeCapturePatched
Write-Host "Universal remote fix   :" $remotePatched
Write-Host "Legacy fixed mappings  :" $legacyRemotePatchMatches.Count
if ($SkipChatFontFix) {
    Write-Host "Chat input font fix    : skipped"
} else {
    Write-Host "Chat input font size   :" $ChatInputFontSize
    Write-Host "Chat input fix         :" $chatFontPatched
}

if ($Status) {
    exit 0
}

$backup = "$workbench.codex-fixes.original.bak"
$oldScriptBackup = "$workbench.codex-remote-path-fix.original.bak"
$legacyRemoteBackup = "$workbench.remote-path-fix.bak"

if ($Undo) {
    Stop-VSCodeIfNeeded

    $sourceBackup = if (Test-Path $backup) {
        $backup
    } elseif (Test-Path $oldScriptBackup) {
        $oldScriptBackup
    } elseif (Test-Path $legacyRemoteBackup) {
        $legacyRemoteBackup
    } else {
        $null
    }

    if (-not $sourceBackup) {
        throw "No original backup was found for the current VS Code build."
    }

    Copy-Item $sourceBackup $workbench -Force

    Write-Host ""
    Write-Host "Restored original workbench:"
    Write-Host $sourceBackup
    Write-Host " -> "
    Write-Host $workbench
    exit 0
}

$needFontPatch = (-not $SkipChatFontFix) -and (-not $chatFontPatched)
if ($runtimeCapturePatched -and $remotePatched -and (-not $needFontPatch)) {
    Write-Host ""
    Write-Host "Nothing to do: requested fixes are already applied to this VS Code build."
    exit 0
}

Stop-VSCodeIfNeeded

# Preflight and build the complete replacement in memory before touching VS Code.
$patchedText = $text

if (-not $runtimeCapturePatched) {
    $getterMatches = [regex]::Matches($patchedText, $runtimeGetterPattern)
    if ($getterMatches.Count -ne 1) {
        throw "Expected exactly one NativeWorkbenchEnvironmentService remoteAuthority getter, found $($getterMatches.Count). VS Code probably changed its bundle; no changes were made."
    }

    $m = $getterMatches[0]
    $runtimeReplacement =
        'get remoteAuthority(){return globalThis.' + $runtimeVariable + '=this.configuration.remoteAuthority,this.configuration.remoteAuthority}' +
        '/*' + $runtimeMarker + '*/'

    $patchedText =
        $patchedText.Substring(0, $m.Index) +
        $runtimeReplacement +
        $patchedText.Substring($m.Index + $m.Length)
}

if (-not $remotePatched) {
    $legacyMatches = [regex]::Matches($patchedText, $legacyRemotePatchPattern)

    if ($legacyMatches.Count -eq 1) {
        $m = $legacyMatches[0]
        $uri = $m.Groups["uri"].Value
        $content = $m.Groups["content"].Value
        $ctor = $m.Groups["ctor"].Value
        $oldPrefix = $m.Groups["prefix"].Value
        $oldAuthority = $m.Groups["authority"].Value

        Write-Host ""
        Write-Host "Migrating old server-specific remote-path fix:"
        Write-Host "  Old prefix    :" $oldPrefix
        Write-Host "  Old authority :" $oldAuthority
        Write-Host "  New mode      : current Remote-SSH window + any absolute path"

        $remoteReplacement =
            'if(!' + $content + '&&globalThis.' + $runtimeVariable + '&&' + $uri + '.path.startsWith("/"))' +
            'return ' + $ctor + '.from({scheme:"vscode-remote",authority:globalThis.' + $runtimeVariable +
            ',path:' + $uri + '.path,query:' + $uri + '.query,fragment:' + $uri + '.fragment});' +
            '/*' + $remoteMarker + '*/'

        $patchedText =
            $patchedText.Substring(0, $m.Index) +
            $remoteReplacement +
            $patchedText.Substring($m.Index + $m.Length)
    } elseif ($legacyMatches.Count -gt 1) {
        throw "Found multiple old server-specific remote-path patches ($($legacyMatches.Count)); refusing to guess. No changes were made."
    } else {
        $remoteMatches = [regex]::Matches($patchedText, $remoteFunctionPattern)

        if ($remoteMatches.Count -ne 1) {
            throw "Expected exactly one pristine wrapAgentHostUri candidate, found $($remoteMatches.Count), and no migratable old patch was found. No changes were made."
        }

        $m = $remoteMatches[0]
        $fn = $m.Groups["fn"].Value
        $uri = $m.Groups["uri"].Value
        $auth = $m.Groups["auth"].Value
        $content = $m.Groups["content"].Value
        $schemas = $m.Groups["schemas"].Value

        $windowLength = [Math]::Min(2500, $patchedText.Length - $m.Index)
        $window = $patchedText.Substring($m.Index, $windowLength)
        $ctorMatch = [regex]::Match($window, 'return\s+(?<ctor>[A-Za-z_$][A-Za-z0-9_$]*)\.from\(\{scheme:')

        if (-not $ctorMatch.Success) {
            throw "Found wrapAgentHostUri, but could not identify its URI constructor. No changes were made."
        }

        $ctor = $ctorMatch.Groups["ctor"].Value

        $remoteReplacement = 'function ' + $fn + '(' + $uri + ',' + $auth + ',' + $content + '){' +
            'if(' + $auth + '==="local"&&' + $uri + '.scheme===' + $schemas + '.file){' +
                'if(!' + $content + '&&globalThis.' + $runtimeVariable + '&&' + $uri + '.path.startsWith("/"))' +
                    'return ' + $ctor + '.from({scheme:"vscode-remote",authority:globalThis.' + $runtimeVariable + ',path:' + $uri + '.path,query:' + $uri + '.query,fragment:' + $uri + '.fragment});' +
                'return ' + $uri + ';' +
            '}' +
            '/*' + $remoteMarker + '*/'

        $patchedText =
            $patchedText.Substring(0, $m.Index) +
            $remoteReplacement +
            $patchedText.Substring($m.Index + $m.Length)
    }
}

if ($needFontPatch) {
    $fontMatches = [regex]::Matches($patchedText, $chatFontDefaultPattern)

    if ($fontMatches.Count -ne 1) {
        throw "Expected exactly one Chat input fontSize=13 candidate, found $($fontMatches.Count). VS Code probably changed its bundle; no changes were made. Use -SkipChatFontFix if you only want the universal remote-path fix."
    }

    $m = $fontMatches[0]
    $old = $m.Value
    $new = $old -replace '\.fontSize=13', ('.fontSize=' + $ChatInputFontSize)

    $patchedText =
        $patchedText.Substring(0, $m.Index) +
        $new +
        $patchedText.Substring($m.Index + $m.Length)
}

# Preserve a genuinely original backup when possible, including backups made by v3/v4.
if (-not (Test-Path $backup)) {
    if (Test-Path $oldScriptBackup) {
        Copy-Item $oldScriptBackup $backup -Force
        Write-Host "Original backup copied from old script backup:"
        Write-Host $backup
    } elseif (Test-Path $legacyRemoteBackup) {
        Copy-Item $legacyRemoteBackup $backup -Force
        Write-Host "Original backup copied from legacy remote-path backup:"
        Write-Host $backup
    } else {
        Copy-Item $workbench $backup -Force
        Write-Host "Original backup created:"
        Write-Host $backup
    }
} else {
    Write-Host "Original backup exists:"
    Write-Host $backup
}

[IO.File]::WriteAllText(
    $workbench,
    $patchedText,
    [Text.UTF8Encoding]::new($false)
)

$verify = [IO.File]::ReadAllText($workbench)

$runtimeVerified =
    $verify.Contains($runtimeMarker) -and
    $verify.Contains("globalThis.$runtimeVariable")

$remoteVerified =
    $verify.Contains($remoteMarker) -and
    $verify.Contains("authority:globalThis.$runtimeVariable") -and
    $verify.Contains('path.startsWith("/")')

if (-not $runtimeVerified) {
    throw "Runtime Remote-SSH authority hook write verification failed."
}

if (-not $remoteVerified) {
    throw "Universal remote-path patch write verification failed."
}

if (-not $SkipChatFontFix) {
    $fontVerified = [regex]::Matches($verify, $chatFontTargetPattern).Count -eq 1
    if (-not $fontVerified) {
        throw "Chat input font-size patch write verification failed."
    }
}

Write-Host ""
Write-Host "VS Code/Codex fixes are applied:"
Write-Host "  Remote-SSH changed-file diff : UNIVERSAL"
Write-Host "  Remote authority source      : current VS Code Remote-SSH window"
Write-Host "  Remote path scope            : any absolute path"
if ($SkipChatFontFix) {
    Write-Host "  Chat input font size         : skipped"
} else {
    Write-Host "  Chat input font size         : $ChatInputFontSize px"
}
Write-Host ""
Write-Host "No server alias or /var/www path is hardcoded. The same patch works for gt-dev, gt-root, stiffyarn and future Remote-SSH hosts."
Write-Host ""
Write-Host "Start VS Code again and test Codex."
Write-Host ""
Write-Host "Note: VS Code may show 'Installation appears to be corrupt' because its integrity check detects the modified built-in bundle."
Write-Host ""
Write-Host "Commands:"
Write-Host "  Apply:        .\fix-vscode-codex-universal.ps1"
Write-Host "  Status:       .\fix-vscode-codex-universal.ps1 -Status"
Write-Host "  Remote only:  .\fix-vscode-codex-universal.ps1 -SkipChatFontFix"
Write-Host "  Undo:         .\fix-vscode-codex-universal.ps1 -Undo"
Write-Host "  Force close:  .\fix-vscode-codex-universal.ps1 -ForceClose"
