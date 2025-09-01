# security-scan-containers

GitHub Action to scan container images with **CrowdStrike Falcon Cloud Security**.

This action authenticates to CrowdStrike using CI-provided credentials and scans a target OCI image (GHCR, ECR, Docker Hub, etc.). Intended for use across repos—projects just add a single workflow step that calls this action.

---

## 🧩 Inputs

| Input                  | Required | Description                                                                                     | Example                                            |
| ---------------------- | -------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `image_name`           | ✅        | Full image reference (repo\:tag) to scan.                                                       | `ghcr.io/bigdata-com/bigdata-risk-analyzer:latest` |
| `falcon_client_id`     | ✅        | CrowdStrike API Client ID (store as secret).                                                    | `${{ secrets.FALCON_CLIENT_ID }}`                  |
| `falcon_client_secret` | ✅        | CrowdStrike API Client Secret (store as secret).                                                | `${{ secrets.FALCON_CLIENT_SECRET }}`              |
| `falcon_region`        | ✅        | CrowdStrike cloud region (e.g., `us-1`, `us-2`, `eu-1`). Put in secrets if org policy requires. | `${{ secrets.FALCON_REGION }}`                     |
| `fcs_version`          | ⛔/✅      | Version of the Falcon Container Security CLI/sensor to use. Pin for reproducibility.            | `"2.0.2"`                                          |

> The action sets these as env vars for the inline script:
> `FALCON_CLIENT_ID`, `FALCON_CLIENT_SECRET`, `FALCON_REGION`, `FCS_VERSION`, `IMAGE_NAME`.

---

## 🚀 Usage (in a consuming repo)

```yaml
name: Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      # Needed if pulling from GHCR private images:
      packages: read
    steps:
      - name: Checkout (optional if only scanning a remote image)
        uses: actions/checkout@v4

      # If the image is in GHCR and private, ensure GHCR login first:
      # - name: Log in to GHCR
      #   uses: docker/login-action@v3
      #   with:
      #     registry: ghcr.io
      #     username: ${{ github.actor }}
      #     password: ${{ secrets.GITHUB_TOKEN }}

      - name: Run security scan
        uses: Bigdata-com/security-scan-containers@master
        with:
          image_name: ghcr.io/bigdata-com/bigdata-risk-analyzer:latest
          falcon_client_id: ${{ secrets.FALCON_CLIENT_ID }}
          falcon_client_secret: ${{ secrets.FALCON_CLIENT_SECRET }}
          falcon_region: ${{ secrets.FALCON_REGION }}
          fcs_version: "2.0.2"

      # (Optional) Upload scanner reports if this action writes them to disk (e.g., reports/scan.json)
      # - name: Upload scan artifact
      #   uses: actions/upload-artifact@v4
      #   with:
      #     name: crowdstrike-scan
      #     path: reports/**
```

> If your image is private in GHCR, keep the `packages: read` permission and login to GHCR (commented step above).
> For ECR/GCR/ACR, add the corresponding login step before the scan.

---

## 🔐 Secrets & permissions

* **Secrets** (org/repo level):

  * `FALCON_CLIENT_ID`
  * `FALCON_CLIENT_SECRET`
  * `FALCON_REGION` (if you prefer not to hardcode)
* **Permissions**:

  * `packages: read` if pulling a private image from GHCR.
  * Additional cloud auth (AWS/GCP/Azure) if the target image lives in ECR/GCR/ACR.

---

## 📦 Example: scanning from ECR

```yaml
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Log in to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Run security scan
        uses: Bigdata-com/security-scan-containers@master
        with:
          image_name: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.${{ secrets.AWS_REGION }}.amazonaws.com/your-repo:tag
          falcon_client_id: ${{ secrets.FALCON_CLIENT_ID }}
          falcon_client_secret: ${{ secrets.FALCON_CLIENT_SECRET }}
          falcon_region: ${{ secrets.FALCON_REGION }}
          fcs_version: "2.0.2"
```

---

## ✅ Exit behavior & reports

* The action’s inline script runs the CrowdStrike scan and should **exit non-zero** if findings breach your policy (e.g., fail on High/Critical).
* If the script writes reports (e.g., JSON/SARIF) to a `reports/` directory, add an **Upload Artifact** step (see usage snippet) or publish SARIF to a security dashboard if supported.

> If you want a configurable **severity gate** (e.g., fail on `CRITICAL,HIGH`), expose it as a new action input and enforce it in the inline script.

---

## 🛠️ Local dev quick check (optional)

You can dry-run the CLI locally (outside Actions) to validate connectivity and credentials before wiring a repo:

```bash
export FALCON_CLIENT_ID=xxx
export FALCON_CLIENT_SECRET=yyy
export FALCON_REGION=eu-1
export FCS_VERSION=2.0.2
# Then run the same commands your inline script uses against an image like:
# ghcr.io/bigdata-com/bigdata-risk-analyzer:latest
```

---

## ❗ Troubleshooting

* **401/403 from CrowdStrike** → verify `FALCON_CLIENT_ID/SECRET/REGION`.
* **Image pull denied** → ensure registry login and required permissions (`packages: read` for GHCR private).
* **Rate limits / timeouts** → run on release tags only or nightly; avoid scanning large multi-arch images on every PR.
* **No reports in artifacts** → confirm the inline script writes files to a known path (e.g., `reports/`).
* **Matrix builds** → pin `fcs_version` and avoid concurrent pulls on the same rate-limited registry.

---

## 🗺️ Roadmap

* Input for severity gate (e.g., `fail_on: "CRITICAL,HIGH"`).
* Optional SARIF output & `upload-sarif` step.
* Support for SBOM generation/attestation as an optional output.

---

## 📄 License

MIT

