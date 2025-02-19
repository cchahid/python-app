# Used by `image`, `push` & `deploy` targets, override as required
IMAGE_REG ?= docker.io
IMAGE_REPO ?= cchahi/my-python-app
IMAGE_TAG ?= latest

# Used by `deploy` target, sets Kubernetes defaults, override as required
K8S_CLUSTER ?= minikube
K8S_DEPLOYMENT_FILE ?= k8s/python-demoapp-deployment.yaml
K8S_SERVICE_FILE ?= k8s/python-demoapp-service.yaml

# Used by `test-api` target
TEST_HOST ?= localhost:5000

# Don't change
SRC_DIR := src

.PHONY: help lint lint-fix image push run deploy undeploy clean test-api .EXPORT_ALL_VARIABLES
.DEFAULT_GOAL := help

help:  ## 💬 This help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*? ## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

lint: venv  ## 🔎 Lint & format, will not fix but sets exit code on error 
	. $(SRC_DIR)/.venv/bin/activate \
	&& black --check $(SRC_DIR) \
	&& flake8 src/app/ && flake8 src/run.py

lint-fix: venv  ## 📜 Lint & format, will try to fix errors and modify code
	. $(SRC_DIR)/.venv/bin/activate \
	&& black $(SRC_DIR)

image:  ## 🔨 Build container image from Dockerfile 
	docker build . --file build/Dockerfile \
	--tag $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

push:  ## 📤 Push container image to registry 
	docker push $(IMAGE_REG)/$(IMAGE_REPO):$(IMAGE_TAG)

run: venv  ## 🏃 Run the server locally using Python & Flask
	. $(SRC_DIR)/.venv/bin/activate \
	&& python src/run.py

deploy:  ## 🚀 Deploy to Kubernetes (Minikube) 
	# Set the Kubernetes context to Minikube
	@echo "### Setting Kubernetes context to Minikube"
	@kubectl config use-context $(K8S_CLUSTER)

	# Deploy the app using the Kubernetes manifest files
	@echo "### Deploying to Kubernetes"
	@kubectl apply -f $(K8S_DEPLOYMENT_FILE)
	@kubectl apply -f $(K8S_SERVICE_FILE)

	@echo "### 🚀 Web app deployed. Verify deployment using kubectl get pods and kubectl get svc"

undeploy:  ## 💀 Remove from Kubernetes (Minikube) 
	@echo "### WARNING! Going to delete the app from the Kubernetes cluster 😲"
	@kubectl delete -f $(K8S_DEPLOYMENT_FILE)
	@kubectl delete -f $(K8S_SERVICE_FILE)

test: venv  ## 🎯 Unit tests for Flask app
	. $(SRC_DIR)/.venv/bin/activate \
	&& pytest -v

test-report: venv  ## 🎯 Unit tests for Flask app (with report output)
	. $(SRC_DIR)/.venv/bin/activate \
	&& pytest -v --junitxml=test-results.xml

test-api: .EXPORT_ALL_VARIABLES  ## 🚦 Run integration API tests, server must be running 
	cd tests \
	&& npm install newman \
	&& ./node_modules/.bin/newman run ./postman_collection.json --env-var apphost=$(TEST_HOST)

clean:  ## 🧹 Clean up project
	rm -rf $(SRC_DIR)/.venv
	rm -rf tests/node_modules
	rm -rf tests/package*
	rm -rf test-results.xml
	rm -rf $(SRC_DIR)/app/__pycache__
	rm -rf $(SRC_DIR)/app/tests/__pycache__
	rm -rf .pytest_cache
	rm -rf $(SRC_DIR)/.pytest_cache

# ============================================================================

venv: $(SRC_DIR)/.venv/touchfile

$(SRC_DIR)/.venv/touchfile: $(SRC_DIR)/requirements.txt
	python3 -m venv $(SRC_DIR)/.venv
	. $(SRC_DIR)/.venv/bin/activate; pip install -Ur $(SRC_DIR)/requirements.txt
	touch $(SRC_DIR)/.venv/touchfile

