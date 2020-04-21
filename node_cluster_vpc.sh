#!/bin/bash
echo "###################################################################"
echo "#--                       creating vpc                          --#"
echo "###################################################################"
whereCreateVPC="us-east-1"
postFix="_dkube"
NameTag="Name"

#-------- vpc ID and NAME  -----------------#
vpcID="" 
vpcNameTagValue="vpc${postFix}"
cidrVPC="172.20.0.0/16"

#-------- rtb ID and NAME  -----------------#
rtbID=""
rtbNameTagValue="rtb${postFix}"

#-------- subnet ID and NAME  --------------#
subnetID=""
subnetNameTagValue="subnet${postFix}"
AZ_ID="use1-az4"
cidrSubnet="172.20.10.0/24"

#-------- igw ID and NAME ------------------#
igwID="" 
igwNameTagValue="igw${postFix}"

#-------- nacl ID and NAME -----------------#
naclID=""
naclNameTagValue="nacl${postFix}"

#-------- sg ID and NAME -------------------#
sgID=""
sgNameTagValue="sg${postFix}"

#-------- ec2 ID and NAME -------------------#
ec2q=3   #how many nodes in a cluster are needed
apiserverIP=""
ec2ID=""
ec2NameTagValue="${postFix}"
ec2Type="t2.micro"
keyPair=$(aws ec2 describe-key-pairs | jq -r '.KeyPairs[0].KeyName')
imageID="ami-0a887e401f7654935"

#-------- All about AMI ---------------------#
amiNameTagValue="ami_for_us-east-2$postFix"
amiName="ami_for_us-east-2"
amiState=""
amiDestinationNameTagValue="ami_for_us-east-2$postFix"
amiDestinationName="ami_from_us-east-1"
amiCopyState=""
amiCopyID=""

#-------- Current region -------------------#
curRegion=$(aws configure get profile.default.region)
sourceRegion=$curRegion
echo -e "Current region: \033[1m$curRegion\033[0m"

#--- beginig of IF  ---#
if [ $curRegion != $whereCreateVPC ]
then
#--- then of IF  ---#
  echo -e "The region must be: \033[1m$whereCreateVPC\033[0m"
  echo "Creating VPC is interrupted"
else
#--- else of IF  ---#
  echo "Creating VPC..."

  #------- 1 creating and retrieving vpc ID  -------------------#
  vpcID=$(aws ec2 create-vpc \
        --cidr $cidrVPC \
        --instance-tenancy default \
        --no-amazon-provided-ipv6-cidr-block | jq -r '.Vpc.VpcId')
  aws ec2 modify-vpc-attribute --vpc-id $vpcID --enable-dns-hostnames
  
  #--------  assigning tag name to vpc -----------#
  aws ec2 create-tags --resources $vpcID --tags Key=$NameTag,Value=$vpcNameTagValue
  echo -e "\t--> VPC created, ID = \033[1m$vpcID\033[0m, Name = \033[1m$vpcNameTagValue\033[0m"

  #-------- 2 assigning tag name to route table --------#
  rtbID=$(aws ec2 describe-route-tables \
	--filter Name=vpc-id,Values=$vpcID > 2_get_rtb.json \
	&& \
	jq -r '.RouteTables[0].RouteTableId' 2_get_rtb.json)
  aws ec2 create-tags --resources $rtbID --tags Key=$NameTag,Value=$rtbNameTagValue
  echo -e "\t--> Route table created, ID = \033[1m$rtbID\033[0m, Name = \033[1m$rtbNameTagValue\033[0m"

  #--------- 3 creating and tagging subnet  ----------------#
  subnetID=$(aws ec2 create-subnet \
	--availability-zone-id $AZ_ID \
	--cidr-block $cidrSubnet \
	--vpc-id $vpcID > 3_create_subnet.json \
	&& \
	jq -r '.Subnet.SubnetId' 3_create_subnet.json)
  aws ec2 create-tags  --resources $subnetID --tags Key=$NameTag,Value=$subnetNameTagValue
  echo -e "\t--> Subnet created, ID = \033[1m$subnetID\033[0m, Name = \033[1m$subnetNameTagValue\033[0m"

  #--------- 4 creating, tagging internetGateway, and attaching to VPC  ------------#
   igwID=$(aws ec2 create-internet-gateway > 4_create_igw.json \
	&& \
	jq -r '.InternetGateway.InternetGatewayId' 4_create_igw.json)
   aws ec2 create-tags --resources $igwID --tags Key=$NameTag,Value=$igwNameTagValue
   aws ec2 attach-internet-gateway --internet-gateway-id $igwID --vpc-id $vpcID
   echo -e "\t--> InternetGateway created, ID =\033[1m$igwID\033[0m, Name = \033[1m$igwNameTagValue\033[0m and attached to VPC"

  #--------- 5 associating rtb, subnet and igw   ----------#
  aws ec2 create-route \
	--route-table-id $rtbID --destination-cidr-block 0.0.0.0/0 \
	--gateway-id $igwID > /dev/null
  aws ec2 associate-route-table --route-table-id $rtbID \
	--subnet-id $subnetID > 5_associate_rtb_subnet_igw.json
  echo -e "\t--> Associating \033[1m$rtbNameTagValue\033[0m, \033[1m$subnetNameTagValue\033[0m and \033[1m$igwNameTagValue\033[0m done"

  #--------- 6 nacl tagging   ----------#
  naclID=$(aws ec2 describe-network-acls --filters Name=vpc-id,Values=$vpcID > 6_nacl.json \
	 && \
	 jq -r '.NetworkAcls[0].NetworkAclId' 6_nacl.json)
  aws ec2 create-tags --resources $naclID --tags Key=$NameTag,Value=$naclNameTagValue
  echo -e "\t--> Network ACL, ID =\033[1m$naclID\033[0m, Name = \033[1m$naclNameTagValue\033[0m"

  #--------- 7 sg creating and tagging ------------#
  sgID=$(aws ec2 create-security-group \
	--description EC2_SSH_HTTP$postFix \
	--group-name $sgNameTagValue \
	--vpc-id $vpcID | jq -r '.GroupId')
  aws ec2 create-tags --resources $sgID --tags Key=$NameTag,Value=$sgNameTagValue
  echo -e "\t--> Security group created, ID =\033[1m$sgID\033[0m, Name = \033[1m$sgNameTagValue\033[0m and attached to VPC:"
  aws ec2 authorize-security-group-ingress \
	--group-id $sgID --protocol tcp --port 22 --cidr 0.0.0.0/0 
  aws ec2 authorize-security-group-ingress \
	--group-id $sgID --protocol tcp --port 80 --cidr 0.0.0.0/0  
  aws ec2 authorize-security-group-ingress \
        --group-id $sgID --protocol tcp --port 6443 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress \
        --group-id $sgID --protocol tcp --port 31000 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress \
        --group-id $sgID --protocol all --port all --source-group $sgID
  echo -e "\t\tAllowed ingress:\n\t\t\tprotocols: \033[1mTCP\033[0m;\n\t\t\tports: \033[1m22, 80, 6443, 31000, $sgID\033[0m;\n\t\t\tsources: \033[1m0.0.0.0/0\033[0m"
  aws ec2 describe-security-groups --filters Name=group-id,Values=$sgID > 7_sg.json
  aws ec2 describe-vpcs --vpc-ids $vpcID > 1_create_vpc.json
 
 #--------- 8 ecc creating and tagging ------------#
 i=1
 while [ $i -le $ec2q ]
 do
  if [ $i -eq 1 ]
  then
    m_name="master"
    f_name="master_script.txt"
  else
    m_name="worker$(( $i - 1 ))"
    f_name="worker_script.txt"
