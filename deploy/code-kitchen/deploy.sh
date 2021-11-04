#!/bin/bash

# Config file for this deployment
if [ -f "$1" ]; then
    echo "Using config file $1"
else 
    echo "No config specified, please run as './deploy/code-kitchen/deploy.sh path-to-config'"
    exit
fi
config_file="$1"


# Value files used for the deployment
jhValuesSource="./deploy/code-kitchen/jh-values.yaml"
jhValuesTarget="./deploy/code-kitchen/jh-values-amended.yaml"
npSource="./deploy/code-kitchen/network-policy.yaml"


# Deployment variables
namespace=`yq e '.cluster.namespace' ${config_file}`
url=`yq e '.cluster.url' ${config_file}`


# Make sure we're deploying to the correct cluster
kubectl config use-context lke41595-ctx


# Create a file we can edit without touching the original
cp ${jhValuesSource} ${jhValuesTarget}


# Set the image source
hubImageRepo="ghcr.io/foodyfood/code-kitchen-hub"
coderImageRepo="ghcr.io/foodyfood/code-kitchen-coder"


# Set the hub image we will use
imageTag=$(yq e ".hub.imageTag" ${config_file})
echo "Image used for the hub $hubImageRepo:$imageTag"
yq -i e ".hub.image.name = \"$hubImageRepo\"" ${jhValuesTarget}
yq -i e ".hub.image.tag = \"$(yq e ".hub.imageTag" ${config_file})\"" ${jhValuesTarget}
printf "Hub updated in config\n\n"


# Count the number of profiles wanted (images available in the deployment)
number_of_profiles=$(yq eval '.profile | length' ${config_file})
printf "\nTotal profiles found $number_of_profiles\n\n"


# The default profile (the one that's selected when you hit 'start server')
imageTag=$(yq e ".profile[0].imageTag" ${config_file})
printf "Image used for default profile $coderImageRepo:$imageTag\n\n"
yq -i e ".singleuser.image.name = \"$coderImageRepo\"" ${jhValuesTarget}
yq -i e ".singleuser.image.tag = \"$imageTag\"" ${jhValuesTarget}
name=$(yq e ".profile[0].name" ${config_file})
description=$(yq e ".profile[0].description" ${config_file})
yq -i e ".singleuser.profileList += [ { \"display_name\": \"$name\", \"description\": \"$description\", \"default\": true }]" ${jhValuesTarget}


# Make entries for the profiles
number_of_profiles=$(($number_of_profiles-1)) # -1 since default one was first in list
for i in $(seq 1 $number_of_profiles); do
    echo "Profile $(($i))"
    imageTag=$(yq e ".profile[$(($i))].imageTag" ${config_file})
    name=$(yq e ".profile[$(($i))].name" ${config_file})
    description=$(yq e ".profile[$(($i))].description" ${config_file})
    
    echo "Name $name"
    echo "Description $description"
    echo "Image $coderImageRepo:$imageTag"
    yq -i e ".singleuser.profileList += [ { \"display_name\": \"$name\", \"description\": \"$description\", \"kubespawner_override\": {\"image\": \"$coderImageRepo:$imageTag\"} }]" ${jhValuesTarget}
    echo "Added to profile list"
    echo ""
done


# Set the URL of the deployment
printf "Setting URL\n\n"
url=$(yq e ".cluster.url" ${config_file})
yq -i e ".ingress.hosts = [\"$url\"]" ${jhValuesTarget}
yq -i e ".ingress.tls[0].hosts = [\"$url\"]" ${jhValuesTarget}
yq -i e ".hub.config.GenericOAuthenticator.oauth_callback_url = \"https://$url/hub/oauth_callback\"" ${jhValuesTarget}


# Set user scheduling preferences
printf "Setting User Scheduling\n\n"
yq -i e ".scheduling.userScheduler.enabled = $(yq e ".user.scheduler" ${config_file})" ${jhValuesTarget}
yq -i e ".scheduling.userPlaceholder.enabled = $(yq e ".user.placeholder" ${config_file})" ${jhValuesTarget}


# Set admins
printf "Setting admins:\n"
yq -i e ".hub.config.Authenticator.admin_users = []" ${jhValuesTarget}
number_of_admins=$(yq eval '.admins | length' ${config_file})
for i in $(seq 1 $number_of_admins); do
    adminToCopy=$(yq e ".admins.[$(($i-1))] " ${config_file})
    echo $adminToCopy
    yq -i e ".hub.config.Authenticator.admin_users += [\"$adminToCopy\"]" ${jhValuesTarget}
done
printf "\n\n"

# Set random secret token
printf "Setting secret token\n\n"
yq -i e ".proxy.secretToken = \"$(openssl rand -hex 32)\"" ${jhValuesTarget}


# Add the needed helm repos for the deployment
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update


# What base jupyterhub chart version are we overriding with our values file
jhChartVersion=`yq e '.jhChartVersion' ${config_file}`


# Deploy Code Kitchen using our ammended values file, upgrade if already deployed
helm upgrade --cleanup-on-fail --install code-kitchen jupyterhub/jupyterhub -n ${namespace} --create-namespace --values ${jhValuesTarget} --version "${jhChartVersion}"
rm ${jhValuesTarget}

# Put a network policy in the namespace that only allows traffic from nginx {soon to be ALB}
kubectl apply -f ${npSource} --namespace=${namespace}
