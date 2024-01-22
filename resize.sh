# !/bin/bash
# https://docs.aws.amazon.com/cloud9/latest/user-guide/move-environment.html
# uso: sh resize.sh 100

# Specify the desired volume size in GiB as a command-line argument. If not specified, default to 20 GiB.
SIZE=${1:-100}

# Get the ID of the environment host Amazon EC2 instance.
#INSTANCEID=$(curl http://169.254.169.254/latest/meta-data//instance-id)
# https://docs.aws.amazon.com/pt_br/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCEID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data///instance-id)

# Get the ID of the Amazon EBS volume associated with the instance.
VOLUMEID=$(aws ec2 describe-instances \
  --instance-id $INSTANCEID \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" \
  --output text)

#echo "Verifica valor antes do comando modify-volume :"
#aws ec2 describe-volumes-modifications --volume-id $VOLUMEID

# Resize the EBS volume.
aws ec2 modify-volume --volume-id $VOLUMEID --size $SIZE > /dev/null

#echo "Verifica valor depois do comando modify-volume :"
#aws ec2 describe-volumes-modifications --volume-id $VOLUMEID

# Wait for the resize to finish.
while [ \
  "$(aws ec2 describe-volumes-modifications \
    --volume-id $VOLUMEID \
    --filters Name=modification-state,Values="optimizing","completed" \
    --query "length(VolumesModifications)"\
    --output text)" != "1" ]; do
sleep 1
done

#if [ $(readlink -f /dev/xvda) = "/dev/xvda" ]
#then
  # Rewrite the partition table so that the partition takes up all the space that it can.
  sudo growpart /dev/xvda 1
  # Expand the size of the file system.
  sudo resize2fs /dev/xvda1
#else
  # Rewrite the partition table so that the partition takes up all the space that it can.
  sudo growpart /dev/nvme0n1 1
  # Expand the size of the file system.
  sudo resize2fs /dev/nvme0n1p1
#fi
