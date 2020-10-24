fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios preprocess
```
fastlane ios preprocess
```
Configures Fabric, builds the project file and sets the build number from git.
### ios ci
```
fastlane ios ci
```

### ios test
```
fastlane ios test
```

### ios upload_build
```
fastlane ios upload_build
```
Uploads the previously built binary to TestFlight and tags it
### ios tag_build
```
fastlane ios tag_build
```
Creates and pushes a tag like 'build/1583'
### ios release
```
fastlane ios release
```

### ios snaps
```
fastlane ios snaps
```
Create framed screenshots for a range of devices
### ios dsyms
```
fastlane ios dsyms
```
Download DSYMs from iTunes and upload them to Crashlytics
### ios patch
```
fastlane ios patch
```
Create a commit incrementing the patch number
### ios minor
```
fastlane ios minor
```
Create a commit incrementing the minor version number
### ios major
```
fastlane ios major
```
Create a commit incrementing the major version number

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
