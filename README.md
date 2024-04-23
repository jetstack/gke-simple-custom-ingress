# gke-simple-custom-ingress
Designed to be used alongside the blog https://venafi.com/blog/gke-custom-ingress-routing-made-simple/

## Pre Requisites 

1. Before running Terraform Plan/Apply you will need to fill in the variables present in `variables.tf`
2. Depending on your implementation you may need to remove either the `external-lb.tf` or `internal-lb.tf`.

## Running Terraform

1. Run Terraform init
    ```bash
    terraform init
    ```
2. Run Terraform Plan
    ```bash
    terraform plan 
    ```

3. Run Terraform Apply
    ```bash
    terraform apply 
    ```

## Notes

Sometimes when running terraform destroy, the GKE Network Endpoint Controller does not get chance to destroy the Network Endpoint Groups, 
if this happens the VPC Network will fail to destroy, you can delete these manually by going to the following 
<https://console.cloud.google.com/compute/networkendpointgroups/list>
Selecting the Network Endpoints and Deleting, Re-Run Terraform Destroy and it should be ok the second time.
