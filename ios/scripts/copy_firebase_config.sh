#!/bin/bash
# Copy the correct GoogleService-Info.plist based on the build flavor.
# This script is invoked as a Build Phase in Xcode.

set -e

PLIST_SOURCE=""

if [ "${FLAVOR}" == "dev" ]; then
  PLIST_SOURCE="${PROJECT_DIR}/config/dev/GoogleService-Info.plist"
elif [ "${FLAVOR}" == "staging" ]; then
  PLIST_SOURCE="${PROJECT_DIR}/config/staging/GoogleService-Info.plist"
elif [ "${FLAVOR}" == "prod" ]; then
  PLIST_SOURCE="${PROJECT_DIR}/config/prod/GoogleService-Info.plist"
else
  echo "warning: FLAVOR not set, defaulting to dev"
  PLIST_SOURCE="${PROJECT_DIR}/config/dev/GoogleService-Info.plist"
fi

if [ ! -f "${PLIST_SOURCE}" ]; then
  echo "error: GoogleService-Info.plist not found at ${PLIST_SOURCE}"
  exit 1
fi

PLIST_DESTINATION="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
echo "Copying ${PLIST_SOURCE} to ${PLIST_DESTINATION}"
cp "${PLIST_SOURCE}" "${PLIST_DESTINATION}"
