##############################################################################################################################
#
#
#
##############################################################################################################################

# See also https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/naming-and-tagging

az --version
az account list 
az account show 
# /!\ In CloudShell, the default subscription is not always the one you thought ...
subName="set here the name of your subscription"
subName=$(az account list --query "[?name=='${subName}'].{name:name}"  --output tsv)
echo "subscription Name :" $subName 
subId=$(az account list --query "[?name=='${subName}'].{id:id}"  --output tsv)
echo "subscription ID :" $subId

az account set --subscription $subId
az account show 

# az account list-locations ==> choose among francecentral | northeurope | westeurope
location=westeurope 
echo "location is : " $location 

appName="lhparis" 
echo "appName is : " $appName 

dnz_zone="akshandsonlabs.com" # azurewebsites.net 
echo "DNS Zone is : " $dnz_zone

custom_dns="issyaksgbb.net"

# Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
storage_name="stwe""${appName,,}"
echo "Storage name:" $storage_name

# original sources at https://github.com/spring-projects/spring-petclinic.git then forked to https://github.com/spring-petclinic
# option: forks project on your GitHub account
# https://spring-petclinic.github.io/docs/forks.html
git_url="https://github.com/spring-projects/spring-petclinic.git"
echo "Project git repo URL : " $git_url 

version=$(az aks get-versions -l $location --query 'orchestrators[-1].orchestratorVersion' -o tsv) 
echo "version is :" $version 

network_plugin="azure"
echo "Network Plugin is : " $network_plugin 

network_policy="azure"
echo "Network Policy is : " $network_policy 

rg_name="rg-${appName}-${location}" 
echo "RG name:" $rg_name 

target_namespace="staging"
echo "Target namespace:" $target_namespace

cluster_name="aks-${appName}-dr-2d2" #aks-<App Name>-<Environment>-<###>
echo "Cluster name:" $cluster_name

# --nodepool-name can contain at most 12 characters. must conform to the following pattern: '^[a-z][a-z0-9]{0,11}$'.
node_pool_name="devnodepool"
echo "Node Pool name:" $node_pool_name

vnet_name="vnet-${appName}"
echo "VNet Name :" $vnet_name

subnet_name="snet-${appName}"
echo "Subnet Name :" $subnet_name

vault_name="vault-${appName}"
echo "Vault name :" $vault_name

vault_secret="NoSugarNoStar" 
echo "Vault secret:" $vault_secret 

analytics_workspace_name="${appName}AnalyticsWorkspace"
echo "Analytics Workspace Name :" $analytics_workspace_name

acr_registry_name="acr${appName,,}"
echo "ACR registry Name :" $acr_registry_name

##############################################################################################################################
#
# Create/Reuse service Principal
#
##############################################################################################################################

#sp_password=$(az ad sp create-for-rbac --name $appName --role contributor --query password --output tsv)  #  --keyvault $vault_name --create-cert --cert "${appName}-Certificate"
#echo $sp_password > spp.txt
echo "Service Principal Password saved to ./spp.txt. IMPORTANT Keep your password ..." 
# sp_password=`cat spp.txt`
sp_id=$(az ad sp list --show-mine --query "[?appDisplayName=='${appName}'].{appId:appId}" --output tsv)
echo "Service Principal ID:" $sp_id 
az ad sp show --id $sp_id

# Get the id of the service principal configured for AKS
CLIENT_ID=$(az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)
echo "CLIENT_ID:" $CLIENT_ID 

##############################################################################################################################
#
# Create RG & Networks
#
##############################################################################################################################
az group create --name $rg_name-$location --location $location
# https://docs.microsoft.com/en-us/cli/azure/storage/account?view=azure-cli-latest#az-storage-account-create
# https://docs.microsoft.com/en-us/azure/storage/common/storage-introduction#types-of-storage-accounts
az storage account create --name $storage_name --kind StorageV2 --sku Standard_LRS --resource-group $rg_name  --location $location --https-only true

az network vnet create --name $vnet_name --resource-group $rg_name --address-prefixes 172.16.0.0/16 --location $location
az network vnet subnet create --name $subnet_name --address-prefixes 172.16.1.0/24 --vnet-name $vnet_name --resource-group $rg_name 

