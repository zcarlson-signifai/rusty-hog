#!/bin/bash

SUCCESSFUL_LAMBDA_BUILD=0
[ -z "${RUSTYHOG_VERSION}" ] && RUSTYHOG_VERSION="1.0.11"

cargo build --release
if [ $? -ne 0 ]; then
  echo "cargo build returned non-zero exit code"
  exit 1
fi

if [[ "$(uname)" == "Darwin" ]]; then
    if ./build_lambda_macos.sh; then
        SUCCESSFUL_LAMBDA_BUILD=1
    fi
elif [[ "$(uname)" == "Linux" ]]; then
    if ./build_lambda.sh; then
        SUCCESSFUL_LAMBDA_BUILD=1
    fi
else
    echo "Only macOS and Linux currently supported for Lambda build"
fi

# Start rolling releases
pwd
mkdir darwin_releases
[ "${SUCCESSFUL_LAMBDA_BUILD}" -gt 0 ] && mkdir musl_releases
cp target/release/*_hog darwin_releases
[ "${SUCCESSFUL_LAMBDA_BUILD}" -gt 0 ] && cp target/x86_64-unknown-linux-musl/release/*_hog musl_releases
mv scripts/.idea ../

# Darwin
strip darwin_releases/*
for f in darwin_releases/*; do
    ft=$(echo $f | awk -F/ '{print $2}');
    zip -r "rustyhogs-darwin-${ft}-${RUSTYHOG_VERSION}.zip" $f;
done

# x86_64 musl
if [ "${SUCCESSFUL_LAMBDA_BUILD}" -gt 0 ]; then
    if x86_64-linux-musl-strip musl_releases/*; then
        for f in musl_releases/*; do
            ft=$(echo $f | awk -F/ '{print $2}');
            zip -r "rustyhogs-musl-${ft}-${RUSTYHOG_VERSION}.zip" $f;
        done
    else
        if [ "$(uname)" == "Darwin" -a ! -z "$(which brew)" ]; then
            echo "You may want to run \`brew install FiloSottile/musl-cross/musl-cross\`";
            echo "(and possibly reload your shell)";
            exit 1;
        else
            echo "You may want to set up cross-compilation for musl on x86_64 linux";
        fi
        exit 1
    fi
fi

# misc
zip -r rustyhogs-lambda_$1.zip berkshire_lambda.zip
zip -r rustyhogs-scripts_$1.zip scripts
rm -rf darwin_releases musl_releases
mv ../.idea scripts
echo "Output build in release.zip"
[ "${SUCCESSFUL_LAMBDA_BUILD}" -eq 0 ] && echo "(Note that this DOES NOT include the Lambda build because it was unsuccessful)"

