# lighthouse-paris-2019

## Pre-requisites

### Tools

You can use the Azure Cloud Shell accessible at <https://shell.azure.com> once you login with an Azure subscription. The Azure Cloud Shell has the Azure CLI pre-installed and configured to connect to your Azure subscription as well as `kubectl` and `helm`.

### Azure subscription

#### If you have an Azure subscription

Please use your username and password to login to <https://portal.azure.com>.

Also please authenticate your Azure CLI by running the command below on your machine and following the instructions.

```sh
az account show
az login
```

#### Azure Cloud Shell

You can use the Azure Cloud Shell accessible at <https://shell.azure.com> once you login with an Azure subscription.


#### Uploading and editing files in Azure Cloud Shell

- You can use `code <file you want to edit>` in Azure Cloud Shell to open the built-in text editor.
- You can upload files to the Azure Cloud Shell by dragging and dropping them
- You can also do a `curl -o filename.ext https://file-url/filename.ext` to download a file from the internet.

### Naming conventions
See also [See also https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/naming-and-tagging](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/considerations/naming-and-tagging)


## Build AKS Cluster on main region

### Set-up environment variables
### Create Service Principal
### Create RG & Networks
### Create AKS Cluster
### Create Namespaces
### Create Azure Container Registry
### Create Docker Image
### Create Kubernetes deployment
### Create Kubernetes service
### Configure DNS
### Monitoring

## Build AKS Cluster on secondary region

### Set-up environment variables
### Create Service Principal
### Create RG & Networks
### Create AKS Cluster
### Create Namespaces
### Create Azure Container Registry
### Create Docker Image
### Create Kubernetes deployment
### Create Kubernetes clusterIP service and Ingress
### Configure DNS
### Configure Automatic failover with Traffic Manager
### Monitoring

## Clean-Up