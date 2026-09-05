# Hyprland on Bazzite via a BlueBuild image — design

Date: 2026-09-05
Status: approved in brainstorming, awaiting implementation plan

## Goal

Add a Hyprland session to this machine without changing anything else
about Bazzite. KDE Plasma, SDDM, Steam, gamescope and `ujust` all stay.
Hyprland appears as a second entry in the SDDM session picker.

The mechanism is a BlueBuild recipe in this repo. GitHub Actions builds it
on top of `ghcr.io/ublue-os/bazzite:stable` and publishes a signed image to
`ghcr.io/realsnowl/bazzy:latest`. The machine rebases to it once; after
that Bazzite's normal updater pulls this image instead of upstream.

This is the OS-layer half only. Hyprland, waybar and rofi configuration is
a separate project, managed by chezmoi, and is out of scope here.

## Context

- Host: Bazzite `stable`, Fedora 44, AMD RX 6800, one 2560x1440 display
  on HDMI-A-1 at 1.25 scale. Wired and wifi both in use.
- Hyprland is not in Fedora's repositories (the package is retired). The
  `solopasha/hyprland` COPR most guides cite has gone dormant for current
  Fedora. `lionheartp/Hyprland` is the maintained COPR: Hyprland 0.56 plus
  the hypr* ecosystem, built for Fedora 43, 44, 45 and rawhide.
- The machine currently layers eight packages with rpm-ostree: aspell,
  aspell-en, cmake, direnv, emacs, java-25-openjdk-devel, mpv, rofi,
  waybar. These move into the image so nothing is layered afterwards.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Delivery | BlueBuild recipe in this repo | Declarative, ~30 lines, the OS-layer analogue of a Guix `operating-system` |
| Base | `ghcr.io/ublue-os/bazzite`, tag `stable` | Exactly the image running now |
| Hyprland source | `lionheartp/Hyprland` COPR, release packages | Only COPR building for Fedora 44 and 45 |
| Layered packages | Folded into the image | Single source of truth for the OS layer |
| Removals | None | "Bazzite plus Hyprland", nothing taken away |
| Repo visibility | Public | Unlimited Actions minutes; no pull credentials on the host; recipe holds nothing secret |
| Published tag | `latest` (BlueBuild default) | Nothing depends on a custom tag |
| Local builds | Not done | CI builds every push; a local Bazzite build is ~10 GB for no extra signal |

Alternatives rejected: forking `ashebanow/hyprblue` (Containerfile plus
shell, 40-odd packages to strip), Bazzite's own `image-template`
(flexible but imperative), and layering the COPR directly with rpm-ostree
(fastest, but a COPR on the live system and nothing declared).

## The recipe

`recipes/recipe.yml` becomes exactly this. Everything the template shipped
that is not listed here is deleted: the Silverblue base, the starship COPR,
the Firefox removal, the `default-flatpaks` module, `files/scripts/example.sh`.

```yaml
name: bazzy
description: Bazzite with a Hyprland session alongside KDE.
base-image: ghcr.io/ublue-os/bazzite
image-version: stable

modules:
  - type: dnf
    repos:
      cleanup: true
      copr:
        - lionheartp/Hyprland
    install:
      packages:
        # Hyprland session, from the COPR
        - hyprland
        - xdg-desktop-portal-hyprland
        - hyprpolkitagent
        - hyprlock
        - hypridle
        - hyprpaper
        # desktop plumbing, from Fedora
        - waybar
        - rofi
        - dunst
        - grim
        - slurp
        - cliphist
        - wev
        - pavucontrol
        - network-manager-applet
        - blueman
        - nwg-bar
        # previously layered with rpm-ostree
        - aspell
        - aspell-en
        - cmake
        - direnv
        - emacs
        - java-25-openjdk-devel
        - mpv

  - type: signing
```

Notes:

- `cleanup: true` removes the COPR repo file after the install step, so
  the booted system carries no Hyprland repository. Nothing can be layered
  from it by accident.
