# hello-devops — learn the DevOps lifecycle with one button

A one-page website. The "feature" you'll ship is a **Click me** button. It's deliberately
tiny so the attention goes on the *lifecycle*, not the code. Everything runs free on
your laptop.

## The tool map

| Stage | Tool in this lab | What you'd see in an enterprise |
|---|---|---|
| 1. Plan | GitHub Issues | Jira, Azure Boards |
| 2. Code | Git + GitHub pull requests | GitHub / GitLab / Bitbucket |
| 3. Build (CI) | GitHub Actions + Docker | Jenkins, GitLab CI, Azure Pipelines |
| 4. Test | pytest, Ruff (lint), Trivy (security scan) | JUnit, SonarQube, Snyk |
| 5. Release | Git tags + GitHub Container Registry | Artifactory, Nexus, Harbor |
| 6. Deploy (CD) | Argo CD (GitOps) + Terraform (infra) | Argo CD, Flux, Spinnaker, Terraform |
| 7. Operate | Kubernetes (kind, on your laptop) | EKS / AKS / GKE / OpenShift |
| 8. Monitor | Prometheus, Grafana, Alertmanager | Dynatrace, Datadog, PagerDuty |

```
 you ──► Issue ──► branch + PR ──► CI (lint, test, build, scan) ──► merge
                                                                     │
  Grafana ◄── Prometheus ◄── Kubernetes ◄── Argo CD ◄── k8s/ in Git ◄── tag v0.x ──► image in GHCR
     └──────────── what you learn feeds the next Issue ─────────────────────────────────────┘
```

## What's in the repo

```
app/                 the website (Python FastAPI, one HTML page)
tests/               unit tests
Dockerfile           how the app is packaged
.github/workflows/   ci.yml (build + test), release.yml (release + GitOps update)
k8s/                 what "running in prod" looks like: deployment, service, alerts, dashboard
argocd/              tells Argo CD to watch k8s/
infra/               Terraform: builds the cluster + Argo CD + monitoring
Makefile             shortcuts for every command below
```

---

## Part 1 — One-time setup (~15 min)

**Prerequisites** (macOS shown; on Windows use `winget` or WSL2):

```bash
brew install terraform kubectl make python@3.12 git
# plus Docker Desktop — give it at least 6 GB RAM in Settings → Resources
```

**1. Clone and check the app works on your machine**

```bash
git clone https://github.com/8foldfence/hello-devops.git && cd hello-devops
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
make test        # same checks the pipeline runs
make run         # open http://localhost:8000, then Ctrl+C
```

**2. Build the platform with Terraform (Infrastructure as Code)**

```bash
make platform    # ~5 minutes: kind cluster + Argo CD + Prometheus/Grafana
```

Open `infra/main.tf`. That file *is* your infrastructure — no clicking in consoles.
Run `make platform` again and Terraform reports no changes: it is declarative.

**3. Publish the first release (v0.1.0)**

```bash
git tag v0.1.0 && git push origin v0.1.0
```

Watch it in GitHub → **Actions → Release**. When it's green:
- GitHub → your profile → **Packages → hello-devops → Package settings → Change visibility → Public**
  (one time only, so your laptop cluster can pull the image without credentials).
- `git pull` — notice the bot committed `newTag: v0.1.0` into `k8s/kustomization.yaml`.

**4. Hand the app to Argo CD**

```bash
make deploy      # one-time: "Argo CD, please keep the cluster matching k8s/ on main"
```

Open **http://localhost:8080** — "Hello, DevOps!" with *Version v0.1.0* in the footer.

In a second terminal, `make argocd` (it prints the password) → http://localhost:8081.
In a third, `make grafana` → http://localhost:3000 (admin / admin) → Dashboards → **Hello DevOps**.
Note the **Button clicks** panel says *No data*. That's about to change.

---

## Part 2 — Ship the feature through all 8 stages

### 1. Plan — GitHub Issues
GitHub → **Issues → New issue → Feature**. Fill it in:

> **Title:** Add a "Click me" button that counts clicks
> **Acceptance criteria:** button visible on home page · each click increases a counter shown on the page · clicks are visible in Grafana
> **How we'll know it works in prod:** "Button clicks" panel in Grafana shows data

It becomes issue **#1**. *Concept: work is defined, with "done" agreed up front — including how you'll measure it in production.*

