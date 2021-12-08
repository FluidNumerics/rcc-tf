#
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  region = join("-", slice(split("-", var.zone), 0, 2))
}

provider "google" {
  project = var.project
  region  = local.region
}

module "slurm_cluster_network" {
  source = "github.com/FluidNumerics/slurm-gcp//tf/modules/network"

  cluster_name                  = var.cluster_name
  disable_login_public_ips      = var.disable_login_public_ips
  disable_controller_public_ips = var.disable_controller_public_ips
  disable_compute_public_ips    = var.disable_compute_public_ips
  network_name                  = var.network_name
  partitions                    = var.partitions
  shared_vpc_host_project       = var.shared_vpc_host_project
  subnetwork_name               = var.subnetwork_name

  project = var.project
  region  = local.region
}

data "google_compute_subnetwork" "slurm_subnet" {
  name = var.subnetwork_name
  self_link = module.slurm_cluster_network.subnet_depend
  region = local.region
  project = var.project
}

// ***************************************** //
// Create the Cloud SQL instance

resource "google_compute_global_address" "private_ip_address" {
  count = var.cloudsql_slurmdb ? 1 : 0
  provider = google-beta
  name = "private-ip-address"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  prefix_length = 16
  network = data.google_compute_subnetwork.slurm_subnet.network
  project = var.project
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count = var.cloudsql_slurmdb ? 1 : 0
  provider = google-beta
  network = data.google_compute_subnetwork.slurm_subnet.network
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
}

resource "google_sql_database_instance" "slurm_db" {
  count = var.cloudsql_slurmdb ? 1 : 0
  provider = google-beta
  name = var.cloudsql_name
  database_version = "MYSQL_5_6"
  region = local.region
  project = var.project
  depends_on = [google_service_networking_connection.private_vpc_connection[0]]

  settings {
    tier = var.cloudsql_tier
    ip_configuration {
      ipv4_enabled  = var.cloudsql_enable_ipv4
      private_network = data.google_compute_subnetwork.slurm_subnet.network
    }
  }
  deletion_protection = false
}

resource "google_sql_user" "slurm" {
  count = var.cloudsql_slurmdb ? 1 : 0
  name = "slurm"
  instance = google_sql_database_instance.slurm_db[0].name
  password = "changeme"
}

locals {
  cloudsql = var.cloudsql_slurmdb ? {"db_name":google_sql_database_instance.slurm_db[0].name, 
                                     "server_ip":google_sql_database_instance.slurm_db[0].private_ip_address,
                                     "user": "slurm",
                                     "password": "changeme"} : null
}
// ***************************************** //


// Create Lustre File System

module "lustre_gcp" {
  source = "github.com/FluidNumerics/lustre-gcp_terraform"

  create_lustre = var.create_lustre
  image = var.lustre.image
  project = var.lustre.project == null ? var.project : var.lustre.project 
  zone = var.lustre.zone == null ? var.zone : var.lustre.zone 
  vpc_subnet = var.lustre.vpc_subnet == null ? module.slurm_cluster_network.subnet_depend : var.lustre.vpc_subnet 
  service_account = var.lustre.service_account 
  network_tags = var.lustre.network_tags
  cluster_name = var.lustre.name
  fs_name = var.lustre.fs_name
  mds_node_count = var.lustre.mds_node_count
  mds_machine_type = var.lustre.mds_machine_type
  mds_boot_disk_type = var.lustre.mds_boot_disk_type
  mds_boot_disk_size_gb = var.lustre.mds_boot_disk_size_gb
  mdt_disk_type = var.lustre.mdt_disk_type
  mdt_disk_size_gb = var.lustre.mdt_disk_size_gb
  mdt_per_mds = var.lustre.mdt_per_mds
  oss_node_count = var.lustre.oss_node_count
  oss_machine_type = var.lustre.oss_machine_type
  oss_boot_disk_type = var.lustre.oss_boot_disk_type
  oss_boot_disk_size_gb = var.lustre.oss_boot_disk_size_gb
  ost_disk_type = var.lustre.ost_disk_type
  ost_disk_size_gb = var.lustre.ost_disk_size_gb
  ost_per_oss = var.lustre.ost_per_oss
  hsm_node_count = var.lustre.hsm_node_count
  hsm_machine_type = var.lustre.hsm_machine_type
  hsm_gcs_bucket = var.lustre.hsm_gcs_bucket
  hsm_gcs_prefix = var.lustre.hsm_gcs_prefix
}

// ***************************************** //

