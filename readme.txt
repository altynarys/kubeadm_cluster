The script launch new VPC with Docker & Kubernetes baked node-cluster

1) You can specify how many nodes are needed in EC2 section of node_cluster_vpc.sh
2) Try to check up AMI of the EC2 image. Amazon sometimes changes it. If it does you can put new image id in EC2 section of node_cluster_vpc.sh
3) Everything should work but launching Flannel network (it does not work on user data section. Don't have any idea of the issue). SSH master node and under root user home directory run flannel.sh manually. After that, the cluster will be ready to use. Have a nice adventure!

NOTE: After work done recommend you to terminate EC2s and delete VPC as well. It might be cost-effective. And when you need it again - just run the script
