
# Requirements: awscli v2, hugo, jq (optional)
export BUCKET_NAME="rosahcpworkshop"
export AWS_REGION="ap-southeast-1"  
export HUGO_SRC="$HOME/rosahcpworkshop" # path to your Hugo project root

# To deploy
bash s3-hugo-deploy.sh