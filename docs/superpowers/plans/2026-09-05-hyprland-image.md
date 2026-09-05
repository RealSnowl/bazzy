# Hyprland-on-Bazzite Image Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a signed BlueBuild image `ghcr.io/realsnowl/bazzy:latest` that is Bazzite stable plus a Hyprland session, and rebase this machine onto it.

**Architecture:** One BlueBuild recipe in this repo, built nightly by GitHub Actions on top of `ghcr.io/ublue-os/bazzite:stable`. The recipe enables the `lionheartp/Hyprland` COPR at build time only, installs Hyprland and its helpers plus the eight packages currently layered on the host, and signs the result with a cosign key whose private half lives in a repo secret. The host then does a reset, an unsigned rebase, and a signed rebase.

**Tech Stack:** BlueBuild recipe v1 (`recipes/recipe.yml`), `blue-build/github-action@v1.11`, cosign, rpm-ostree, `gh` CLI, podman (only to run the BlueBuild validator container).

**Spec:** `docs/superpowers/specs/2026-09-05-hyprland-image-design.md`

## Global Constraints

- Base image is `ghcr.io/ublue-os/bazzite` with `image-version: stable`. Never any other base.
- Hyprland packages come only from the `lionheartp/Hyprland` COPR, release builds (`hyprland`, never `hyprland-git`).
- The recipe has no `remove` block. Nothing is taken out of Bazzite.
- `cleanup: true` on the COPR list so the booted image contains no Hyprland repo file.
- The published tag consumed by the host is `latest`.
- The cosign private key is never committed. `cosign.key` is already in `.gitignore`; check `git status` before every commit in Task 3.
- No local image builds. Only `bluebuild validate` runs locally, via the CLI container.
- All work happens on the `hyprland-image` branch until Task 4 merges it.
- Commits end with the two trailer lines shown in each commit step.
- Two of the tasks end in a reboot. The executor's session ends there; the next task starts in a fresh session from the repo directory `~/Projects/bazzy`.

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `recipes/recipe.yml` | rewrite | The entire OS delta. Base, COPR, package list, signing module. |
| `files/scripts/example.sh` | delete | Template demo. Unused. |
| `files/system/` | keep, empty | Reserved for future system overlays. Two `.gitkeep` files stay. |
| `README.md` | rewrite | What the image is, how to rebase, how to verify. |
| `cosign.pub` | replace | Public half of this repo's signing key. |
| `.github/workflows/build.yml` | unchanged | Template workflow already correct. |
| `.github/dependabot.yml` | unchanged | Bumps the action version. |

Working directory for every task: `~/Projects/bazzy`, branch `hyprland-image`.

---

### Task 1: Rewrite the recipe

**Files:**
- Modify: `recipes/recipe.yml` (replace whole file)
- Delete: `files/scripts/example.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `recipes/recipe.yml` with `name: bazzy`. The workflow matrix already references `recipe.yml`, so the name inside decides the published path `ghcr.io/realsnowl/bazzy`.

- [ ] **Step 1: Confirm starting state**

Run:
```sh
cd ~/Projects/bazzy && git status -sb && git branch --show-current
```
Expected: `## hyprland-image`, working tree clean, branch `hyprland-image`. If on `main`, run `git checkout hyprland-image` first.

- [ ] **Step 2: Replace the recipe**

Write this exact content to `recipes/recipe.yml`:

```yaml
---
# yaml-language-server: $schema=https://schema.blue-build.org/recipe-v1.json
# Published to ghcr.io/realsnowl/bazzy
name: bazzy
description: Bazzite with a Hyprland session alongside KDE.

# Exactly the image this machine runs today, tracked at its stable tag.
base-image: ghcr.io/ublue-os/bazzite
image-version: stable

modules:
  - type: dnf
    repos:
      # The COPR exists only inside the build. cleanup drops its repo
      # file before the image is finished, so nothing on the booted
      # system can layer from it.
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
        # previously layered with rpm-ostree on the host
        - aspell
        - aspell-en
        - cmake
        - direnv
        - emacs
        - java-25-openjdk-devel
        - mpv

  # Bakes cosign.pub and a container policy into the image so
  # rpm-ostree verifies every future update against this repo's key.
  - type: signing
```

