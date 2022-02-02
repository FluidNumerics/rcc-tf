# Research Computing Cloud (RCC) - Terraform Module
Copyright 2021 Fluid Numerics LLC

## About
The Research Computing Cloud (RCC) Terraform Module is infrastructure-as-code that will quickly get you started with a complete HPC/RC cluster on Google Cloud. Features of this deployment include:
* Slurm job scheduler hosted on a controller instance
* Multiple login nodes
* Multi-region, multi-zone compute partitions
* (Optional) Cloud SQL Slurm Database
* (Optional) Lustre file system  (mounts to `/mnt/lustre`)
* (Optional) NFS Filestore file system  (mounts to `/mnt/filestore`)

We recommend that you use this infrastructure as code with Fluid Numerics' RCC VM Image Library image families.


## Images

### Free Images
Fluid Numerics makes some VM images available for free. These images provide a good starting point, but do not grant you access to support from Fluid Numerics.
* [`projects/research-computing-cloud/images/family/rcc-centos-foss`]()
* [`projects/research-computing-cloud/images/family/rcc-debian-foss`]()
* [`projects/research-computing-cloud/images/family/rcc-ubuntu-foss`]()


### Supported Images
If you would like to obtain support from Fluid Numerics for using this solution, you can use the following VM Images :
* [`projects/fluid-cluster-ops/global/images/family/rcc-centos-7-v3`]()
* [`projects/fluid-cluster-ops/global/images/family/rcc-ubuntu-2004-v3`]()
* [`projects/fluid-cluster-ops/global/images/family/rcc-debian-10-v3`]()
* [`projects/fluid-cluster-ops/global/images/family/rcc-rocky-`]()

Use of these images incurs a licensing fee of $0.01 USD/vCPU/hour and $0.09 USD/GPU/hour. If you are interested in obtaining a different usage-based pricing model for support, reach out to support@fluidnumerics.com.

The use of these images are subject to the terms of [Fluid Numerics' RCC EULA]()

## Quick Start

### Deploy your cluster
1. [Navigate to Google Cloud Shell](https://shell.cloud.google.com/?show=terminal)
2. Clone this repository
```
git clone https://github.com/fluidnumerics/rcc-tf ~/rcc-tf
```
3. Set your project ID, replacing `PROJECT-ID` with your Google Cloud project ID
```
gcloud config set project PROJECT-ID
```
4. (Optional) Enable Lustre parallel file system
```
export USE_LUSTRE=true
```
5. (Optional) Enable Filestore
```
export USE_FILESTORE=true
```
6. (Optional) Enable CloudSQL for Slurm database
```
export USE_CLOUDSQL=true
```
7. Create a terraform plan
```
cd ~/rcc-tf/
make plan
```
8. Deploy you're infrastructure when ready
```
make apply
```

### Tear down your cluster
When you're done using your cluster, you can tear down resources to avoid accruing additional costs on Google Cloud.
1. [Navigate to Google Cloud Shell](https://shell.cloud.google.com/?show=terminal)
2. Navigate to the `~/rcc-tf/` directory
```
cd ~/rcc-tf/
```
3. Delete your infrastructure
```
make destroy
```

### Dive Deeper
You can [You can learn more about configuring your cluster at the research-computing-cluster readthedocs](https://research-computing-cluster.readthedocs.io/en/latest/QuickStart/deploy_with_terraform.html).

## Reporting Issues
You can [report any issues associated with the rcc-tf repository using our issue tracker](https://octoskelo.atlassian.net/servicedesk/customer/portal/1/create/150)
