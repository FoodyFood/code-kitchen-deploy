#!/bin/bash

# This script wil grab the matching CLI version for an installed keycloak.

#These may be passed as arguments later
context="my-kubernetes-context"
namespace="keycloak"

echo Switching to the supplied context
kubectl config use-context $context

echo Using namespace $namespace

echo Getting deployed keycloak version from cluster
image=$(kubectl get statefulset/keycloak --namespace $namespace -o jsonpath="{..containers..image}")
version=$(cut -d':' -f2 <<< "$image")
echo Deployed version: $version

if [ "$version" ==  "" ]
then
	echo Keycloak not found in namespace $namespace
	exit 1
fi

localVersion=`cat keycloak/local-keycloak-version`
echo Local version: $localVersion

if [ "$localVersion" == "$version" ]
then
	echo Local Keycloak version matches deployed version, exiting
	exit 0
fi


echo Removing incompatable local version
rm -rf keycloak
rm keycloak/local-keycloak-version


echo Downloading keycloak version $version
wget "https://github.com/keycloak/keycloak/releases/download/$version/keycloak-$version.tar.gz"
tar -xzf keycloak-$version.tar.gz
rm keycloak-$version.tar.gz
mv keycloak-$version keycloak


echo $version >> keycloak/local-keycloak-version

echo Downloded keycloak version that matches supplied cluster/namespace