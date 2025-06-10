# PowerShell equivalent of build.sh
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Enable verbose output
Set-PSDebug -Trace 1

# Check if docker buildx is installed
try {
    docker buildx version | Out-Null
}
catch {
    Write-Error "docker buildx is not installed"
    exit 1
}

# Get working directory
$WD = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $WD

# Environment variables setup
if (-not $env:BUILDKIT_PROGRESS) {
    $env:BUILDKIT_PROGRESS = "plain"
}

if (-not $env:LOCAL) {
    $env:LOCAL = "true"
}

# Get image name from git if not set
if (-not $env:IMAGE_NAME) {
    try {
        # Redirect error output to null to silence error messages
        $gitPrefix = git rev-parse --show-prefix 2>$null
        if ([string]::IsNullOrWhiteSpace($gitPrefix)) {
            # Fallback to current directory name if git command returns empty
            $env:IMAGE_NAME = Split-Path -Leaf $WD
        } else {
            $env:IMAGE_NAME = Split-Path -Leaf $gitPrefix
        }
    } catch {
        # Fallback to current directory name if git command fails
        $env:IMAGE_NAME = Split-Path -Leaf $WD
    }
}
if (-not $env:DISABLE_FROM_CACHE) {
    $env:DISABLE_FROM_CACHE = "true"
}

# Chaotic AUR key
# Using the official key from https://aur.chaotic.cx/docs
if (-not $env:CHAOTIC_AUR_KEY) {
    $env:CHAOTIC_AUR_KEY = "3056513887B78AEB"
}

# Setup builder
try {
    # Redirect error output to null to silence error messages
    $gitRemote = git remote get-url origin 2>$null
    if ([string]::IsNullOrWhiteSpace($gitRemote)) {
        # Fallback to current directory name if git command returns empty
        $BUILDER = Split-Path -Leaf $WD
    } else {
        $BUILDER = $gitRemote -replace '\.git$', '' | Split-Path -Leaf
    }
} catch {
    # Fallback to current directory name if git command fails
    $BUILDER = Split-Path -Leaf $WD
}
$BUILDER = $BUILDER + "-builder"
# Check if builder exists, create if not
$builderExists = $false

# Temporarily change error action preference
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

# Check if builder exists
docker buildx inspect $BUILDER > $null 2>&1
if ($LASTEXITCODE -eq 0) {
    $builderExists = $true
}

# Restore error action preference
$ErrorActionPreference = $previousErrorActionPreference

if (-not $builderExists) {
    docker buildx create --bootstrap --name $BUILDER --driver "docker-container"
}

docker buildx use $BUILDER

# Check if required variables are set
if (-not $env:CHAOTIC_AUR_KEY) {
    Write-Error "CHAOTIC_AUR_KEY: Variable not set or empty"
    exit 1
}

# Run docker buildx bake
docker buildx bake --set "default.args.CHAOTIC_AUR_KEY=$($env:CHAOTIC_AUR_KEY)"

# Return to original directory
Pop-Location
