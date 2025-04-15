# My dotfiles

## Installation

Install with:

`chezmoi init Cydonia7`

Install the following packages:

`yay -S lightdm i3-wm i3lock neovim neovim-symlinks lightdm-gtk-greeter chezmoi kitty eza starship keychain zoxide dunst inter-font file-roller ttf-jetbrains-mono feh polybar rofi numlockx picom tmux ttf-nerd-fonts-symbols brightnessctl maim evolution espanso vim-spell-fr snixembed safeeyes xprintidle brightness redshift`

## Add machine-specific configuration

Default values for variables can be found in `.chezmoidata.yaml`. Any variable can be customized in
`~/.config/chezmoi/chezmoi.yaml` like this:

```yaml
data:
  features:
    quotatis: true
```

## Enable private features

To enable private features and fetch the repositories that contain them, edit the file mentioned above and use:

`chezmoi apply -R`

The `-R` flag is needed to force refresh repositories.

## Configure the repository with push remote

```bash
chezmoi cd
git remote set-url --push origin git@github.com:Cydonia7/dotfiles.git
```

## Brightness control on desktop

<https://moverest.xyz/blog/control-display-with-ddc-ci/>

## Configure HiDPI if necessary

```bash
export GDK_SCALE=2
gsettings set org.gnome.settings-daemon.plugins.xsettings overrides "[{'Gdk/WindowScalingFactor', <$GDK_SCALE>}]"
gsettings set org.gnome.desktop.interface scaling-factor $GDK_SCALE
gsettings set org.gnome.desktop.interface text-scaling-factor $GDK_SCALE
echo Xft.dpi: 150 >> .Xresources
echo Xcursor.size: 32 >> .Xresources
```

## Find a high-quality wallpaper

Sources:

- Reddit
- Unsplash
- Starkiteckt Designs

## Enable services

```bash
espanso service register
```
