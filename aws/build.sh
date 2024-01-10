#!/bin/bash
echo "Logging in to Amazon ECR"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

echo "Starting build at `date`"

echo "Building Docker image"
docker build -t $APP_NAME:$TAG .
docker tag $APP_NAME:$TAG $ECR_URL/$APP_NAME:$TAG

echo "Build completed at `date`"

echo "Pushing Docker image to ECR"
docker push $ECR_URL/$APP_NAME:$TAG