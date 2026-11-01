# OmniBridge POS — Evaluation Demo and Integration Guide

**English** | [Español](README.es.md)

[![Preview](https://img.shields.io/badge/Base-1.2.0_preview-orange.svg)](https://github.com/dpadrino/omnibridge-pos-demo/releases/tag/preview)

Native POS peripheral agent with local HTTP interfaces for serial scales,
receipt/label/matrix/document printing and cash drawers. This public repository
contains documentation, integration examples and distribution scripts, **not
the private Rust source**.

## Download and build identity

[Download the current evaluation preview](https://github.com/dpadrino/omnibridge-pos-demo/releases/tag/preview).
The base version stays **1.2.0** during this prototype sprint. Stable tags and
historical releases are not overwritten; `preview` is a prerelease, not `latest`.

Packages are compiled in the agent's GitHub Actions for:

| Platform | Target | Package |
|---|---|---|
| Windows x86_64 | `x86_64-pc-windows-msvc` | `.zip`, includes Inno Setup installer |
| Linux x86_64 | `x86_64-unknown-linux-gnu` | `.tar.gz` |
| macOS Apple Silicon | `aarch64-apple-darwin` | `.tar.gz` |

macOS Intel is not included in this build matrix. Package names include the
version, complete **agent source SHA**, and target. Each package has an external
SHA-256 checksum and a build manifest; internal `SHA256SUMS.txt` verifies its
files. Release notes identify the agent SHA/run and this demo's documentation
SHA. Both repositories distribute **the same verified compiled packages**, not
independent builds from public source.

Publishing to the public demo requires an authenticated maintainer to copy the
verified complete asset set after all three agent builds pass. The public
workflow validates examples/scripts, not Rust compilation or hardware.
Publication is not complete until download hashes and the three identities
agree. No signing keys, customer licenses or local configuration are distributed.

## Installation and safe update

Verify checksums and signatures when provided. Extract outside the installed
directory: **never overwrite a running installation by unpacking over it**.

```powershell
# Administrator, from the separately extracted Windows package
.\scripts\install_windows_service.ps1 -InstallDir 'C:\PosAgent' -Port 8989
.\scripts\diagnose_service.ps1 -Port 8989
```

```sh
# Choose the matching platform; do not execute both installers
sudo bash scripts/install_linux_service.sh 8989
sudo bash scripts/install_macos_service.sh 8989
sudo bash scripts/diagnose_service.sh 8989
```

Installers preserve existing configuration/license/master key, stop before
replacement, retain backups, and require service manager + HTTP liveness before
success. Failed updates remain failures even if recovery succeeds. The port
argument checks availability; it does not change saved configuration.
Gatekeeper quarantine is not removed automatically.

[Deployment and recovery guide](docs/DEPLOYMENT_GUIDE.md) |
[Pilot acceptance playbook](docs/PILOT_DEPLOYMENT_AND_DIAGNOSTICS_PLAYBOOK.md)

## Configuration, security and integration

The restricted local administration panel covers non-secret service settings,
requires a separate admin credential/session and validates Origin/CSRF.
Saving configuration does **not** imply live activation: compare active/saved
values and restart when indicated. Operational API authentication and CORS are
separate controls; loopback access alone is not an admin authorization.

Use the [validated JavaScript consumer example](https://dpadrino.github.io/omnibridge-pos-demo/#pos-integration-example)
and [OpenAPI contract](docs/openapi.yaml), not unchecked three-line requests.
Handle non-JSON errors and HTTP status before using the response. Do not
automatically resend print requests after 503/504 or an ambiguous failure.
The agent admits four concurrent print dispatch workers; scale locking is
independent.

```sh
node --test scripts/consumer_contract.test.mjs
```

## Honest support and acceptance limits

- Serial detection/parser support is not compatibility with every scale.
- Successful printing means backend submission, not paper output or drawer movement.
- Simulation and the [online showcase](https://dpadrino.github.io/omnibridge-pos-demo/)
  do not certify physical devices.
- Biometric network paths cover bounded ZKTeco attendance/ADMS/JSON push.
  USB capture and fingerprint enrollment are not implemented and return 501;
  attendance is volatile. Do not use this as a certified biometric product.
- Native service installation/update and actual peripheral acceptance still
  require dedicated Windows/Linux/macOS stations and model-level testing.

[Video demonstration](docs/OmniBridge_POS_Promo_Video.mp4) |
[Historical commercial brochure](docs/OmniBridge_POS_Brochure_Comercial.en.pdf)

Videos, brochures and legacy compatibility lists are illustrative historical
material, not current acceptance evidence; this README, current contracts and
release notes define the preview's limits.

## Licensing

Without a valid commercial license, the agent runs under its evaluation
restrictions; it does not grant unlimited access or implemented support for
every endpoint. See [proprietary license](LICENSE.txt) and
[third-party licenses](docs/THIRD_PARTY_LICENSES.md).