- [ ] **Step 3: Delete the template's example script**

Run:
```sh
git rm -q files/scripts/example.sh && ls files/scripts 2>&1
```
Expected: `ls` reports the directory is gone or empty (git does not track empty directories). `files/system/etc/.gitkeep` and `files/system/usr/.gitkeep` must still exist: `ls files/system/etc/.gitkeep files/system/usr/.gitkeep`.

- [ ] **Step 4: Check the YAML parses and has the right shape**

Run:
```sh
python3 - <<'PY'
import yaml
r = yaml.safe_load(open("recipes/recipe.yml"))
assert r["name"] == "bazzy", r["name"]
assert r["base-image"] == "ghcr.io/ublue-os/bazzite", r["base-image"]
assert r["image-version"] == "stable", r["image-version"]
assert [m["type"] for m in r["modules"]] == ["dnf", "signing"], [m["type"] for m in r["modules"]]
dnf = r["modules"][0]
assert dnf["repos"]["cleanup"] is True
assert dnf["repos"]["copr"] == ["lionheartp/Hyprland"]
assert "remove" not in dnf, "no remove block allowed"
pkgs = dnf["install"]["packages"]
assert len(pkgs) == 24, len(pkgs)
assert "hyprland-git" not in pkgs
for p in ["hyprland","xdg-desktop-portal-hyprland","hyprpolkitagent","hyprlock","hypridle","hyprpaper",
          "waybar","rofi","dunst","grim","slurp","cliphist","wev","pavucontrol","network-manager-applet","blueman","nwg-bar",
          "aspell","aspell-en","cmake","direnv","emacs","java-25-openjdk-devel","mpv"]:
    assert p in pkgs, p
print("recipe shape OK")
PY
```
Expected: `recipe shape OK`.

- [ ] **Step 5: Validate with the BlueBuild CLI container**

The container's entrypoint is `dumb-init`, so the command must start with `bluebuild`. The `:z` on the volume is needed for SELinux on Bazzite.

Run:
```sh
podman run --rm -v "$PWD":/bluebuild:z -w /bluebuild ghcr.io/blue-build/cli:latest bluebuild validate recipes/recipe.yml
```
Expected: last line `INFO  => Recipe recipes/recipe.yml is valid`. Any `ERROR` line means the YAML violates the schema; fix and re-run.

- [ ] **Step 6: Commit**

```sh
git add recipes/recipe.yml
git commit -m "Base the recipe on Bazzite and add a Hyprland session

Replaces the Silverblue template recipe. Installs Hyprland and helpers from
the lionheartp/Hyprland COPR (repo removed after install), plus the eight
packages previously layered on the host with rpm-ostree.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01AfDUGNrT5qoyWZUupF8Kyb"
git status -sb
```
Expected: clean tree on `hyprland-image`. The `git rm` from Step 3 is included because `git rm` stages the deletion.

---

### Task 2: Rewrite the README

**Files:**
- Modify: `README.md` (replace whole file)

**Interfaces:**
- Consumes: image path `ghcr.io/realsnowl/bazzy` from Task 1.
- Produces: the rebase and verify commands that Tasks 5 through 7 run verbatim.

- [ ] **Step 1: Replace the README**

Write this exact content to `README.md`:

````markdown
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
````

- [ ] **Step 2: Check the README references the right image everywhere**

Run:
```sh
grep -c 'ghcr.io/realsnowl/bazzy' README.md; grep -n 'blue-build/template' README.md || echo "no template refs"
```
Expected: first line `4` or more, second line `no template refs`.

- [ ] **Step 3: Commit**

```sh
git add README.md
git commit -m "Describe the bazzy image and its rebase procedure

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01AfDUGNrT5qoyWZUupF8Kyb"
```

---

### Task 3: Signing key

**Files:**
- Replace: `cosign.pub`
- Never commit: `cosign.key`

**Interfaces:**
- Consumes: nothing.
- Produces: repo secret `SIGNING_SECRET` (read by `.github/workflows/build.yml` as `cosign_private_key`) and a committed `cosign.pub` that the `signing` module bakes into the image and that Task 5 verifies against.

- [ ] **Step 1: Confirm the ignore rule and secret state**