vnet_id=$(az network vnet show --resource-group $rg_name --name  $vnet_name --query id -o tsv)
subnet_id=$(az network vnet subnet show --resource-group $rg_name --vnet-name  $vnet_name  --name $subnet_name --query id -o tsv)
echo "VNet Id :" $vnet_id	
echo "Subnet Id :" $subnet_id	

# https://docs.microsoft.com/en-us/cli/azure/network/route-table?view=azure-cli-latest#az-network-route-table-create
az network route-table list
route_table="rtb-${appName}"
az network route-table create -g  $rg_name -n $route_table


# https://docs.microsoft.com/en-us/cli/azure/network/route-table/route?view=azure-cli-latest#az-network-route-table-route-create
route="rte${appName}"
az network route-table route create -g  $rg_name --route-table-name $route_table -n $route \
    --next-hop-type VirtualAppliance --address-prefix 172.16.1.0/24 --next-hop-ip-address 172.16.2.0


# Install the aks-preview extension
az extension add --name aks-preview
# Update the extension to make sure you have the latest version installed
az extension update --name aks-preview
az feature register --name AvailabilityZonePreview --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AvailabilityZonePreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

##############################################################################################################################
#
# Create Cluster. For Basic/Advcanced networking options, see https://docs.microsoft.com/en-us/azure/aks/configure-kubenet
# https://docs.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-advanced-networking
##############################################################################################################################
az aks create --name $cluster_name \
    --resource-group $rg_name \
    --service-principal $sp_id \
    --client-secret $sp_password \
    --zones 1 2 3 \
    --vnet-subnet-id $subnet_id \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --location $location \
    --kubernetes-version $version \
    --node-count 3 \
    --generate-ssh-keys \
    --network-plugin $network_plugin \
    --network-policy $network_policy \
    --nodepool-name  $node_pool_name \
    --verbose \
    --load-balancer-sku standard \
    --vm-set-type VirtualMachineScaleSets

az aks get-credentials --resource-group $rg_name  --name $cluster_name

# https://kubernetes.io/docs/reference/kubectl/cheatsheet/#kubectl-autocomplete
source <(kubectl completion bash) # setup autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
alias k=kubectl
complete -F __start_kubectl k

kubectl completion bash
kubectl cluster-info
kubectl config view

# Namespaces
kubectl create namespace development
kubectl label namespace/development purpose=development

kubectl create namespace staging
kubectl label namespace/staging purpose=staging

kubectl create namespace production
kubectl label namespace/production purpose=production

kubectl describe namespace production

# Play
kubectl get nodes

# https://docs.microsoft.com/en-us/azure/aks/availability-zones#verify-node-distribution-across-zones
kubectl describe nodes | grep -e "Name:" -e "failure-domain.beta.kubernetes.io/zone"

kubectl get pods
kubectl top node
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false

kubectl get roles --all-namespaces
kubectl get serviceaccounts --all-namespaces
kubectl get rolebindings --all-namespaces
kubectl get ingresses  --all-namespaces

# Monitor
az aks enable-addons --resource-group $rg_name --name $cluster_name --addons monitoring

# https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
az aks browse --resource-group $rg_name --name $cluster_name

# https://docs.microsoft.com/en-us/azure/azure-monitor/learn/quick-create-workspace-cli
az group deployment create --resource-group $rg_name --name $analytics_workspace_name --template-file deploylaworkspacetemplate.json


##############################################################################################################################
#
# Create Azure Container Registry
#
##############################################################################################################################

# Replications are only supported for managed registries in Premium SKU.
az acr create --resource-group $rg_name --name $acr_registry_name --sku Premium --location $location
az acr replication create --location northeurope --registry $acr_registry_name --resource-group $rg_name


# Get the ACR registry resource id
acr_registry_id=$(az acr show --name $acr_registry_name --resource-group $rg_name --query "id" --output tsv)
echo "ACR registry ID :" $acr_registry_id
az acr repository list  --name $acr_registry_name --resource-group $rg_name

