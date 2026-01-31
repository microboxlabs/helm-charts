# MicroboxLabs Helm Charts

A curated collection of Helm charts for Kubernetes deployments, including custom charts and an enhanced distribution of [Alfresco Helm Charts](https://github.com/Alfresco/alfresco-helm-charts).

## Quick Start

### Add the Helm Repository

```bash
helm repo add microboxlabs https://microboxlabs.github.io/helm-charts/
helm repo update
```

### Search Available Charts

```bash
helm search repo microboxlabs
```

### Install a Chart

```bash
helm install my-release microboxlabs/<chart-name>
```

## Available Charts

### Custom Charts

| Chart | Description |
|-------|-------------|
| `quarkus-sse` | Quarkus Server-Sent Events application |

### Alfresco Charts

This repository includes an enhanced distribution of Alfresco Helm Charts with additional configuration options:

| Chart | Description |
|-------|-------------|
| `activemq` | ActiveMQ message broker |
| `alfresco-repository` | Alfresco Content Repository |
| `alfresco-search-enterprise` | Alfresco Search Enterprise (Elasticsearch) |
| `alfresco-search-service` | Alfresco Search Services (Solr) |
| `alfresco-share` | Alfresco Share UI |
| `alfresco-sync-service` | Alfresco Sync Service |
| `alfresco-transform-service` | Alfresco Transform Service |
| `alfresco-common` | Common templates and helpers |

## Documentation

Full documentation is available at: **https://microboxlabs.github.io/helm-charts/**

The documentation includes:
- Installation guides
- Chart configuration reference
- Architecture guides
- Best practices

## Development

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/) v3.x
- [Node.js](https://nodejs.org/) v20+ (for documentation site)

### Local Development

```bash
# Clone the repository
git clone https://github.com/microboxlabs/helm-charts.git
cd helm-charts

# Lint charts
helm lint charts/quarkus-sse
helm lint charts/alfresco/charts/*

# Template a chart locally
helm template my-release charts/quarkus-sse
```

### Documentation Site

```bash
cd docs
npm install
npm run dev      # Development server at http://localhost:3002/helm-charts/
npm run preview  # Build and preview static site
```

## Repository Structure

```
helm-charts/
├── .github/workflows/     # CI/CD workflows
│   ├── ci.yaml           # Chart linting and releases
│   ├── docs.yml          # Documentation deployment
│   └── sync-*.yaml       # Alfresco upstream sync
├── charts/
│   ├── alfresco/         # Alfresco charts (git subtree)
│   └── quarkus-sse/      # Custom charts
└── docs/                 # Nextra documentation site
```

## Alfresco Upstream Sync

This repository maintains a fork of Alfresco Helm Charts using `git subtree`. Changes from the upstream repository are automatically detected weekly and proposed via Pull Request.

To manually sync with upstream:

```bash
# Add upstream remote (if not already added)
git remote add alfresco-upstream https://github.com/Alfresco/alfresco-helm-charts.git

# Fetch and merge upstream changes
git fetch alfresco-upstream main --no-tags
git subtree pull --prefix=charts/alfresco alfresco-upstream main --squash
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Lint your charts (`helm lint charts/<chart-name>`)
5. Commit your changes (`git commit -m 'feat: add new feature'`)
6. Push to the branch (`git push origin feature/my-feature`)
7. Open a Pull Request

### Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `ci:` - CI/CD changes
- `chore:` - Maintenance tasks

## License

- Custom charts: MIT License
- Alfresco charts: See [Alfresco License](https://github.com/Alfresco/alfresco-helm-charts/blob/main/LICENSE)
