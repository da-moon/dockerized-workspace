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
variable "REGISTRY_HOSTNAME" {default="docker.io"}
variable "REGISTRY_USERNAME" {default="fjolsvin"}
group "default" {
  targets = [
    "gitpod",
  ]
}
target "gitpod" {
  context    = "."
  dockerfile = "gitpod/Dockerfile"
  tags       = [
    equal(LOCAL,true)
    ? "gp-archlinux-workspace"
    : "${REGISTRY_HOSTNAME}/${REGISTRY_USERNAME}/gp-archlinux-workspace:latest",
  ]
  cache-from = [
    equal(LOCAL,true)
    ? ""
    : "type=registry,mode=max,ref=${REGISTRY_HOSTNAME}/${REGISTRY_USERNAME}/gp-archlinux-workspace:cache" ,
  ]
  cache-to   = [
    equal(LOCAL,true)
    ? ""
    : "type=registry,mode=max,ref=${REGISTRY_HOSTNAME}/${REGISTRY_USERNAME}/gp-archlinux-workspace:cache" ,
  ]
  output     = [
    equal(LOCAL,true)
    ? "type=docker"
    : "type=registry",
  ]
}