# Configure https://docs.microsoft.com/en-us/azure/container-registry/container-registry-geo-replication#configure-geo-replication
# https://docs.microsoft.com/en-us/cli/azure/acr/replication?view=azure-cli-latest
# location from az account list-locations : francecentral | northeurope | westeurope 
						  
# Create role assignment
az role assignment create --assignee $sp_id --role acrpull --scope $acr_registry_id

docker_server="$(az acr show --name $acr_registry_name --resource-group $rg_name --query "name" --output tsv)"".azurecr.io"
echo "Docker server :" $docker_server

kubectl create secret docker-registry acr-auth \
        --docker-server="$docker_server" \
        --docker-username="$sp_id" \
        --docker-password="$sp_password" \
        --docker-email="youremail@groland.grd"

kubectl get secrets


##############################################################################################################################
#
# Create Docker Image
#
##############################################################################################################################

# https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-pack-build#example-build-java-image-with-heroku-builder
# https://docs.microsoft.com/en-us/azure/container-registry/container-registry-quickstart-task-cli
git clone $git_url
cd spring-petclinic
mvn package

# Test the App
mvn spring-boot:run

# Java 8 image : mcr.microsoft.com/java/jdk:8u222-zulu-alpine
# Java 11 image :  mcr.microsoft.com/java/jre:11u4-zulu-alpine
# JAVA_HOME: /usr/lib/jvm/zulu-11-azure-jre_11.33.15-11.0.4-linux_musl_x64'
#artifact="spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"
artifact="spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"
echo -e "FROM mcr.microsoft.com/java/jre:11u4-zulu-alpine\n" \
"VOLUME /tmp \n" \
"ADD target/${artifact} app.jar \n" \
"RUN touch /app.jar \n" \
"EXPOSE 8080 \n" \
"ENTRYPOINT [ \""java\"", \""-Djava.security.egd=file:/dev/./urandom\"", \""-jar\"", \""/app.jar\"" ] \n"\
> Dockerfile

az acr build -t "${docker_server}/spring-petclinic:{{.Run.ID}}" -r  $acr_registry_name --file Dockerfile .
az acr repository list  --name $acr_registry_name --resource-group $rg_name

# Test container
# az acr run -r $acr_registry_name --cmd "${docker_server}/spring-petclinic:dd4" /dev/null
# https://docs.microsoft.com/en-us/azure/container-registry/container-registry-helm-repos

kubectl apply -f petclinic-deployment.yaml --namespace $target_namespace
kubectl get deployments -n $target_namespace
kubectl get deployment petclinic -n $target_namespace
kubectl get pods -l app=petclinic -o wide -n $target_namespace
kubectl get pods -l app=petclinic -o yaml -n $target_namespace | grep podIP 

# kubectl describe pod petclinic-649bdc4d5-964vl
# kubectl logs petclinic-649bdc4d5-964vl
# kubectl -n $target_namespace exec -ti POD-UID -- /bin/bash
#  kubectl -n $target_namespace exec -ti petclinic-65dfbc9fd7-v7pgj -- ls '/usr/lib/jvm/zulu-11-azure-jre_11.33.15-11.0.4-linux_musl_x64'

##############################################################################################################################
#
# Declare service as ClusterIP, NOT exposed as a SLB/pubic IP to then play with Ingress
#
##############################################################################################################################

kubectl apply -f petclinic-service-cluster-ip.yaml -n $target_namespace

helm repo update
kubectl apply -f helm-rbac.yaml
helm init --service-account tiller

helm upgrade --install ingress stable/nginx-ingress --namespace ingress
service_ip=$(kubectl get svc -n ingress ingress-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[*].ip}")
echo "Your service is now exposed through Ingress Controller at http://${service_ip}"

kubectl apply -f petclinic-ingress.yaml -n $target_namespace
kubectl apply -f petclinic-ingress-drp.yaml -n $target_namespace
kubectl apply -f petclinic-ingress-tm.yaml -n $target_namespace

kubectl get ingresses --all-namespaces
kubectl get ingress -n $target_namespace

