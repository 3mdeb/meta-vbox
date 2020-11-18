# meta-vbox

This meta layer allows to create Open Virtualization Appliance (OVA) file to run
virtual system image using
[VirtualBox](https://www.virtualbox.org/wiki/Linux_Downloads). The image is
created for a machine called [vbox](conf/machine/vbox.conf).

## Build required artifacts

To run virtual image by using `meta-vbox` layer, `wic.vmdk` image file need to
be built. This can be achieved by adding the `wic.vmdk` extension to the
variable `IMAGE_FSTYPES` in the Yocto build environment. After building the
image, the `vmdk` file should be inside the `DEPLOYDIR` directory of the given
Yocto project.

## Create OVA file

To create ova file `vm-create.sh` script can be used

```
$ ./scripts/vm-create.sh
Usage:    ./scripts/vm-create.sh <NAME_OF_MACHINE> <PATH_TO_VMDK>
Example:  ./scripts/vm-create.sh vm1 core-image-minimal-qemux86-64.wic.vmdk
```

It takes two arguments, name of virtual machine (e.g. `vm1`) and path to a
`vmdk` file which should be available in `DEPLOYDIR` of the given Yocto project.
Example usage

```
$ ./vm-create.sh vm1 /hdd/projects/custom_proj/build/tmp/deploy/images/vbox/core-image-minimal-vbox.wic.vmdk
Virtual machine 'vm1' is created and registered.
UUID: e11fb4c3-135f-4cc3-8021-8b524f070882
Settings file: '/home/tzyjewski/VirtualBox_VMs/vm1/vm1.vbox'
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
Successfully exported 1 machine(s).
```

That should create `vm1.ova` file. It should be ready to launch from
`VirtualBox` menu. If it is not there, `ova` file can be imported by choosing
`File -> Import Appliance...` in `VirtualBox` window.

Running virtual image from `ova` file creates socket under path `/tmp/vbox`. It
can be used to get serial logs from virtual machine by connecting to it via
`minicom`

```
$ minicom  -o -b 115200 -D unix#/tmp/vbox
```

## Known limitations

* virtual machine can hang while booting, it can be caused by enabling serial
  port via `/tmp/vbox`, to avoid this problem serial port can be disable in `VM`
  options or minicom need to be open on `/tmp/vbox` while `VM` is booting
