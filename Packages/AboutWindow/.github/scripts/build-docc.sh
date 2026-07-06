#!/bin/bash

export LC_CTYPE=en_US.UTF-8

set -o pipefail && xcodebuild clean docbuild -scheme AboutWindow \
    -destination generic/platform=macos \
    -skipPackagePluginValidation \
    OTHER_DOCC_FLAGS="--transform-for-static-hosting --hosting-base-path WelcomeWindow --output-path ./docs" | xcpretty