Run:
```sh
grep -n '^cosign.key$' .gitignore && gh secret list --repo RealSnowl/bazzy
```
Expected: the grep prints the line number of `cosign.key`; the secret list is empty (no `SIGNING_SECRET` yet). If `SIGNING_SECRET` already exists, stop and ask the user whether to rotate it, since overwriting it orphans any image already signed.

- [ ] **Step 2: Generate the key pair with an empty password**

GitHub Actions cannot decrypt a passworded key. `COSIGN_PASSWORD=""` makes cosign skip the prompt.

Run:
```sh
cd ~/Projects/bazzy && rm -f cosign.pub && COSIGN_PASSWORD="" cosign generate-key-pair && ls -l cosign.key cosign.pub && head -1 cosign.pub
```
Expected: both files listed, `cosign.key` mode `-rw-------`, and `cosign.pub` starts with `-----BEGIN PUBLIC KEY-----`.

- [ ] **Step 3: Confirm the public key changed from the template placeholder**

Run:
```sh
git diff --stat cosign.pub && ! git diff --quiet cosign.pub && echo "cosign.pub replaced"
```
Expected: a diff stat for `cosign.pub` and the line `cosign.pub replaced`.

- [ ] **Step 4: Upload the private key as the repo secret**

Run:
```sh
gh secret set SIGNING_SECRET --repo RealSnowl/bazzy < cosign.key && gh secret list --repo RealSnowl/bazzy
```
Expected: `SIGNING_SECRET` listed with today's date.

- [ ] **Step 5: Delete the private key locally and prove it is not staged**

Run:
```sh
shred -u cosign.key 2>/dev/null || rm -f cosign.key; ls cosign.key 2>&1; git status --porcelain
```
Expected: `ls` reports no such file; `git status --porcelain` shows only ` M cosign.pub`.

- [ ] **Step 6: Commit the public key**

```sh
git add cosign.pub
git commit -m "Replace template signing key with this repo's public key

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01AfDUGNrT5qoyWZUupF8Kyb"
git show --stat HEAD | tail -3
```
Expected: exactly one file changed, `cosign.pub`.

---

### Task 4: Publish and build

**Files:** none changed locally. Remote state: repo visibility, branch push, PR merge.

**Interfaces:**
- Consumes: the three commits from Tasks 1 through 3 on `hyprland-image`.
- Produces: `ghcr.io/realsnowl/bazzy:latest`, signed, built from `main`. Intermediate proof: `ghcr.io/realsnowl/bazzy:br-hyprland-image-44` from the branch push.

- [ ] **Step 1: Make the repo public**

Public repos get unlimited Actions minutes and the host needs no registry credentials to pull. The flag pair is required by `gh`.

Run:
```sh
gh repo edit RealSnowl/bazzy --visibility public --accept-visibility-change-consequences && gh repo view RealSnowl/bazzy --json visibility --jq .visibility
```
Expected: `PUBLIC`.

- [ ] **Step 2: Push the branch and start the build**

Run:
```sh
git push -u origin hyprland-image && sleep 20 && gh run list --repo RealSnowl/bazzy --branch hyprland-image --limit 1
```
Expected: one run for workflow `bluebuild` on `hyprland-image`, status `in_progress` or `queued`.

- [ ] **Step 3: Watch the branch build to completion**

A Bazzite build takes 25 to 40 minutes. `gh run watch` blocks until it ends; run it with a long timeout, or poll `gh run list` every few minutes.

Run:
```sh
RUN_ID=$(gh run list --repo RealSnowl/bazzy --branch hyprland-image --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --repo RealSnowl/bazzy --exit-status && echo BUILD_OK
```
Expected: `BUILD_OK`. If it fails, read `gh run view "$RUN_ID" --log-failed --repo RealSnowl/bazzy`. The most likely failure is a package name the COPR or Fedora does not carry; fix the recipe, commit, push, repeat this step. Do not weaken the recipe with `skip-unavailable`.

- [ ] **Step 4: Confirm the branch tag exists in the registry**

BlueBuild tags non-default-branch builds as `br-<branch>-<fedora version>`.

