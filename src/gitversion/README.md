
# GitVersion

Adds the GitVersion CLI tool as a feature to a devcontainer.

## Example Usage

```json
"features": {
    "ghcr.io/danstis/devcontainers-features/gitversion:0": {
        "version": "latest"
    }
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Controls the version of GitVersion that will be installed. | string | latest |
