#!/bin/bash
BUILD_TAG=${BUILD_TAG:-latest}
IMAGE="arkb2023/abode-website:${BUILD_TAG}"

docker run --rm $IMAGE sh -c "
  ls -la /var/www/html/ &&
  test -f /var/www/html/index.html
"
echo "Tests passed"