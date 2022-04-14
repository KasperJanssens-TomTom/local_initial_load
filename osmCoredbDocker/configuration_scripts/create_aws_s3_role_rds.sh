#!/bin/bash

BUCKET=$1

#SOURCE BUCKET
# maps-contentops -> maps-camu-prod
#Policy to be attached to output bucket of maps-contentops (once during entire lifetime of bucket)
# run following script on source account - create_aws_s3_role_source.sh

#DESTINATIN BUCKET
# maps-camu-prod
# run as a AWS Administrator
POLICY_NAME=rds-s3-import-${BUCKET}-policy
_out=$(aws iam create-policy \
   --policy-name $POLICY_NAME \
   --policy-document '{ "Version": "2012-10-17", "Statement": [ { "Sid": "s3import", "Action": [ "s3:GetObject", "s3:ListBucket" ], "Effect": "Allow", "Resource": [ "arn:aws:s3:::'"${BUCKET}"'", "arn:aws:s3:::'"${BUCKET}"'/*" ] } ] }')
POLICY_ARN="arn:aws:iam::293913556225:policy/"${POLICY_NAME}
echo "$POLICY_ARN"

ROLE_NAME="rds-s3-import-role"
aws iam get-role --role-name ${ROLE_NAME}
role_exits=$?
if [[ $role_exits != 0 ]]; then
  aws iam create-role \
     --role-name ${ROLE_NAME} \
     --assume-role-policy-document '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Service": "rds.amazonaws.com" }, "Action": "sts:AssumeRole" } ]  }'
else
  echo "role $ROLE_NAME already exists"
fi
ROLE_ARN="arn:aws:iam::293913556225:role/"${ROLE_NAME}

aws iam attach-role-policy \
   --policy-arn ${POLICY_ARN} \
   --role-name ${ROLE_NAME}

if [[ $role_exits != 0 ]]; then
  aws rds add-role-to-db-cluster \
     --db-cluster-identifier my-db-cluster \
     --feature-name s3Import \
     --role-arn ${ROLE_ARN}   \
     --region eu-west-1
fi