Run:
```sh
skopeo list-tags docker://ghcr.io/realsnowl/bazzy | jq -r '.Tags[]' | grep -E '^br-hyprland-image-4[0-9]$'
```
Expected: one line, `br-hyprland-image-44` (the number is the Fedora release Bazzite stable is on).

- [ ] **Step 5: Merge to main**

Run:
```sh
gh pr create --repo RealSnowl/bazzy --base main --head hyprland-image \
  --title "Hyprland session on Bazzite" \
  --body "Bazzite stable plus Hyprland from the lionheartp/Hyprland COPR, folding in previously layered packages. Design in docs/superpowers/specs/2026-09-05-hyprland-image-design.md.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01AfDUGNrT5qoyWZUupF8Kyb"
gh pr merge --repo RealSnowl/bazzy --merge --delete-branch=false hyprland-image
git checkout main && git pull --ff-only && git log --oneline -1
```
Expected: the PR merges, local `main` fast-forwards, and the top commit is the merge commit.

- [ ] **Step 6: Watch the main build**

Run:
```sh
sleep 20
RUN_ID=$(gh run list --repo RealSnowl/bazzy --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --repo RealSnowl/bazzy --exit-status && echo MAIN_BUILD_OK
```
Expected: `MAIN_BUILD_OK`.

- [ ] **Step 7: Confirm `latest` exists**

Run:
```sh
skopeo list-tags docker://ghcr.io/realsnowl/bazzy | jq -r '.Tags[]' | grep -x latest
```
Expected: `latest`.

---

### Task 5: Pre-rebase checks

**Files:** none.

**Interfaces:**
- Consumes: `ghcr.io/realsnowl/bazzy:latest` from Task 4 and `cosign.pub` from Task 3.
- Produces: go/no-go for Task 6.

- [ ] **Step 1: Verify the signature with the committed public key**

Run:
```sh
cd ~/Projects/bazzy && git checkout -q main && cosign verify --key cosign.pub ghcr.io/realsnowl/bazzy:latest >/dev/null && echo SIGNATURE_OK
```
Expected: `SIGNATURE_OK`. A failure means the secret and the committed key are not a pair; redo Task 3 and rebuild.

- [ ] **Step 2: Confirm the image was built from today's Bazzite**

Run:
```sh
skopeo inspect docker://ghcr.io/realsnowl/bazzy:latest | jq '.Labels | to_entries | map(select(.key | test("version|base.name|created|bazzite"))) | from_entries'
```
Expected: a base-name label containing `ghcr.io/ublue-os/bazzite`, a version label starting with the current Fedora number (`44.` today), and a created timestamp within the last few hours. If the version is older than what `rpm-ostree status` shows for the current Bazzite deployment, the build used a stale base; re-run the workflow with `gh workflow run build.yml --repo RealSnowl/bazzy` and wait as in Task 4 Step 6.

- [ ] **Step 3: Record the current deployment for rollback reference**

Run:
```sh
rpm-ostree status --booted | tee ~/Projects/bazzy/docs/superpowers/plans/pre-rebase-status.txt
```
Expected: shows `ghcr.io/ublue-os/bazzite:stable` with the `LayeredPackages` line listing aspell through waybar. This file is a scratch note; do not commit it.

---

### Task 6: Unsigned rebase (ends with a reboot)

**Files:** none.

**Interfaces:**
- Consumes: go from Task 5.
- Produces: a booted deployment of `bazzy:latest` with the repo's public key and container policy installed under `/etc`, which Task 7 needs.

- [ ] **Step 1: Drop the layered packages**

Run:
```sh
rpm-ostree reset && rpm-ostree status | sed -n '1,12p'
```
Expected: a new pending deployment of `ghcr.io/ublue-os/bazzite:stable` with no `LayeredPackages` line above the booted one.

- [ ] **Step 2: Rebase to the unsigned image**

Run:
```sh
rpm-ostree rebase ostree-unverified-registry:ghcr.io/realsnowl/bazzy:latest
```
Expected: pulls several gigabytes, ends with `Changes queued for next boot. Run "systemctl reboot" to start a reboot`. If it errors with `is already in the base`, the reset from Step 1 did not take: run `rpm-ostree cleanup -p && rpm-ostree reset` and repeat this step.

- [ ] **Step 3: Confirm the pending deployment has no layers**