##############################################################################################################################
#
# Configure Automatic failover with Traffic Manager
# https://docs.microsoft.com/en-us/azure/aks/operator-best-practices-multi-region#use-azure-traffic-manager-to-route-traffic
# https://docs.microsoft.com/en-us/azure/networking/disaster-recovery-dns-traffic-manager#automatic-failover-using-azure-traffic-manager
# https://docs.microsoft.com/en-us/cli/azure/network/traffic-manager?view=azure-cli-latest
# 
# lighthouseparis.trafficmanager.net
#
##############################################################################################################################
az network traffic-manager profile create -g $rg_name -n ${appName}-TmProfile --routing-method Priority \
    --unique-dns-name lighthouseparis --ttl 30 --protocol HTTP --port 80 --path "/"

az network traffic-manager endpoint create -g $rg_name --profile-name ${appName}-TmProfile \
    -n LightHouseMainEndpoint --target lighthouseparis.akshandsonlabs.com --priority 1 --type externalEndpoints --endpoint-status enabled

az network traffic-manager endpoint create -g $rg_name --profile-name ${appName}-TmProfile \
    -n LightHouseDrEndpoint --target drp.akshandsonlabs.com --priority 2 --type externalEndpoints --endpoint-status enabled


##############################################################################################################################
#
# Enforce TLS with Ingress : https://docs.microsoft.com/en-us/azure/aks/ingress-tls
# https://github.com/helm/charts/blob/master/stable/nginx-ingress/README.md
# 
##############################################################################################################################

echo "Check Live Probe with Spring Actuator : http://${service_ip}/manage/health"
curl "http://${service_ip}/manage/health" -i -X GET
echo "\n"
# You should received an UP reply :
# {
#  "status" : "UP"
# }
echo "Checkc spring Management Info at http://${service_ip}/manage/info" -i -X GET
curl "http://${service_ip}/manage/info" -i -X GET


##############################################################################################################################
#
# Create Key Vault
# 
##############################################################################################################################

# https://docs.microsoft.com/en-us/cli/azure/keyvault/secret?view=azure-cli-latest#az-keyvault-secret-set
az keyvault create --location $location --name $vault_name --resource-group $rg_name
az keyvault secret set --name  "${appName}-Secret" --vault-name $vault_name --description "${appName}-Secret" --value $vault_secret 
az keyvault secret list --vault-name $vault_name
az keyvault secret show --vault-name $vault_name --name "${appName}-Secret"  --output tsv

##############################################################################################################################
#
# Configure DNS
# https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/azure.md
# https://docs.microsoft.com/en-us/azure/aks/http-application-routing
# https://docs.microsoft.com/en-us/azure/dns/
# https://azure.microsoft.com/en-us/resources/videos/custom-dns-records-with-azure-web-sites/
#
# https://docs.microsoft.com/en-us/azure/dns/dns-domain-delegation
# https://docs.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns 
# 
##############################################################################################################################

# http://drp.akshandsonlabs.com/
az network dns zone create -g $rg_name -n $dnz_zone
az network dns zone list -g $rg_name
az network dns record-set a add-record -g $rg_name -z $dnz_zone -n drp -a ${service_ip}
az network dns record-set list -g $rg_name


# To test DNS name resolution:
az network dns record-set ns show --resource-group $rg_name --zone-name $dnz_zone --name drp

# https://docs.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns#delegate-the-domain
# In the registrar's DNS management page, edit the NS records and replace the NS records with the Azure DNS name servers.

# /!\ On your windows station , flush DNS ... : ipconfig /flushdns
# Mac: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder; say cache flushed
nslookup drp.$dnz_zone ns1-08.azure-dns.com

# https://aka.ms/lighthouse/blue mapped to http://lighthouseparis.akshandsonlabs.com
# https://aka.ms/lighthouse/green to be mapped to the SLB Public IP of DRP region


tenant_id=$(az account show --query "tenantId")
# sp_password=`cat spp.txt`
# touch /etc/kubernetes/azure.json
touch azure.json
echo -e "{
  \"tenantId\": \"${tenant_id}\",
  \"subscriptionId\": \"${subId}\",
  \"resourceGroup\": \"${rg_name}\",
  \"aadClientId\": \"${sp_id}\",
  \"aadClientSecret\": \"${sp_password}\"
}" > azure.json

