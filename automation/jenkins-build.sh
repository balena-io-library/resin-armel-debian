#!/bin/bash

set -o errexit
set -o pipefail

export SUITES='wheezy jessie'
export REPO='resin/armel-debian'
LATEST='jessie'
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
date=$(date +'%Y%m%d' -u)

bash "$dir/build-image.sh"

for suite in $SUITES; do

	docker run --rm $REPO:$suite bash -c 'dpkg-query -l' > $suite

	# Upload to S3 (using AWS CLI)
	printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
	aws s3 cp $suite s3://$BUCKET_NAME/image_info/armel-debian/$suite/
	aws s3 cp $suite s3://$BUCKET_NAME/image_info/armel-debian/$suite/$suite_$date
	rm -f $suite
	
	docker tag -f $REPO:$suite $REPO:$suite-$date
	if [ $LATEST == $suite ]; then
		docker tag -f $REPO:$suite $REPO:latest
	fi
done

docker push $REPO

# Clean up unnecessarry docker images after pushing
if [ $? -eq 0 ]; then
	for suite in $SUITES; do
		docker rmi -f $REPO:$suite
		docker rmi -f $REPO:$suite-$date
	done
fi
