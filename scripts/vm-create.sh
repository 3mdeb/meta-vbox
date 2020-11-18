#!/bin/bash

errorCheck() {
    local error_code="$?"
    local error_msg="$1"
    if [ "$error_code" -ne 0  ]; then
        echo "[ERROR] $error_msg : $error_code"
        exit 1
    fi
}

if [ "$#" -ne 2 ]; then
  echo "Usage:    $0 <NAME_OF_MACHINE> <PATH_TO_VMDK>"
  echo "Example:  $0 vm1 core-image-minimal-qemux86-64.wic.vmdk"
  exit 1
fi

VM_NAME="$1"
VMDK_FILE="$2"
# harcode to eno1, it needs to be changed anyway after OVA gets imported
BRIDGED_IFACE="eno1"

if [ -z "$VM_NAME" ]; then
  echo "VM_NAME must not be empy"
  exit 1
fi

if [ ! -f "$VMDK_FILE" ]; then
  echo "VMDK_FILE: \"$VMDK_FILE\" does not exist"
  exit 1
fi

VMDK_FILE="$(readlink -f $VMDK_FILE)"

vboxmanage --help &> /dev/null
errorCheck "vboxmanage not found, make sure that VirtualBox is installed"

echo "Checking if $VM_NAME already exists..."
vboxmanage showvminfo "$VM_NAME" &> /dev/null
# if ther is no error code, it means that VM with given name already exists and
# we should remove it before continuing
if [ $? -eq 0 ]; then
  echo "VM $VM_NAME already exists, removing it..."

  # detach disk (VMDK file) before removing machine
  # then close medium
  # don't care if any of those fails
  vboxmanage storageattach "$VM_NAME" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium none
  vboxmanage closemedium disk $VMDK_FILE

  vboxmanage unregistervm --delete "$VM_NAME"
  errorCheck "vboxmanage unregistervm failed"
  echo "VM $VM_NAME removed"
fi

PARENT_UUID=$(vboxmanage showmediuminfo ./artifacts/vbox/infloent-fb-image-vbox-0.2.0.wic.vmdk | grep 'UUID:' | head -n 1 | cut  -d ':' -f 2 | tr -d ' ')
echo "Setting UUID TO: $PARENT_UUID"
vboxmanage internalcommands sethduuid $VMDK_FILE $PARENT_UUID

# vboxmanage showmediuminfo "$VMDK_FILE" &> /dev/null
# # if there is no error code, it means that the medium with given file (UUID)
# # was not registered before and we are safe to continue
# if [ $? -ne 0 ]; then
#   # if there is error code, it means that VMDK with given UUID was probably
#   # already registered and we should try to unregister it
#   # retreive it's UUID first
#   DISK_UUID="$(vboxmanage internalcommands dumphdinfo $VMDK_FILE | grep uuidCreation | cut -d ' ' -f 2 | cut -d '=' -f 2 | tr -d '{}')"
#   echo "Disk with $VMDK_FILE file (UUID: $DISK_UUID) was already registered, trying to close it..."
#   # try to unregister the disk with given UUID
#   vboxmanage closemedium disk "$DISK_UUID"
#   errorCheck "Failed to close the disk with $VMDK_FILE (UUID: $DISK_UUID)"
#   echo "Disk with $VMDK_FILE was closed"
# fi

echo "Registering $VM_NAME..."
vboxmanage createvm --name "$VM_NAME" --register
errorCheck "vboxmanage createvm failed"

echo "Configuring $VM_NAME..."
vboxmanage modifyvm "$VM_NAME" \
  --cpus 2 \
  --memory 2048 \
  --vram 128 \
  --graphicscontroller vmsvga \
  --accelerate3d on \
  --acpi on \
  --ioapic on \
  --boot1 floppy \
  --nic1 bridged \
  --mouse usbtablet \
  --rtcuseutc on \
  --ostype Linux_64 \
  --audio pulse \
  --usb on \
  --firmware efi \
  --nic1 bridged \
  --nictype1 82540EM \
  --bridgeadapter1 $BRIDGED_IFACE \
  --cableconnected1 on \
  --uart1 0x3F8 4 \
  --uartmode1 server /tmp/vbox
errorCheck "vboxmanage modifyvm failed"

echo "Adding storage controller..."
vboxmanage storagectl "$VM_NAME" \
  --name "SATA Controller" \
  --add sata \
  --portcount 2
errorCheck "vboxmanage storagectl failed"

echo "Attaching $VMDK_FILE to storage controller..."
vboxmanage storageattach "$VM_NAME" \
  --storagectl "SATA Controller" \
  --port 0 \
  --device 0 \
  --type hdd \
  --medium $VMDK_FILE
errorCheck "vboxmanage storageattach failed"

vboxmanage setextradata $VM_NAME VBoxInternal2/EfiGopMode 4
errorCheck "vboxmanage setextradata EfiGopMode 4 failed"

rm -f $VM_NAME.ova
echo "Exporting to $VM_NAME.ova..."
vboxmanage export "$VM_NAME" --output $VM_NAME.ova --options nomacs
errorCheck "vboxmanage export failed"
