# GitHub Actions Workflows

This directory contains GitHub Actions workflows for CI/CD automation of the Cloudflare WARP Site-to-Site Connector project.

## Workflows Overview

### 1. Build Workflow (`build.yml`)

Unified workflow that handles CI, building, and releases with conditional execution.

**Triggers**:

- Push to `main` branch
- Pull requests to `main` branch
- Tag pushes matching pattern `v*.*.*` (e.g., `v1.0.0`, `v2.1.3`)

**Jobs**:

#### Lint Job

- Runs Hadolint on Dockerfiles
- Validates shell scripts with ShellCheck
- Runs on all triggers

#### Build Job

- Builds both Docker images (WARP Connector and Docker Events Handler) with proper OCI metadata
- Conditional behavior based on trigger:
  - **Pull Requests**: Build only (load locally, no push)
  - **Tag Push**: Build multi-platform images, push with semantic version tags, create GitHub Release (draft)

**Image Tags** (based on trigger):

- PR: `pr-<number>` (not pushed)
- Branch: `main` (not pushed)
- Tag: `v1.2.3`, `v1.2`, `v1`, `latest`

**Features**:

- Single source of truth for build configuration
- Docker layer caching for faster builds
- OCI image metadata (title, description, source, version, licenses)
- Multi-platform builds for releases (amd64 for WARP Connector, amd64/arm64 for Docker Events Handler)
- Automatic GitHub Release creation (draft) with usage instructions

### 2. Security Scan Workflow (`security-scan.yml`)

Runs on:

- All pushes
- All pull requests

**Purpose**: Detect hardcoded secrets and leaked sensitive data.

**Jobs**:

#### GitGuardian Scan

- Scans for hardcoded secrets, API keys, credentials
- Checks commit history for leaked sensitive data
- Requires `GITGUARDIAN_API_KEY` secret to be configured
- Uses shallow fetch (depth: 1) for performance

## Setup Instructions

### Required Secrets

Configure these secrets in your GitHub repository settings (`Settings` → `Secrets and variables` → `Actions`):

1. **GITGUARDIAN_API_KEY** (Required for GitGuardian security scanning)
   - Sign up at https://www.gitguardian.com/
   - Generate an API key from your dashboard
   - Add as repository secret

The `GITHUB_TOKEN` is automatically provided by GitHub Actions for package publishing and release creation.

### Required Permissions

The workflows require the following permissions (automatically granted via `permissions` in workflow files):

- `contents: read` - Read repository contents
- `contents: write` - Create releases (release workflow only)
- `packages: write` - Push to GitHub Container Registry
- `security-events: write` - Upload security scan results

### GitHub Container Registry Setup

Images are automatically published to GitHub Container Registry (GHCR). No additional setup required.

**Image URLs**:

```
ghcr.io/<owner>/<repo>/warp-connector:latest
ghcr.io/<owner>/<repo>/dehandler:latest
```

To pull images, authenticate with GitHub:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin
docker pull ghcr.io/<owner>/<repo>/warp-connector:latest
```

For public repositories, authentication is not required for pulling images.

### Making Images Public

By default, GHCR images are private. To make them public:

1. Go to your repository on GitHub
2. Click on "Packages" in the right sidebar
3. Select the package (warp-connector or dehandler)
4. Click "Package settings"
5. Scroll to "Danger Zone" and click "Change visibility"
6. Select "Public"

## Usage Examples

### Triggering Builds

The build workflow runs automatically based on the event:

**For Pull Requests** (build and test only):

```bash
git checkout -b feature-branch
git add .
git commit -m "Update Dockerfile"
git push origin feature-branch
# Create PR on GitHub
```

**For Branch Commits** (build only, no push):

```bash
git add .
git commit -m "Update Dockerfile"
git push origin main
```

**For Releases** (build, push, and create GitHub Release):

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will:

1. Build multi-platform Docker images with version tags
2. Push to GHCR at `ghcr.io/<owner>/<repo>/warp-connector:v1.0.0` and `ghcr.io/<owner>/<repo>/dehandler:v1.0.0`
3. Create a draft GitHub Release with auto-generated release notes and usage instructions

### Using Released Images

Update your `docker-compose.yml`:

```yaml
services:
  warp-connector:
    image: ghcr.io/<owner>/<repo>/warp-connector:v1.0.0
    # Remove the 'build' directive
    # ... rest of configuration

  dehandler:
    image: ghcr.io/<owner>/<repo>/dehandler:v1.0.0
    # Remove the 'build' directive
    # ... rest of configuration
```

### Viewing Security Scan Results

1. Check workflow logs in the "Actions" tab
2. Review GitGuardian scan results for any detected secrets
3. If secrets are found, rotate them immediately and update your code

## Workflow Status Badges

Add these badges to your README.md:

```markdown
![Build](https://github.com/genzj/warp-to-warp-container/workflows/Build/badge.svg)
![Security Scan](https://github.com/genzj/warp-to-warp-container/workflows/Security%20Scan/badge.svg)
```

## Troubleshooting

### Build Failures

Check the workflow logs in the "Actions" tab. Common issues:

- Dockerfile syntax errors (caught by Hadolint)
- Missing dependencies
- Network issues during package installation

### Release Not Publishing

Ensure:

- Tag follows semantic versioning (`v*.*.*`)
- `GITHUB_TOKEN` has package write permissions (automatic)
- Repository settings allow GitHub Actions to create packages

### Security Scan Failures

- **GitGuardian**: Ensure `GITGUARDIAN_API_KEY` secret is set correctly
- Review workflow logs for detected secrets or sensitive data
- Rotate any exposed credentials immediately

### Image Pull Authentication Issues

For private images:

```bash
# Create a Personal Access Token with 'read:packages' scope
echo $PAT | docker login ghcr.io -u <username> --password-stdin
```

## Best Practices

1. **Semantic Versioning**: Use proper semantic version tags (v1.0.0, v2.1.0)
2. **Security**: Regularly review security scan results and update dependencies
3. **Testing**: Test locally before pushing tags
4. **Documentation**: Update CHANGELOG.md with each release
5. **Image Size**: Keep images minimal; review Dockerfile for optimization opportunities

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [OCI Image Spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- [GitGuardian Documentation](https://docs.gitguardian.com/)
