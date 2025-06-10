# PowerShell script for building docker image without buildx
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Enable verbose output
Set-PSDebug -Trace 1

# Get working directory
$WD = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $WD

# Environment variables setup
if (-not $env:BUILDKIT_PROGRESS) {
    $env:BUILDKIT_PROGRESS = "plain"
}

# Ensure BuildKit is enabled for Docker secret support
$env:DOCKER_BUILDKIT = "1"

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

# Chaotic AUR key
# Using the official key from https://aur.chaotic.cx/docs
if (-not $env:CHAOTIC_AUR_KEY) {
    $env:CHAOTIC_AUR_KEY = "3056513887B78AEB"
}

# GitHub Token for authentication
# This will be passed as a secret to the Docker image
# Leave empty if not needed
if (-not $env:GITHUB_TOKEN) {
    $env:GITHUB_TOKEN = ""
}

# Determine tag and repository info
try {
    # Redirect error output to null to silence error messages
    $gitRemote = git remote get-url origin 2>$null
    if ([string]::IsNullOrWhiteSpace($gitRemote)) {
        # Fallback to current directory name if git command returns empty
        $repoName = Split-Path -Leaf $WD
    } else {
        $repoName = $gitRemote -replace '\.git$', '' | Split-Path -Leaf
    }
} catch {
    # Fallback to current directory name if git command fails
    $repoName = Split-Path -Leaf $WD
}

# Check if required variables are set
if (-not $env:CHAOTIC_AUR_KEY) {
    Write-Error "CHAOTIC_AUR_KEY: Variable not set or empty"
    exit 1
}

# Note: GITHUB_TOKEN is optional, so we don't exit if it's not set

# Determine the tag based on LOCAL environment variable
if ($env:LOCAL -eq "true") {
    $tag = "gp-archlinux-workspace"
} else {
    $registryHostname = if ($env:REGISTRY_HOSTNAME) { $env:REGISTRY_HOSTNAME } else { "docker.io" }
    $registryUsername = if ($env:REGISTRY_USERNAME) { $env:REGISTRY_USERNAME } else { "fjolsvin" }
    $tag = "${registryHostname}/${registryUsername}/gp-archlinux-workspace:latest"
}

# Build the Docker image using standard docker build
Write-Host "Building Docker image with tag: $tag"
$buildCommand = "docker build --load -f gitpod/Dockerfile"

# Add build arguments
$buildCommand += " --build-arg CHAOTIC_AUR_KEY=$($env:CHAOTIC_AUR_KEY)"

# Add GitHub Token as a secret if it's set
if ($env:GITHUB_TOKEN) {
    Write-Host "Adding GITHUB_TOKEN as a secret"
    $buildCommand += " --secret id=github_token,env=GITHUB_TOKEN"
}

# Add tag
$buildCommand += " -t $tag"

# Set ulimits if possible (this is normally handled in docker-bake.hcl)
# Note: Standard docker build doesn't support ulimits directly during build

# Add context
$buildCommand += " ."

# Execute the build command
Write-Host "Executing: $buildCommand"
Invoke-Expression $buildCommand

# If not local and we want to push the image
if ($env:LOCAL -ne "true") {
    Write-Host "Pushing image to registry: $tag"
    docker push $tag
}

# Return to original directory
Pop-Location

Write-Host "Build completed successfully"
