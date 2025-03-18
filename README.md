# To create public folder
hugo

# To serve locally
hugo server

#s3 policy
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::rosahcpworkshop/*"
        }
    ]
}

#to deploy to S3 
aws s3 cp public s3://rosahcpworkshop/ --recursive