- No `remove` block and no `files` module. The `hyprland` package installs
  the SDDM session file and `xdg-desktop-portal-hyprland` installs the
  portal preference file. User-level configuration belongs to chezmoi.
- The COPR also carries newer builds of packages such as qt6ct, kitty and
  matugen. None are in Bazzite and the repo is gone after install, so they
  cannot displace anything.
- `files/system/` stays in the repo, empty, for future system overlays.

## Workflow

`.github/workflows/build.yml` stays as the template ships it: nightly at
06:00 UTC (twenty minutes after Bazzite's own builds start), on every push
that touches non-Markdown files, and on manual dispatch. One recipe in the
matrix. `maximize_build_space: true` stays on; a Bazzite build needs it.

`.github/dependabot.yml` stays. It opens PRs bumping the BlueBuild action.

## Signing

1. `cosign generate-key-pair` in the repo root, empty password (Actions
   cannot use an encrypted key).
2. Replace the template's `cosign.pub` with the generated one and commit.
3. `gh secret set SIGNING_SECRET < cosign.key`, then delete `cosign.key`.
   `cosign.key` is already in the template's `.gitignore`; verify before
   committing anything.

If the private key is ever lost: generate a new pair, commit the new
public key, rebase to the unsigned image once, then to the signed image.

## Rebase procedure

Only after the first Actions run is green and the pre-checks below pass.

```sh
rpm-ostree reset
rpm-ostree rebase ostree-unverified-registry:ghcr.io/realsnowl/bazzy:latest
systemctl reboot
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/realsnowl/bazzy:latest
systemctl reboot
```

- `rpm-ostree reset` first. rpm-ostree refuses to rebase while a layered
  package is already present in the new base ("Package X is already in the
  base"). The eight packages come back from inside the image.
- The unsigned rebase installs the public key and container policy into
  `/etc`; the signed rebase then verifies against them. Both reboots are
  required.

Rollback: the previous Bazzite deployment remains in the GRUB menu, and
`rpm-ostree rollback` returns to it in one reboot. That deployment has no
layered packages (they were reset), so re-layer only if the image is
abandoned. Full return to stock is a rebase to
`ostree-image-signed:docker://ghcr.io/ublue-os/bazzite:stable`.

After the rebase, Bazzite's updater tracks `bazzy:latest` with no further
configuration. The image lags upstream Bazzite by roughly an hour.

## Verification

Before rebasing:

- Actions run green. First build expected at 25 to 40 minutes.
- `cosign verify --key cosign.pub ghcr.io/realsnowl/bazzy:latest` succeeds
  from this machine, proving the secret and committed public key match.
- `skopeo inspect docker://ghcr.io/realsnowl/bazzy:latest` shows the
  expected Bazzite version in the image labels.

After the signed reboot (acceptance criteria):

- `rpm-ostree status` shows the `ostree-image-signed` bazzy deployment
  with no `LayeredPackages` line.
- `rpm -q hyprland emacs waybar` all resolve.
- SDDM lists a Hyprland session. Logging in with the stock Hyprland config
  yields a working compositor with `hyprctl version` responding.
- Logging back into Plasma works unchanged.

## Maintenance

- **Failed nightly build.** GitHub emails. The machine keeps the last good
  image. The usual cause is the COPR lagging a Fedora major release; the
  fix is pinning `image-version` to the previous Fedora number until the
  COPR catches up, then un-pinning.
- **Dependabot PRs.** Merge when green.
- **Adding a package.** One line in the recipe. On the machine after the
  next nightly build and update.

## Out of scope

- All Hyprland, waybar, rofi, dunst and hyprpaper configuration.
- Video wallpaper. Neither Fedora nor the COPR packages `mpvpaper`; the
  config project decides how to bring it back.
- Any change to KDE, SDDM autologin, portals beyond what the packages
  install, or Bazzite's own COPRs.
