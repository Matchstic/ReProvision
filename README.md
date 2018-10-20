## ReProvision

This project provides automatic re-provisioning of iOS and tvOS applications to avoid the 7-day expiration associated with free certificates, along with a macOS application to manually provision a given `.ipa` file.

### Features

Provisioning is undertaken via the user's Apple ID credentials, and supports both paid and free development accounts. These credentials are stored in the user's Keychain for subsequent re-use, and are only sent to Apple's iTunes Connect API for authentication.

#### iOS

- Automatic re-signing of locally provisioned applications.
- Basic settings to configure alerts shown by the automatic re-signing.
- Ability to install any `.ipa` file downloaded through Safari from the device.
- Support for re-signing Apple Watch applications.
- 3D Touch menu for starting a new re-signing routine directly from the Homescreen.

Battery optimisations are also in place through the usage of a background daemon to handle automatic signing.

Please note that only jailbroken devices are supported at this time. Follow [issues/44](https://github.com/Matchstic/ReProvision/issues/44) for progress regarding stock devices.

#### tvOS [TODO]

- Automatic re-signing of locally provisioned applications.
- Basic settings to configure alerts shown by the automatic re-signing.
- Ability to install any `.ipa` file downloaded to the device.

#### macOS [TODO]

- Ability to write a newly provisioned `.ipa` file to the filesystem, or install directly to the user's device

### Pre-Requisites

~~For compiling the iOS project into a Debian archive, `ldid2` and (currently) `iOSOpenDev`. I plan to integrate these two dependencies into this repository.~~ These are now integrated into this repository under `/bin`.

CocoaPods is also utilised.

### Building

To build this project, make sure to have the above pre-requisites installed.

1. Clone the project; `git clone https://github.com/Matchstic/ReProvision.git`
2. Update CocoaPods, by running `pod install` in the project's root directory.
3. Open `ReProvision.xcworkspace`, and roll from there.

### Third-Party Libraries

**iOS**

A third-party library notice can be found [here](https://raw.githubusercontent.com/Matchstic/ReProvision/master/iOS/HTML/openSourceLicenses.html).

### License

Licensed under the AGPLv3 License.

If you re-distribute this package on a Cydia repository, be aware that I will not provide any support whatsoever for users of it on said repository.

Furthermore, ReProvision (and by extension, libProvision as found in `/Shared/`) IS NOT FOR PIRACY. It is intended to allow users to ensure applications signed with a free development certificate remain signed past the usual 7-day window.