#    if [ $i -eq 2 ]
#    then
#      f_name="worker1_script.txt"
#    fi
  fi
  aws ec2 run-instances \
        --image-id $imageID \
        --count 1 \
        --subnet-id $subnetID \
        --instance-type $ec2Type \
        --associate-public-ip-address \
        --security-group-ids $sgID \
	--key-name $keyPair \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$m_name$ec2NameTagValue'}]' 'ResourceType=volume,Tags=[{Key=Name,Value='$m_name$ec2NameTagValue'}]' \
	--user-data file://$f_name > 8_ec2.json

  ec2ID=$(jq -r '.Instances[0].InstanceId' 8_ec2.json)
  ec2State=""
  echo -e "\t--> ${m_name} node created, ID =\033[1m$ec2ID\033[0m, Name = \033[1m$m_name$ec2NameTagValue\033[0m"
  echo -e "\t    key pair applied, Name = \033[1m$keyPair\033[0m"
  while [ "$ec2State" != "running" ]
  do
     sleep 5s
     ec2State=$(aws ec2 describe-instance-status --instance-ids $ec2ID | jq -r '.InstanceStatuses[0].InstanceState.Name')
     echo -e "\t\t ${m_name} node status: \033[1m$ec2State\033[0m"
  done
  dnsEC2=$(aws ec2 describe-instances --instance-ids $ec2ID | jq -r '.Reservations[0].Instances[0].PublicDnsName')
  pubIPEC2=$(aws ec2 describe-instances --instance-ids $ec2ID | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
  if [ $i -eq 1 ]
  then
    apiserverIP=$(aws ec2 describe-instances --instance-ids $ec2ID | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')
    echo -e "\t    apiserver IP: \033[1m$apiserverIP\033[0m"
    cat worker_template.txt > worker_script.txt
    echo "curl http://$apiserverIP > ~/join.sh && chmod +x ~/join.sh && ~/join.sh" >> worker_script.txt
  fi
  echo -e "\t    ${m_name} node public DNS: \033[1m$dnsEC2\033[0m"
  echo -e "\t    ${m_name} node public IP: \033[1m$pubIPEC2\033[0m\n"
  ((i++))
 done
 echo "###################################################################"
 echo "#--                     vpc has been created                    --#"
 echo "###################################################################"
fi
