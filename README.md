Extender Installer
=================

This package will automatically install the latest version of Cydia Extender onto the user's device during installation, and also provides a number of modifications, such as:

- Automatic re-signing of locally provisioned applications.
- Caching of the user's Apple ID login details (Note: sensitive information is stored in the Keychain)
- Basic settings to configure alerts shown by the automatic re-signing.

As per usual for my projects, ```iOSOpenDev``` will be required for compilation.  
That said, the maintainer scripts are all ```theos``` projects, and so providing a makefile for the Extender-Extensions and Extender-Installer directories should
suffice.

License
=======

Licensed under the BSD 2-Clause License.

If you distribute this package on a repository, be aware that I will not provide any support whatsoever for users of it on said repository.  