kubectl create secret generic "${appName}-dns-secret" --from-file=azure.json
kubectl get secrets

rg_id=$(az group show --name ${rg_name} --query id --output tsv)
dns_zone_id=$(az network dns zone show --name ${dnz_zone} -g ${rg_name} --query id --output tsv)
az role assignment create --role "Reader" --assignee ${sp_id} --scope ${rg_id} 
az role assignment create --role "Contributor" --assignee ${sp_id} --scope ${dns_zone_id} 


##############################################################################################################################
#
# Configure secrets
# https://docs.microsoft.com/en-us/azure/aks/developer-best-practices-pod-security#use-pod-managed-identities
# 
##############################################################################################################################



##############################################################################################################################
#
# Buy a custom domain with Azure: https://docs.microsoft.com/en-us/azure/app-service/manage-custom-dns-buy-domain
# 
# App Service Domains use GoDaddy for domain registration and Azure DNS to host the domains. 
# In addition to the domain registration fee, usage charges for Azure DNS apply. For information, see Azure DNS Pricing.
# The following top-level domains are supported by App Service domains: com, net, co.uk, org, nl, in, biz, org.uk, and co.in.
#
##############################################################################################################################
 
# Prerequisites: Create an App Service app
# To use custom domains in Azure App Service, your app's App Service plan must be a paid tier (Shared, Basic, Standard, or Premium). 
# https://docs.microsoft.com/en-us/cli/azure/appservice/plan?view=azure-cli-latest#az-appservice-plan-create
# The pricing tiers, e.g., F1(Free), D1(Shared), B1(Basic Small), B2(Basic Medium), B3(Basic Large), S1(Standard Small), P1V2(Premium V2 Small), PC2 (Premium Container Small), PC3 (Premium Container Medium), PC4 (Premium Container Large).

az appservice plan create -g ${rg_name} -n "gbbPlan" --number-of-workers 1 --sku B1 --subscription $subId
az appservice plan show --name "gbbPlan" --resource-group ${rg_name}
# $custom-dns

##############################################################################################################################
#
# Add Appplication Gateway.
# https://docs.microsoft.com/en-us/azure/application-gateway/create-ssl-portal
# https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-certs-create --> outdated !
# https://docs.microsoft.com/en-us/azure/application-gateway/certificates-for-backend-authentication
# 
##############################################################################################################################



##############################################################################################################################
#
# Manage certificates with KeyVault : 
# https://docs.microsoft.com/en-us/azure/key-vault/about-keys-secrets-and-certificates#key-vault-certificates 
# https://docs.microsoft.com/en-us/cli/azure/keyvault/certificate/issuer?view=azure-cli-latest
#
##############################################################################################################################





##############################################################################################################################
#
# Ops Monitoring
#
##############################################################################################################################
# https://docs.microsoft.com/en-us/azure/aks/developer-best-practices-resource-management#regularly-check-for-application-issues-with-kube-advisor
kubectl run --rm -i -t kube-advisor --image=mcr.microsoft.com/aks/kubeadvisor --restart=Never

kubectl run --rm -i -t kube-advisor --image=mcr.microsoft.com/aks/kubeadvisor --restart=Never --overrides="{ \"apiVersion\": \"v1\", \"spec\": { \"serviceAccountName\": \"kube-advisor\" } }"


##############################################################################################################################
#
# Clean-Up
#
##############################################################################################################################

az aks delete --name $cluster_name --resource-group $rg_name
az acr delete --resource-group $rg_name --name $acr_registry_name
az keyvault delete --location $location --name $vault_name --resource-group $rg_name
az network vnet delete --name $vnet_name --resource-group $rg_name --location $location
az network vnet subnet delete --name $subnet_name --vnet-name $vnet_name --resource-group $rg_name 
az network route-table route delete -g  $rg_name --route-table-name $route_table -n $route
az network route-table delete -g  $rg_name -n $route_table
az network dns record-set a delete -g $rg_name -z $dnz_zone -n www 
az network dns zone delete -g $rg_name -n $dnz_zone
az network dns zone list -g $rg_name
# /!\ IMPORTANT : Decide to keep or delete your service principal
# az ad sp delete --id $sp_id