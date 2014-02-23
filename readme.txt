This program will turn a regular file into an NTFS system file, by changing it's MFT reference number to one between 12 and 15, which are reserved by the filesystem. By doing this, the file becomes invisible and protected from modification. By invisible it means, no tool explorer or the dir command will see it. However the filesystem regard it as a systemfile, and will thus prevent writing any file to that location with that name. It is like when you try to create a file named $MFT in the root of the volume, which the filesystem will prevent you from doing. The only way to modify this file is by a hex editor writing to physical disk. Alternatively you could extract the file from volume (datarecovery), modify the extracted file, and then lastly use the tool to inject it back into the same MFT reference number as it was.

What can be hidden with this tool?
Basically any file or folder. However a few restrictions apply:
- Target can not have $ATTRIBUTE_LIST in its MFT record (content span across several MFT records).
- Content in subdirectories, except root dir.
- New MFT reference must be between 12 and 15.

That means the file or folder must be located at the root level of the volume. 

Example that works:
HideAndProtect.exe C:\file.ext 12
HideAndProtect.exe C:\folder 15
HideAndProtect.exe C:W 13

Example that does not work:
HideAndProtect.exe C:\folder\file.ext 14
HideAndProtect.exe C:\file.ext 20
HideAndProtect.exe C:W 23

What can it be used for?
Hide a few files, and protect them from modification. Try it on your boot loader, like bootmgr.
Reserve certain filenames in the root of the volume. For instance autorun.inf on flash sticks.

I have tried this on bootmgr, and Windows booted fine. The point is that when the bootsector is executed there is no NTFS driver or anything present that understand the concept of a file vs folder. It is basically X number of sector loaded into memory, based on a few conditions.

Warning:
Due to the very hacky nature of this application, you must understand that this may corrupt your filesystem, and that I take no responsibility for what this application may cause. Use at own risk! Important to close any open files on the target volume before trying this.

The tool has been tested with success on XP SP2 32-bit and Windows 7 SP1 64-bit. Please be aware of limitations when running on nt6.x.

Limitation
At nt6.x new security measures have been implemented, preventing you from writing directly to sectors inside filesystem. Before doing anything like this, we obtain a lock on the target volume. However, this is not possible to in a few situations (systemdrive, volume where pagefile is on, volume where HideAndProtect is run from, and maybe a ew more). These restrictions do not apply for nt5.x (anything before Vista).

Changelog
v1.0.0.0: First version.
v1.0.0.1: Added help/usage when no parameters are supplied. Added option to wipe/delete any of the 12-15 records. Added more specific output informing about how to use chkdsk when done.
