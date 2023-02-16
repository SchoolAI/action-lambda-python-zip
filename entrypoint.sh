#!/bin/bash

configure_aws_credentials(){
	aws configure set aws_access_key_id "${INPUT_AWS_ACCESS_KEY_ID}"
    aws configure set aws_secret_access_key "${INPUT_AWS_SECRET_ACCESS_KEY}"
    aws configure set default.region "${INPUT_LAMBDA_REGION}"
}

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	cd ${INPUT_TARGET_DIR}
	echo "input target directory"
	echo ${INPUT_TARGET_DIR}
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	echo "input requirements txt"
	echo ${INPUT_REQUIREMENTS_TXT}
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
	echo "lambda function layer arn"
	echo ${INPUT_LAMBDA_LAYER_ARN}
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	echo ${LAYER_VERSION}
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code itself..."
	echo "lambda function name"
	echo ${INPUT_LAMBDA_FUNCTION_NAME}
	zip -r code.zip . -x \*.git\*
	aws lambda update-function-code --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
	echo "waiting for lambda function to be updated"
	aws lambda wait function-updated --function-name "${INPUT_LAMBDA_FUNCTION_NAME}"
}

update_function_layers(){
	echo "Using the layer in the function..."
	echo "lambda function name"
	echo ${INPUT_LAMBDA_FUNCTION_NAME}
	echo "lambda layer version:"
	echo ${LAYER_VERSION}
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
    configure_aws_credentials
	install_zip_dependencies
	publish_dependencies_as_layer
	publish_function_code
	update_function_layers
}

deploy_lambda_function
echo "Each step completed, check the logs if any error occured."
