#!/usr/bin/env bash
# Bash script for building docker image without buildx
set -euo pipefail

# Enable verbose output
set -x

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Navigate to repository root
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
pushd "$REPO_ROOT" > /dev/null

# Set working directory to the script's directory for image name logic
WD="$SCRIPT_DIR"

# Environment variables setup
if [ -z "${BUILDKIT_PROGRESS:-}" ]; then
    export BUILDKIT_PROGRESS="plain"
fi

# Ensure BuildKit is enabled for Docker secret support
export DOCKER_BUILDKIT="1"

if [ -z "${LOCAL:-}" ]; then
    export LOCAL="true"
fi

# Get image name from git if not set
if [ -z "${IMAGE_NAME:-}" ]; then
    # Try to get git prefix
    gitPrefix=$(git rev-parse --show-prefix 2>/dev/null || true)
    if [ -z "$gitPrefix" ]; then
        # Fallback to current directory name if git command returns empty
        IMAGE_NAME=$(basename "$WD")
    else
        IMAGE_NAME=$(basename "$gitPrefix")
    fi
    export IMAGE_NAME
fi

# GitHub Token for authentication
# This will be passed as a secret to the Docker image
# Leave empty if not needed
if [ -z "${GITHUB_TOKEN:-}" ]; then
    export GITHUB_TOKEN=""
fi

# Determine tag and repository info
gitRemote=$(git remote get-url origin 2>/dev/null || true)
if [ -z "$gitRemote" ]; then
    # Fallback to current directory name if git command returns empty
    repoName=$(basename "$WD")
else
    repoName=$(basename "${gitRemote%.git}")
fi

# Note: GITHUB_TOKEN is optional, so we don't exit if it's not set

# Determine the tag based on LOCAL environment variable
tag="claude-code"
if [ "$LOCAL" != "true" ]; then
    registryHostname="${REGISTRY_HOSTNAME:-docker.io}"
    registryUsername="${REGISTRY_USERNAME:-fjolsvin}"
    tag="${registryHostname}/${registryUsername}/${tag}:latest"
fi

# Build the Docker image using standard docker build
echo "Building Docker image with tag: $tag"
buildCommand="docker build --load -f claude-code/Dockerfile"

# Add GitHub Token as a secret if it's set
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Adding GITHUB_TOKEN as a secret"
    buildCommand+=" --secret id=github_token,env=GITHUB_TOKEN"
fi

# Add tag
buildCommand+=" -t $tag"

# Set ulimits if possible (this is normally handled in docker-bake.hcl)
# Note: Standard docker build doesn't support ulimits directly during build

# Add context
buildCommand+=" ."

# Execute the build command
echo "Executing: $buildCommand"
eval "$buildCommand"

# If not local and we want to push the image
if [ "$LOCAL" != "true" ]; then
    echo "Pushing image to registry: $tag"
    docker push "$tag"
fi

# Return to original directory
popd > /dev/null

echo "Build completed successfully"