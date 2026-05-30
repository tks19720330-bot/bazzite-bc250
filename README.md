# bazzite-bc250

Custom Bazzite image for AMD BC-250 systems with additional hardware support.

This image is based on Bazzite and includes:

* Nuvoton NCT6687 hardware monitoring driver (`nct6687`)
* AIC8800D80 Wi-Fi driver (`aic8800d80`)
* Automatic module loading and firmware installation

## Features

### NCT6687 Hardware Monitoring

The image builds and installs the out-of-tree NCT6687 kernel module.

Included configuration:

* Automatically loads `nct6687` at boot
* Uses `fan_config=msi_alt1`
* Enables sensor monitoring through `lm_sensors`

Source:

* https://github.com/Fred78290/nct6687d

### AIC8800D80 Wi-Fi Support

The image builds and installs the AIC8800D80 kernel modules and firmware.

Included components:

* `aic_load_fw`
* `aic8800_fdrv`
* Firmware files
* Udev rules for device mode switching
* Automatic module loading at boot

Source:

* https://github.com/shenmintao/aic8800d80

## Installation

Rebase an existing Bazzite installation to this image:

```bash
sudo rpm-ostree rebase \
  ostree-unverified-registry:ghcr.io/tks19720330-bot/bazzite-bc250:stable
```

Reboot after deployment:

```bash
systemctl reboot
```

## Verify Driver Installation

### NCT6687

```bash
lsmod | grep nct6687
```

```bash
sensors
```

### AIC8800D80

```bash
lsmod | grep aic
```

```bash
dmesg | grep -i aic
```

## Updating

This image is automatically built through GitHub Actions when changes are pushed to this repository.

To update a running system:

```bash
rpm-ostree upgrade
```

or:

```bash
ujust update
```

If a new image version is available, reboot to apply the update.

## Building Locally

Install BlueBuild and build the image:

```bash
bluebuild build recipes/recipe.yml
```

## Disclaimer

This project uses third-party kernel modules that are not included in the upstream Bazzite project.

Compatibility may vary depending on:

* Kernel version
* BC-250 hardware revision
* AIC8800D80 adapter revision

Use at your own risk.

## Credits

* Bazzite Team
* Universal Blue Project
* Fred78290 (NCT6687 driver)
* shenmintao (AIC8800D80 driver)
* BlueBuild Project
