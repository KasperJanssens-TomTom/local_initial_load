#!/bin/bash

BUCKET=$1

#SOURCE BUCKET
# maps-contentops
aws s3api put-bucket-policy \
    --bucket "${BUCKET}" \
    --policy '{ "Version": "2012-10-17", "Statement": [ { "Sid": "s3import", "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::293913556225:root" }, "Action": [ "s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation" ], "Resource": [ "arn:aws:s3:::'"${BUCKET}"'", "arn:aws:s3:::'"${BUCKET}"'/*"] } ] }'


#DESTINATIN BUCKET
# maps-camu-prod
# run following script on destination account - create_aws_s3_role_rds.sh