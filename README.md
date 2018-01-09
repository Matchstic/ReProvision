### ReProvision

This project provides automatic re-provisioning of iOS and tvOS applications to avoid the 7-day expiration associated with free certificates, along with a macOS application to manually provision a given <code>.ipa</code> file.

#### Features

Provisioning is undertaken via the user's Apple ID credentials, and supports both paid and free development accounts. These credentials are stored in the user's Keychain for subsequent re-use, and are only sent to Apple's iTunes Connect API for authentication.

##### iOS, and tvOS

- Automatic re-signing of locally provisioned applications.
- Basic settings to configure alerts shown by the automatic re-signing.
- Ability to install any <code>.ipa</code> file downloaded through Safari from the device.

##### macOS

- Ability to write a newly provisioned <code>.ipa</code> file to the filesystem, or install directly to the user's device

#### Pre-Requisites

None.

#### Third-Party Libraries

This project uses the following third-party libraries:
- ldid -> https://git.saurik.com/ldid.git
- libplist -> https://github.com/libimobiledevice/libplist
- SAMKeychain -> https://github.com/soffes/SAMKeychain
- SSZipArchive (modified slightly) -> https://github.com/ZipArchive/ZipArchive

#### License

Licensed under the GPLv3 License.

If you re-distribute this package on a Cydia repository, be aware that I will not provide any support whatsoever for users of it on said repository.