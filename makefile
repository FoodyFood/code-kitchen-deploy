#!/bin/bash

# deploy charts
deploy-code-kitchen:
	./deploy/code-kitchen/deploy.sh ./deploy/code-kitchen/prod-env.yaml

deploy-keycloak:
	helm repo add codecentric https://codecentric.github.io/helm-charts
	helm upgrade --cleanup-on-fail --install keycloak codecentric/keycloak -n keycloak --values ./deploy/keycloak/kc-values.yaml --create-namespace
