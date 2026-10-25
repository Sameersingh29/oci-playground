#!/bin/bash

# --- Configuration ---
# Add your Tenancy OCID here
TENANCY_OCID="ocid1.tenancy.oc1..aaaaaaaako2zlra75wzy7e5d7cbbbu4dtx6tbpg4nlxm4jo4dsnsp4jvfomq"

# The three Mumbai Availability Domains
ADS=("ESfE:AP-MUMBAI-1-AD-1" "ESfE:AP-MUMBAI-1-AD-2" "ESfE:AP-MUMBAI-1-AD-3")

echo "🚀 Starting OCI ARM Instance Auto-Retry Script..."
echo "Press [CTRL+C] at any time to stop."

while true; do
  for AD in "${ADS[@]}"; do
    echo "----------------------------------------"
    echo "🔍 Checking capacity for $AD..."
    
    # Check capacity using OCI CLI
    RESULT=$(oci compute compute-capacity-report create \
      --compartment-id "$TENANCY_OCID" \
      --availability-domain "$AD" \
      --shape-availabilities '[{"instanceShape":"VM.Standard.A1.Flex","instanceShapeConfig":{"ocpus":2,"memoryInGBs":12}}]' \
      --query 'data."available-count"' \
      --raw-output 2>/dev/null)

    # If the result is a number greater than 0, capacity is available!
    if [[ "$RESULT" =~ ^[0-9]+$ ]] && [ "$RESULT" -gt 0 ]; then
      echo "✅ Capacity found in $AD ($RESULT available)! Updating Terraform..."
      
      # Update main.tf with the available AD using sed
      sed -i "s|availability_domain = \".*\"|availability_domain = \"$AD\"|g" main.tf
      
      echo "⚙️  Running terraform apply..."
      terraform apply --auto-approve
      
      # Check if terraform apply was successful (exit code 0)
      if [ $? -eq 0 ]; then
        echo "🎉 SUCCESS! Instance created in $AD."
        echo "🎉 Script stopping."
        exit 0
      else
        echo "❌ Terraform failed to apply (Capacity likely taken by someone else)."
        echo "🧹 Cleaning up failed state and retrying..."
        terraform state rm oci_core_instance.free_arm_vm 2>/dev/null
      fi
    else
      echo "❌ No capacity in $AD."
    fi
  done
  
  echo "⏳ Sleeping for 60 seconds before checking again..."
  sleep 60
done