# My dotfiles

## Installation

Install with:

`chezmoi init Cydonia7`

## Add machine-specific configuration

Default values for variables can be found in `.chezmoidata.yaml`. Any variable can be customized in
`~/.config/chezmoi/chezmoi.yaml` like this:

```yaml
data:
  alacritty:
    font: "Jetbrains Mono"
```

## Configure the repository with push remote

```bash
chezmoi cd
git remote set-url --push origin git@github.com:Cydonia7/dotfiles.git
```
