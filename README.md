# kubernetes-private-aws


The code in this repo is for provisioning a K8s in a private topology on AWS.


## Terraform state

If you are on a team and want to have terraform state stored in a s3 bucket, do this:
```
cd state
terraform init
terraform plan
terraform apply
```

## Provision the cluster

In this directory do:
```
terraform init
terraform plan
terraform apply
```

This should give you the output of the master ips:
```
Outputs:

kubernetes_version = 1.9.3
masters-ip = 10.46.28.173
```

Make sure you have kubectl installed on your system, the same version as the cluster:
```
kubectl_version=v1.9.3

curl -LO https://storage.googleapis.com/kubernetes-release/release/${kubectl_version}/bin/linux/amd64/kubectl

chmod +x kubectl

sudo mv kubectl /usr/local/bin
```
Now configure kubectl to work with the cluster:

```
scp -i ssh/cluster ubuntu@masters-ip:~/.kube/config ~/.kube/config
```
Verify the cluster is working:
```
kubectl get nodes

NAME                                            STATUS    ROLES     AGE       VERSION
ip-10-46-28-114.eu-central-1.compute.internal   Ready     <none>    3h        v1.9.3
ip-10-46-28-173.eu-central-1.compute.internal   Ready     master    3d        v1.9.3
```