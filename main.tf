terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

provider "oci" {
  region = "ap-mumbai-1"
}

# Variables to hold our auth data
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "ssh_public_key" {}

# Fetch the latest Ubuntu 22.04 ARM image
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Create a new VCN
resource "oci_core_vcn" "playground_vcn" {
  compartment_id = var.compartment_ocid
  cidr_block     = "10.0.0.0/16"
  display_name   = "playground-vcn"
  dns_label      = "playground"
}

# Create a public subnet
resource "oci_core_subnet" "playground_subnet" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.playground_vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "playground-subnet"
  dns_label      = "playgroundsub"
  route_table_id = oci_core_vcn.playground_vcn.default_route_table_id
  security_list_ids = [oci_core_vcn.playground_vcn.default_security_list_id]
}

# Create the Always Free ARM Instance
resource "oci_core_instance" "free_arm_vm" {
  # Try AD-1 first; if it fails, we can change this index to 1 or 2 for other ADs
  # Change to this
  availability_domain = "ESfE:AP-MUMBAI-1-AD-1"
  compartment_id      = var.compartment_ocid
  shape               = "VM.Standard.A1.Flex"
  
  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_arm.images[0].id
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.playground_subnet.id
    assign_public_ip = true
  }

  metadata = {
    # This assumes you have an SSH key at ~/.ssh/id_rsa.pub in WSL
    ssh_authorized_keys = file("~/.ssh/id_rsa.pub") 
  }
}

# Output the public IP so you can SSH in
output "public_ip" {
  value = oci_core_instance.free_arm_vm.public_ip
}
