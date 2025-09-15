### Prerequisites
Requirements: awscli v2, hugo, jq (optional)

### Install Hugo
brew install hugo

### Clone the project
git clone https://github.com/enzobercasio/rosahcpworkshop.git

### Set variables

export BUCKET_NAME="rosahcpworkshop"

export AWS_REGION="ap-southeast-1"  

export HUGO_SRC="$HOME/rosahcpworkshop" 

#### Run to create S3 and deploy static website

bash s3-hugo-deploy.sh