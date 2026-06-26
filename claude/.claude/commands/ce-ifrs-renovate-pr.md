---
name: ce-ifrs-renovate-pr
description: "Find and fix renovate PRs across the ce-ifrs Azure DevOps org (discovers failing 'update non-major' PRs, pulls their grype CVEs, pins the fix, builds, pushes)"
---

Find and fix the automatic "update non-major" renovate PRs across the ce-ifrs
Azure DevOps org (`Devops-BTV-Extern`). Repos are cloned under `~/repos/ce-ifrs`.
Tooling lives in `~/repos/ce-ifrs/scripts` (enter it with `nix-shell`).

## 0. Discovery setup (authenticated browser)

Azure DevOps needs auth and the tenant blocks `az login`, so drive the REST API
through an authenticated Chrome via CDP. Chrome 136+ ignores
`--remote-debugging-port` on the default profile, so a dedicated profile is used
and the user logs in once.

- Launch: `~/repos/ce-ifrs/scripts/launch-chrome-cdp.sh` (handles the Wayland env
  + flags, waits for CDP on :9222). Ask the user to **log into Azure DevOps** in
  the new window, then continue.
- All queries run as JS in the page origin via `python cdp.py eval < some.js`
  (`fetch(..., {credentials:'include'})` against the REST API just works).

## 1. Triage

From `~/repos/ce-ifrs/scripts`: `nix-shell --run "python cdp.py eval < triage.js"`

Returns every active PR with "update non-major" in the title, its Build policy
status (`approved` = green, `rejected` = failing, `queued`/`running` = pending),
and the grype CVE table when the PR pipeline prints it. Fix the `rejected` ones.

When presenting results, output a markdown table whose PR cell is a real link
using each PR's `url` field (e.g. `[#6753](https://dev.azure.com/.../pullrequest/6753)`).
Do NOT write bare `#1234` — terminal GFM auto-linkifies that to github.com.

## 2. Get the grype CVEs for a failing PR

The CVE table tells you what to pin (`INSTALLED` → `FIXED IN` per package):

- **RiskAndFinanceRoadmap** PR pipelines print the table in the build log →
  it's already in `triage.js`'s `grypeTable`.
- **SenacorIFRS** PR pipelines write it to a `scan_reports/cves.txt` artifact
  that is only published on **main** builds (`grypeTable` is null). Fetch it:
  1. Edit `PROJECT`/`REPO` in `latest_main_scan.js`, then
     `python cdp.py eval < latest_main_scan.js` → latest main `buildId` with a
     `scan_reports` artifact.
  2. `python cdp.py download SenacorIFRS <buildId> scan_reports`
  3. `unzip -o /tmp/cdpdl/scan_reports.zip -d /tmp/scan_out && cat /tmp/scan_out/scan_reports/cves.txt`

  (cves.txt from main reflects the pinned dep on main; the renovate PR keeps the
  same manual pin, so the fix is the same bump.)

## 3. Fix the repo

In `~/repos/ce-ifrs/<repo>`:

1. `git fetch origin && git checkout renovate/non-major-dependencies && git pull --ff-only`
2. Build & test. Use `./mvnw -B clean install` if a wrapper exists, else
   `nix-shell -p maven --run "mvn -B clean install"` (NixOS: no global `mvn`).
3. **Run grype locally** — replicates the pipeline's scan so you can fix without
   waiting for it (and cross-checks section 2). After the build populates
   `./target`:

   ```sh
   nix-shell -p syft grype --run '
     mkdir -p scan_reports
     syft --from dir ./target -o json=scan_reports/sbom.json
     grype sbom:scan_reports/sbom.json --fail-on medium \
       --config /home/flo/repos/ce-ifrs/ci-base/standalone/.grype.yml -o table
   '
   ```

   This mirrors `ci-base/azure-test.yml` exactly (syft `./target` → grype on the
   SBOM, `--fail-on medium`, same `.grype.yml`). The `.grype.yml` ignore list
   suppresses accepted/false-positive CVEs — **always pass it** or you'll chase
   CVEs the pipeline deliberately ignores. The table it prints is the
   authoritative `INSTALLED → FIXED IN` list to pin; grype exits non-zero while
   any medium+ remains.
4. **Trace each flagged package in the dependency tree first.** Run
   `mvn dependency:tree` (via the wrapper or `nix-shell`) and locate where the
   vulnerable artifact comes from. It is almost always transitive — note the
   *outermost* (direct or parent-managed) package that drags it in. Before
   force-pinning the transitive version, check whether a bump to that outer
   package — or simply *removing* a stale local pin so the Spring Boot parent's
   newer managed version takes over — already pulls a fixed transitive. Prefer
   that: it's the cleaner fix, avoids version-property overrides that drift, and
   sometimes the parent default is already past the `FIXED IN` (a local pin may
   even be holding it *back* on a vulnerable version). Verify with
   `dependency:tree` that the resolved version is now `>= FIXED IN`. Only fall
   back to an explicit version-property pin (step 5) when no upstream bump
   resolves it, or when the fixed version was never published (e.g. the advisory
   names a patch that isn't on Maven Central — jump to the next published release
   that sits outside the affected range).
5. **Pin** each still-flagged package to its `FIXED IN` version (usually a
   `<x.version>` property fed by the Spring Boot parent). Always pin to the fixed
   version — there are no false positives; an unfixed CVE fails the pipeline. Add
   a comment documenting the resolved CVEs, e.g.:

   ```xml
   <!-- Pinned to resolve netty CVEs:
        4.2.13.Final -> 4.2.15.Final: GHSA-3qp7-7mw8-wx86 (netty-handler, High)
        ... -->
   <netty.version>4.2.15.Final</netty.version>
   ```

   (single-line form: `<lib.version>1.2.3.4</lib.version> <!-- pinned to resolve 1.2.3 GHSA-… (lib-name, Medium) -->`)
6. **Prune obsolete pin comments**: a pin-comment line reads `from -> to: CVE`;
   if the property value is now higher than that line's `to` target, the line is
   superseded — remove it (replace with the current set when re-pinning).
7. Build & test again, then **re-run the grype scan from step 3**. Iterate until
   it reports no medium+ CVEs (clean, zero exit) — that's the same gate the
   pipeline applies.
8. Commit & push the `renovate/non-major-dependencies` branch.

## 4. Confirm

Re-run `triage.js` after the pipelines re-run; the fixed PRs should flip from
`rejected` to `queued`/`running` → `approved`.
