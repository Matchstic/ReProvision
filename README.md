Extender Installer
=================

This package will automatically install the latest version of [Cydia Extender](http://www.idownloadblog.com/2017/03/11/cydia-impactor-update-extender-release/) onto the user's device during installation, and also provides a number of modifications, such as:

- Automatic re-signing of locally provisioned applications.
- Installation of locally provisioned applications without the use of saurik's VPN.
- Caching of the user's Apple ID login details (Note: sensitive information is stored in the Keychain)
- Basic settings to configure alerts shown by the automatic re-signing.  

Note that there is no need for a paid iOS Developer certificate to use this, a free one will suffice.

As per usual for my projects, ```iOSOpenDev``` will be required for compilation.  
That said, the maintainer scripts are all ```theos``` projects, and so providing a makefile for the Extender-Extensions and Extender-Installer directories should
suffice.

Pre-requisites
=============

This package depends upon:
- ```ldid```
- uikittools for ```uicache```

License
=======

Licensed under the BSD 2-Clause License.

If you distribute this package on a repository, be aware that I will not provide any support whatsoever for users of it on said repository.  

Other Notes
==========

I'm aware that there is another implementation of this idea from @julioverne. Please note that inspiration was used from him, though this is all original code.