### 2. Code — branch + pull request
The code is already written on a branch so you can focus on the flow:

```bash
git fetch && git checkout feature/1-click-button
git diff main --stat          # 3 files: the page, the API, the test
git diff main                 # read the actual change
make test                     # run tests locally before pushing anything
```

On GitHub open a **Pull request** from `feature/1-click-button` into `main`, and write
`Closes #1` in the description. *Concept: small branch, peer review, link to the plan.*

### 3. Build — GitHub Actions (CI)
Opening the PR triggered **CI** automatically (`.github/workflows/ci.yml`). In the PR's
**Checks** tab watch it build the Docker image — the same image will later run in prod.
*Concept: every change is built the same way, by a machine, every time.*

### 4. Test — quality, unit tests, security
Same pipeline, three gates, any of which blocks the merge:
- **Ruff** — code-quality lint
- **pytest** — unit tests, including the new `test_click_button_counts`
- **Trivy** — scans the image for known critical vulnerabilities, then a smoke test hits `/healthz`

**Try it:** break a test on the branch (e.g. change `== 1` to `== 99` in `tests/test_app.py`),
push, and watch the PR go red. Revert, push, it goes green. *Concept: the pipeline, not a
person, decides whether code is safe to merge.*

> To make the gates truly blocking: GitHub → **Settings → Branches → Add rule** for `main`,
> tick *Require status checks to pass* and select `lint-and-test` and `build-and-scan`.

Merge the PR. Issue #1 closes itself.

### 5. Release — tag + container registry
```bash
git checkout main && git pull
git tag v0.2.0 && git push origin v0.2.0
```
The **Release** workflow builds the image `ghcr.io/8foldfence/hello-devops:v0.2.0`, stores it
in the registry, writes release notes (GitHub → **Releases**), and commits the new tag
into `k8s/kustomization.yaml`. *Concept: an immutable, versioned artifact — the thing
you tested is exactly the thing you ship.*

### 6. Deploy — Argo CD (GitOps)
Nobody runs `kubectl apply`. Argo CD notices the commit on `main` (within ~3 minutes, or
press **Refresh** in the UI) and syncs. In the Argo CD UI, watch the app go
*OutOfSync → Syncing → Healthy* and see new pods replace old ones one at a time.
*Concept: Git is the single source of truth; the cluster is made to match it.*

Refresh http://localhost:8080 — the button is there and the footer says **v0.2.0**.

### 7. Operate — Kubernetes
```bash
kubectl --context kind-hello-devops -n hello-devops get pods     # 2 replicas
kubectl --context kind-hello-devops -n hello-devops delete pod --all
kubectl --context kind-hello-devops -n hello-devops get pods -w  # replaced within seconds
```
Kubernetes keeps 2 pods running and only sends traffic to pods whose `/healthz` (readiness
probe) answers. *Concept: self-healing, declared desired state.*

### 8. Monitor — Prometheus + Grafana + Alertmanager
Click the button ~20 times. In Grafana's **Hello DevOps** dashboard the **Button clicks**
panel now shows data, and **Running version** shows v0.2.0. Your acceptance criterion
from stage 1 is met — *in production*, not just in a test.

### ↻ Back to Plan
Notice the counter resets whenever pods restart, and each of the 2 pods counts separately.
That's a real finding from operating the feature. Raise it as issue #2
("Persist the click count") and the loop starts again.

---

## Part 3 — Break things on purpose (the most useful 15 minutes)

**Rollback the GitOps way.** Undo a bad release by reverting the deploy commit:
```bash
git log --oneline -3            # find "deploy: hello-devops v0.2.0"
git revert <that-commit> && git push
```
Argo CD rolls the site back to v0.1.0 — the button disappears. Revert the revert to bring it back.

**Drift is undone.** Change the cluster by hand:
```bash
kubectl --context kind-hello-devops -n hello-devops scale deploy hello-devops --replicas=5
```
Within seconds Argo CD scales it back to 2, because Git says 2 (`selfHeal: true`).

**Fire an alert.** Change `replicas: 2` to `replicas: 0` in `k8s/deployment.yaml`, commit,
push. After ~1–2 minutes `make alerts` → http://localhost:9093 shows **HelloDevopsDown**
(in a company this would page the on-call engineer). Set it back to 2 and push.

---

## Teardown
```bash
make down        # Terraform destroys the cluster and everything in it
```