Run:
```sh
rpm-ostree status | sed -n '1,12p'
```
Expected: the pending deployment reads `ostree-unverified-registry:ghcr.io/realsnowl/bazzy:latest` and has no `LayeredPackages` line. Do not reboot if it shows layered packages.

- [ ] **Step 4: Reboot**

Tell the user the session will end here, then run:
```sh
systemctl reboot
```
The next task starts in a new session after login.

---

### Task 7: Signed rebase (ends with a reboot)

**Files:** none.

**Interfaces:**
- Consumes: booted unsigned `bazzy:latest` from Task 6.
- Produces: booted, signature-verified `bazzy:latest`. This is the final OS state.

- [ ] **Step 1: Confirm the unsigned image is booted and the policy landed**

Run:
```sh
rpm-ostree status --booted | head -5 && ls /etc/pki/containers/ && grep -l realsnowl /etc/containers/registries.d/*.yaml
```
Expected: booted deployment is `ostree-unverified-registry:ghcr.io/realsnowl/bazzy:latest`; a `.pub` file for bazzy exists under `/etc/pki/containers/`; one registries.d file mentions `realsnowl`. If the policy files are missing, the `signing` module did not run; check the build log before continuing.

- [ ] **Step 2: Rebase to the signed image**

Run:
```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/realsnowl/bazzy:latest
```
Expected: mostly cached, ends with `Changes queued for next boot`. A signature error here means Task 5 Step 1 was skipped or the key was rotated after the build.

- [ ] **Step 3: Reboot**

Tell the user the session will end here, then run:
```sh
systemctl reboot
```

---

### Task 8: Acceptance

**Files:** none committed. Delete the scratch note at the end.

**Interfaces:**
- Consumes: booted signed image from Task 7.
- Produces: the spec's acceptance criteria, checked.

- [ ] **Step 1: Deployment is signed and has no layers**

Run:
```sh
rpm-ostree status --booted
```
Expected: `ostree-image-signed:docker://ghcr.io/realsnowl/bazzy:latest`, a `Version:` starting with the current Fedora number, and no `LayeredPackages` line.

- [ ] **Step 2: Packages are in the base**

Run:
```sh
rpm -q hyprland xdg-desktop-portal-hyprland hyprlock hypridle hyprpaper hyprpolkitagent waybar rofi dunst grim slurp cliphist wev pavucontrol network-manager-applet blueman nwg-bar aspell aspell-en cmake direnv emacs java-25-openjdk-devel mpv | grep -c -v 'not installed'
```
Expected: `24`.

- [ ] **Step 3: No Hyprland COPR on the live system**

Run:
```sh
ls /etc/yum.repos.d/ | grep -i hypr || echo "no hyprland repo file"
```
Expected: `no hyprland repo file`.

- [ ] **Step 4: SDDM can see the session**

Run:
```sh
ls /usr/share/wayland-sessions/ && grep -E '^(Name|Exec)=' /usr/share/wayland-sessions/hyprland.desktop
```
Expected: both `plasma.desktop` and `hyprland.desktop` listed; `Name=Hyprland` and an `Exec=` line.

- [ ] **Step 5: Manual login test (user does this)**

Ask the user to log out, pick Hyprland in SDDM's session menu, and log in.
Stock Hyprland shows a plain desktop with an on-screen notice that the default
config is in use. Stock keybinds: Super+M exits Hyprland back to SDDM, and
Super+Q would open kitty, which is not installed, so it does nothing. Ask the
user to press Super+M, then log into Plasma and confirm it still works.
Acceptance is the user reporting both: Hyprland started, and Plasma still
works. If Hyprland does not start, ask the user to log into Plasma and send
the output of `journalctl -b -g -i hyprland | tail -50`.

- [ ] **Step 6: Clean up the scratch note**

Run:
```sh
rm -f ~/Projects/bazzy/docs/superpowers/plans/pre-rebase-status.txt && cd ~/Projects/bazzy && git status --porcelain
```
Expected: no output.

- [ ] **Step 7: Delete the merged branch**

Run:
```sh
git branch -d hyprland-image && git push origin --delete hyprland-image
```
Expected: local and remote branch deleted; `main` remains.
