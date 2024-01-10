#!/bin/bash
echo "Update task definition for ECS"
aws iam get-role --role-name ecsTaskExecutionRole | \
    jq ".executionRoleArn=`jq ".Role.Arn"` | .containerDefinitions[0].image = \"$ECR_URL/$APP_NAME:$TAG\" | .logConfiguration.options.\"awslogs-region\" = \"$REGION\"" aws/taskdef.json \
    > taskdef_$TAG.json

echo "Register ECS task definition"
aws ecs register-task-definition --cli-input-json file://taskdef_$TAG.json

echo "Update ECS service"
if [[ "${DESIRED_COUNT}" == "" ]]
then
    aws ecs update-service --cluster $CLUSTER --service $SERVICE \
        --task-definition colour-in-backend:$(aws ecs describe-task-definition --task-definition colour-in-backend | jq ".taskDefinition.revision")
else
    aws ecs update-service --cluster $CLUSTER --service $SERVICE \
        --task-definition colour-in-backend:$(aws ecs describe-task-definition --task-definition colour-in-backend | jq ".taskDefinition.revision") --desired-count $DESIRED_COUNT
fi