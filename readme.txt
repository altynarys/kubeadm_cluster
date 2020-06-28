The script creates a new VPC, K8s node-group cluster with Docker run-time and Flannel network add-on

1) How many nodes are needed can be specified in EC2 section of node_cluster_vpc.sh
2) Make sure that AMI of the EC2 image exists. Amazon often changes AMI ID. If it does you can put new image id in EC2 section of node_cluster_vpc.sh
3) Everything should work but launching Flannel network (the network script does not work from "user data" section. Don't have any idea of the issue). SSH master node and under root user run flannel.sh manually. After that, the cluster will be ready to use. Have a nice adventure!

NOTE: Terminate all of EC2s first and delete VPC after as well when work gets done. It will safe money and keep cost-efficiency. Need it again - just run the script