// Create Filestore File System
resource "google_filestore_instance" "nfs" {
  count = var.create_filestore ? 1 : 0
  name = var.filestore.name
  zone = var.filestore.zone == null ? var.zone : var.filestore.zone
  tier = var.filestore.tier
  file_shares {
    capacity_gb = var.filestore.capacity_gb
    name = var.filestore.fs_name
  }
  networks {
    network = var.filestore.network == null ? data.google_compute_subnetwork.slurm_subnet.network : var.filestore.network
    modes = ["MODE_IPV4"]
  }

}

// Create local.network_storage
locals {
  lustre_storage = var.create_lustre ? [{ server_ip = module.lustre_gcp.server_ip
                                          remote_mount = "/${var.lustre.fs_name}"
                                          local_mount = var.lustre.local_mount
                                          fs_type = "lustre"
                                          mount_options = "defaults,_netdev"
                                        }] : []

  filestore_storage = var.create_filestore ? [{ server_ip = google_filestore_instance.nfs[0].name
                                                remote_mount = "/${var.filestore.fs_name}"
                                                local_mount = var.filestore.local_mount
                                                fs_type = "nfs"
                                                mount_options = "defaults,_netdev"
                                              }] : []

  network_storage = flatten( [var.network_storage, local.lustre_storage, local.filestore_storage] )
}

module "slurm_cluster_controller" {
  source = "github.com/FluidNumerics/slurm-gcp//tf/modules/controller"

  boot_disk_size                = var.controller_disk_size_gb
  boot_disk_type                = var.controller_disk_type
  image                         = var.controller_image
  instance_template             = var.controller_instance_template
  cluster_name                  = var.cluster_name
  cloudsql                      = local.cloudsql
  compute_node_scopes           = var.compute_node_scopes
  compute_node_service_account  = var.compute_node_service_account
  disable_compute_public_ips    = var.disable_compute_public_ips
  disable_controller_public_ips = var.disable_controller_public_ips
  labels                        = var.controller_labels
  login_network_storage         = var.login_network_storage
  login_node_count              = var.login_node_count
  machine_type                  = var.controller_machine_type
  munge_key                     = var.munge_key
  jwt_key                       = var.jwt_key
  network_storage               = local.network_storage
  partitions                    = var.partitions
  project                       = var.project
  region                        = local.region
  secondary_disk                = var.controller_secondary_disk
  secondary_disk_size           = var.controller_secondary_disk_size
  secondary_disk_type           = var.controller_secondary_disk_type
  shared_vpc_host_project       = var.shared_vpc_host_project
  scopes                        = var.controller_scopes
  service_account               = var.controller_service_account
  subnet_depend                 = module.slurm_cluster_network.subnet_depend
  subnetwork_name               = var.subnetwork_name
  suspend_time                  = var.suspend_time
  zone                          = var.zone
}

module "slurm_cluster_login" {
  source = "github.com/FluidNumerics/slurm-gcp//tf/modules/login"
  project                   = var.project
  boot_disk_size            = var.login_disk_size_gb
  boot_disk_type            = var.login_disk_type
  image                     = var.login_image
  instance_template         = var.login_instance_template
  cluster_name              = var.cluster_name
  controller_name           = module.slurm_cluster_controller.controller_node_name
  controller_secondary_disk = var.controller_secondary_disk
  disable_login_public_ips  = var.disable_login_public_ips
  labels                    = var.login_labels
  login_network_storage     = var.login_network_storage
  machine_type              = var.login_machine_type
  node_count                = var.login_node_count
  region                    = local.region
  scopes                    = var.login_node_scopes
  service_account           = var.login_node_service_account
  munge_key                 = var.munge_key
  network_storage           = local.network_storage
  shared_vpc_host_project   = var.shared_vpc_host_project
  subnet_depend             = module.slurm_cluster_network.subnet_depend
  subnetwork_name           = var.subnetwork_name
  zone                      = var.zone
}

module "slurm_cluster_compute" {
  source = "github.com/FluidNumerics/slurm-gcp//tf/modules/compute"

  cluster_name               = var.cluster_name
  controller_name            = module.slurm_cluster_controller.controller_node_name
  disable_compute_public_ips = var.disable_compute_public_ips
  network_storage            = local.network_storage
  partitions                 = var.partitions
  project                    = var.project
  region                     = local.region
  scopes                     = var.compute_node_scopes
  service_account            = var.compute_node_service_account
  shared_vpc_host_project    = var.shared_vpc_host_project
  subnet_depend              = module.slurm_cluster_network.subnet_depend
  subnetwork_name            = var.subnetwork_name
  zone                       = var.zone
}

