# bazzy &nbsp; [![bluebuild build badge](https://github.com/RealSnowl/bazzy/actions/workflows/build.yml/badge.svg)](https://github.com/RealSnowl/bazzy/actions/workflows/build.yml)

Bazzite `stable` with a Hyprland session alongside KDE Plasma. Nothing is
removed from Bazzite; Hyprland shows up as a second entry in the SDDM
session picker.

The recipe is `recipes/recipe.yml`. It enables the
[lionheartp/Hyprland](https://copr.fedorainfracloud.org/coprs/lionheartp/Hyprland/)
COPR at build time only, installs Hyprland and a small set of Wayland
helpers, and folds in the packages that used to be layered on the host with
rpm-ostree. The image is rebuilt every night on top of upstream Bazzite and
published to `ghcr.io/realsnowl/bazzy:latest`.

Design notes: `docs/superpowers/specs/2026-09-05-hyprland-image-design.md`.

## Installation

Rebase an existing Bazzite install. `rpm-ostree reset` comes first because
rpm-ostree refuses to rebase while a layered package is already in the new
base, and every previously layered package is now inside the image.

```sh
rpm-ostree reset
rpm-ostree rebase ostree-unverified-registry:ghcr.io/realsnowl/bazzy:latest
systemctl reboot
```

The unsigned step installs this repo's public key and container policy.
Then switch to the signed image:

```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/realsnowl/bazzy:latest
systemctl reboot
```

Bazzite's updater follows `latest` from then on. `rpm-ostree rollback`
returns to the previous deployment. A full return to stock is a rebase to
`ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable`.

## Verification

Images are signed with [cosign](https://github.com/sigstore/cosign). With
`cosign.pub` from this repo:

```sh
cosign verify --key cosign.pub ghcr.io/realsnowl/bazzy:latest
```

## Maintenance

- A failed nightly build sends an email from GitHub. The host keeps the last
  good image. If the COPR is lagging a Fedora release, pin `image-version`
  to the previous Fedora number until it catches up.
- Dependabot opens PRs for the BlueBuild action. Merge when green.
- Adding a package is one line in the recipe.
