# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules =
    [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    label = "root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    label = "boot";
    fsType = "vfat";
  };

  swapDevices = [{ label = "swap"; }];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
