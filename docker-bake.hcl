# vim: filetype=hcl softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2
# ────────────────────────────────────────────────────────────────────────────────
# usage guide
# ╭──────────────────────────────────────────────────────────╮
# │ 1- create a builder for this file                        │
# ╰──────────────────────────────────────────────────────────╯
# docker buildx create --use --name "$(basename -s ".git" "$(git remote get-url origin)")" --driver docker-container
# ╭──────────────────────────────────────────────────────────╮
# │ 2-A run build without pushing to dockerhub               │
# ╰──────────────────────────────────────────────────────────╯
# LOCAL=true docker buildx bake --builder "$(basename -s ".git" "$(git remote get-url origin)")"
# ╭──────────────────────────────────────────────────────────╮
# │  2-B Run the build and push to docker hub                │
# ╰──────────────────────────────────────────────────────────╯
# docker buildx bake --builder "$(basename -s ".git" "$(git remote get-url origin)")"
# ╭──────────────────────────────────────────────────────────╮
# │                     cleanup builder                      │
# ╰──────────────────────────────────────────────────────────╯
# docker buildx use default && docker buildx ls | awk '$2 ~ /^docker(-container)*$/{print $1}' | xargs -r -I {} docker buildx rm {}
variable "LOCAL" {default=false}
variable "IMAGE_NAME" {default="gp-archlinux-workspace"}
variable "TAG" {default=""}
variable "MAIN_REGISTRY_HOSTNAME" {default="docker.io"}
variable "MAIN_REGISTRY_USERNAME" {default="fjolsvin"}
variable "CACHE_REGISTRY_HOSTNAME" {default="docker.io"}
variable "CACHE_REGISTRY_USERNAME" {default="fjolsvin"}
group "default" {
  targets = [
    "base",
  ]
}
target "base" {
  context    = "."
  dockerfile = "base/Dockerfile"
  tags       = [
    equal(LOCAL,true)
    ? "${IMAGE_NAME}-base"
    : "${MAIN_REGISTRY_HOSTNAME}/${MAIN_REGISTRY_USERNAME}/${IMAGE_NAME}-base:latest",
      equal("",TAG)?"" : "${MAIN_REGISTRY_HOSTNAME}/${MAIN_REGISTRY_USERNAME}/${IMAGE_NAME}-base:${TAG}",
  ]
  cache-from = [
    equal(LOCAL,true)
    ? ""
    : "type=registry,mode=max,ref=${CACHE_REGISTRY_HOSTNAME}/${CACHE_REGISTRY_USERNAME}/${IMAGE_NAME}-base-cache:latest" ,
      equal("",TAG) ? "": "type=registry,mode=max,ref=${CACHE_REGISTRY_HOSTNAME}/${CACHE_REGISTRY_USERNAME}/${IMAGE_NAME}-base-cache:${TAG}"
  ]
  cache-to   = [
    equal(LOCAL,true)
    ? ""
    : "type=registry,mode=max,ref=${CACHE_REGISTRY_HOSTNAME}/${CACHE_REGISTRY_USERNAME}/${IMAGE_NAME}-base-cache:latest" ,
      equal("",TAG) ? "" : "type=registry,mode=max,ref=${CACHE_REGISTRY_HOSTNAME}/${CACHE_REGISTRY_USERNAME}/${IMAGE_NAME}-base-cache:${TAG}",
  ]
  output     = [
    equal(LOCAL,true)
    ? "type=docker"
    : "type=registry",
  ]
}
